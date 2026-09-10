import Foundation

/// The drain's other half: PostgREST, over plain `URLSession`.
///
/// **Not the SDK's PostgREST client**, and for the same reason
/// `SupabaseMealEstimator` is not: what this route needs from a request is not
/// what a typed query builder is for. Two of the six tables have to resolve an
/// upsert against a *named* unique constraint rather than the primary key (see
/// `SyncTable.conflictTarget`), one column has to reach the wire as JSON that
/// was never parsed (`photo_estimates.model_output`), and the status code is
/// the whole of the retry decision. All three are things a typed decode hides.
///
/// The client is still the SDK's — `SupabaseStack` holds the one in the
/// process, because it owns the Keychain session and the refresh timer. This
/// reads the access token off it and nothing else.
@MainActor
struct SupabaseSyncClient: SyncWriting {
    let stack: SupabaseStack
    var session: URLSession = .shared

    func upsert(_ row: SyncRow) async throws {
        var components = URLComponents(
            url: endpoint(for: row.table),
            resolvingAgainstBaseURL: false
        )
        if let target = row.table.conflictTarget {
            components?.queryItems = [URLQueryItem(name: "on_conflict", value: target)]
        }
        guard let url = components?.url else { throw SyncFailure.unavailable }

        var request = try signed(URLRequest(url: url))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // `merge-duplicates` is what turns an insert into an upsert. `return=minimal`
        // because the drain has no use for the row it just sent, and on a
        // connection that is usually the problem, the reply not carrying it back
        // is bytes not spent.
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = row.body

        try await send(request, describing: "upsert \(row.table.postgres)")
    }

    func delete(from table: SyncTable, id: UUID) async throws {
        var components = URLComponents(url: endpoint(for: table), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())"),
        ]
        guard let url = components?.url else { throw SyncFailure.unavailable }

        var request = try signed(URLRequest(url: url))
        request.httpMethod = "DELETE"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        // A delete that matches nothing returns 204, not an error: RLS `using`
        // clauses filter rows rather than raising, so a `food_logs` row past
        // §2.3's 48-hour window is simply not among the rows this request can
        // see. The server keeps its copy and the phone does not, which is the
        // anti-gaming rule working rather than a sync bug — noted here because
        // it is the one place the two stores are allowed to disagree.
        try await send(request, describing: "delete \(table.postgres)")
    }

    // MARK: - The request

    private func endpoint(for table: SyncTable) -> URL {
        stack.configuration.url.appending(path: "rest/v1/\(table.postgres)")
    }

    private func signed(_ request: URLRequest) throws -> URLRequest {
        guard let token = stack.client.auth.currentSession?.accessToken else {
            throw SyncFailure.notSignedIn
        }
        var request = request
        request.setValue(stack.configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Perform it, and turn the answer into one of four verdicts.
    ///
    /// The `URLError` list is the same one `SupabaseMealEstimator` and
    /// `AppleIdentity` use, and for the reason the copy deck gives: only a real
    /// transport failure gets the offline reading, because mapping every failure
    /// to "no connection" states a cause the app does not know.
    private func send(_ request: URLRequest, describing what: String) async throws {
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                throw SyncFailure.offline
            default:
                throw SyncFailure.unavailable
            }
        } catch {
            throw SyncFailure.unavailable
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200..<300:
            return
        case 401:
            throw SyncFailure.notSignedIn
        // 429 is the rate limiter asking for patience and 5xx is the server
        // having a bad minute. Neither is a verdict on the row, so neither
        // spends one of its five attempts.
        case 429, 500...:
            Log.data.error("\(what, privacy: .public) returned \(status, privacy: .public)")
            throw SyncFailure.unavailable
        default:
            // 403 lands here on purpose: an RLS refusal is a statement about
            // this row, and repeating the request unchanged gets the same reply.
            Log.data.error("\(what, privacy: .public) refused with \(status, privacy: .public)")
            throw SyncFailure.refused(status: status)
        }
    }
}
