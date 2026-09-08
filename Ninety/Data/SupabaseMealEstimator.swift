import Foundation
import Supabase

/// Upload the photo, ask the Edge Function, validate what comes back.
///
/// **Three things this deliberately does not do**, each of them a rule from
/// somewhere else in the repo:
///
/// - **It never calls a model API.** §04: a key in a client binary is a key you
///   have published, and `no_embedded_secrets` in `.swiftlint.yml` is the
///   tripwire. The provider, the prompt and the key all live in the function.
/// - **It never trusts the response.** Structured outputs constrain the shape,
///   not the sense. `MealEstimatePayload.validated` is the gate.
/// - **It never blocks a log.** Every failure here throws a `MealEstimateError`
///   whose recovery line is manual entry, which needs no network at all.
///
/// **Plain `URLSession` rather than the SDK's Storage and Functions clients**,
/// and the reason is what this route needs from a response rather than a
/// preference. `photo_estimates.model_output` has to hold the model's output
/// *verbatim* — re-encoding it from parsed values would leave the benchmark
/// re-scoring the app's idea of the answer rather than the model's — and the
/// per-user cap is reported as a status code. A typed decode hides both. The
/// catalogue, which needs neither, uses the SDK.
@MainActor
struct SupabaseMealEstimator: MealEstimating {
    let stack: SupabaseStack
    var session: URLSession = .shared
    /// Injected so a test can place an upload at a known path and instant.
    var now: () -> Date = { Date() }
    var newFilename: () -> String = { "\(UUID().uuidString).jpg" }

    static let bucket = "meal-photos"
    static let functionName = "estimate-meal"

    func estimate(jpeg: Data) async throws -> MealEstimate {
        guard
            let userID = stack.currentUserID,
            let token = stack.client.auth.currentSession?.accessToken
        else { throw MealEstimateError.notSignedIn }

        // `<user-id>/<file>`. The storage policies in migration 003 compare the
        // first path segment against `auth.uid()`, so this shape is not a
        // convention — it is the thing that makes the object private.
        let path = "\(userID.uuidString.lowercased())/\(newFilename())"
        let started = now()

        try await upload(jpeg: jpeg, to: path, token: token)
        let (body, status) = try await invoke(storagePath: path, token: token)

        switch status {
        case 200:
            break
        // The server-side cap. §10 asks for calm copy and an intact manual
        // path, so this is a named case rather than a generic failure.
        case 429:
            throw MealEstimateError.dailyCapReached
        case 401, 403:
            throw MealEstimateError.notSignedIn
        // The function could not make sense of what the model returned, or the
        // model declined. Either way there is nothing to review, and the client
        // treats it the same as a body it could not decode itself.
        case 422:
            throw MealEstimateError.malformedResponse
        default:
            Log.data.error("estimate-meal returned \(status, privacy: .public)")
            throw MealEstimateError.unavailable
        }

        let payload: MealEstimatePayload
        do {
            payload = try JSONDecoder().decode(MealEstimatePayload.self, from: body)
        } catch {
            // A response that satisfied the transport and not the contract. The
            // ticket's wording: a malformed response degrades to manual entry.
            Log.data.error("estimate-meal returned an unreadable body")
            throw MealEstimateError.malformedResponse
        }

        return try payload.validated(
            // The body as it arrived, not as it parsed.
            rawOutput: body,
            latency: now().timeIntervalSince(started)
        )
    }

    // MARK: - The two calls

    private func upload(jpeg: Data, to path: String, token: String) async throws {
        var request = URLRequest(
            url: stack.configuration.url
                .appending(path: "storage/v1/object/\(Self.bucket)/\(path)")
        )
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(stack.configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = jpeg

        let (_, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            Log.data.error("meal-photo upload returned \(code, privacy: .public)")
            throw MealEstimateError.unavailable
        }
    }

    private func invoke(storagePath: String, token: String) async throws -> (Data, Int) {
        var request = URLRequest(
            url: stack.configuration.url.appending(path: "functions/v1/\(Self.functionName)")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stack.configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Only the path. The image is already in a bucket the function can read
        // and the user owns; posting the bytes a second time would double the
        // upload on the connection that is usually the problem.
        request.httpBody = try JSONEncoder().encode(["storage_path": storagePath])

        let (data, response) = try await perform(request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? -1)
    }

    /// One place where a transport failure becomes the offline case.
    ///
    /// Only a real `URLError` gets the offline wording. Mapping everything to
    /// "check your connection" states a cause the app does not know, which the
    /// copy deck rules out for sign-in and rules out here for the same reason.
    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                throw MealEstimateError.offline
            default:
                throw MealEstimateError.unavailable
            }
        } catch {
            throw MealEstimateError.unavailable
        }
    }
}
