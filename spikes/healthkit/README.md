# Spike A — HealthKit read access

> **Throwaway code.** The deliverable is *"your own real step and weight history
> rendering on your own iPhone"* (§0.7 exit criteria) plus what you learn. Delete the
> project afterwards.

**Probably not blocked. Test that for ten minutes before you spend $99.**

This file used to say HealthKit was a paid-programme entitlement. Apple's own
capabilities table says otherwise: **HealthKit is listed as available to the free
Apple Developer account** — the "Personal Team" Xcode gives you for signing in with an
ordinary Apple ID. Only *HealthKit Estimate Recalibration*, which this spike does not
touch, is restricted to the paid programmes.
[Supported capabilities](https://developer.apple.com/support/app-capabilities/).

Apple's table is authoritative but Xcode's signing behaviour has surprised people
before, so treat this as a claim to **verify**, not a fact to build on — see
[the ten-minute gate](#the-ten-minute-gate) below. If it fails you have lost ten
minutes, you buy the account, and nothing else about this spike changes.

The spike itself is roughly 90 minutes once you can build.

### What the free tier genuinely cannot do

None of it affects this spike:

| Limit | Bites when |
|---|---|
| Build stops launching after **7 days** | Dogfooding. ⌘R from Xcode re-signs it; the phone must be plugged in weekly |
| 3 devices, 10 App IDs per 7 days | Never, at this stage |
| No TestFlight, no App Store, no external testers | Phase 2/3 |

So the $99 is still on the critical path — for TestFlight, for submission, and for the
21-consecutive-day dogfood run, where a 7-day expiry means a missed re-sign is a broken
streak. It is just **not** on the critical path for reading your own step and weight
history onto your own phone, which is what §0.7 actually asks for.

---

## The ten-minute gate

Do this before you pay. No spike code, no Health data, no `Info.plist` — the only
question is whether Xcode will sign a HealthKit app with a free team.

1. Xcode → **Settings → Accounts → +** → **Apple ID** → sign in with your normal Apple
   ID. No enrolment, no payment.
2. **File → New → Project → iOS → App.** Product name `HKGate`, Interface SwiftUI.
   Save it somewhere throwaway.
3. Target → **Signing & Capabilities** → tick *Automatically manage signing*, Team =
   **`<Your Name> (Personal Team)`**.
4. Set the bundle identifier to something globally unique —
   `com.<yourname>.hkgate<four random digits>`. An identifier someone else already
   registered fails signing for reasons that have nothing to do with HealthKit, and
   will send you down the wrong path for an hour.
5. **+ Capability → HealthKit.** Double-click it. *Appearing in the picker proves
   nothing* — Xcode lists every capability and only complains when it signs.
6. Plug the iPhone in, pick it as the run destination, **⌘R**.

**PASS — it builds, installs and launches on the phone.** HealthKit works on the free
tier. Do the whole spike today; buy the account when TestFlight needs it.

**FAIL — a signing error that names the capability**, e.g. *"Personal development teams
do not support the HealthKit capability"* or *"Your development team does not support
the HealthKit capability."* The old claim was right. Buy the account, and paste the
exact string into
[`07-spike-findings.md`](../../docs/phase-0/07-spike-findings.md) so nobody re-tests
this.

Anything else — *Untrusted Developer*, bundle ID taken, empty team dropdown, a plain
provisioning-profile error — is ordinary free-provisioning friction, not the answer.
**The gate is specifically whether the error names HealthKit.**

The one report behind the old claim is
[a forum thread](https://developer.apple.com/forums/thread/125980) where a *university
team* account refused the capability while the same person's *personal* account built
it fine. That is an education-account limit, not a free-tier one.

Do the design work and Spike B either way — neither ever needed the account.

---

## What you need

| | |
|---|---|
| Mac | macOS Tahoe 26.2+ (Xcode 26.6's hard floor), ~40 GB free |
| Xcode | 26.6 stable. **Not** the Xcode 27 beta — §04 |
| iPhone | Physical device, iOS 18+. **The Simulator will not do.** |
| Apple Developer Program | **Probably not needed yet** — run [the ten-minute gate](#the-ten-minute-gate) first. Needed for TestFlight regardless. |

On the Simulator, HealthKit compiles and the authorisation sheet appears, but there
is no data behind it and background delivery does nothing. §0.1: *"you cannot fake
your way through this."*

Before you start, put some data in Health: walk around with the phone for a day, and
add two or three weight entries by hand (Health → Browse → Body Measurements →
Weight → Add Data). A spike that reads an empty store teaches you nothing except
what the empty state looks like — which is worth seeing, but second.

---

## Setup

### 1 · New project

Xcode → **File → New → Project → iOS → App**.

| Field | Value |
|---|---|
| Product Name | `NotchHealthSpike` |
| Interface | SwiftUI |
| Language | Swift |
| Storage | None |
| Testing System | None |

Save it **outside this repository** — it is throwaway, and §0.6 does not want Xcode
project noise in the history.

### 2 · Set the deployment target

Select the project (top of the file list) → target `NotchHealthSpike` → **General** →
**Minimum Deployments** → iOS **18.0**. Matches ADR 0002 so the spike proves the
right thing.

### 3 · Add the HealthKit capability

Target → **Signing & Capabilities** → **+ Capability** → **HealthKit**.

- Leave *Clinical Health Records* and *Background Delivery* unchecked. Background
  delivery is a Phase 1 concern (§1.4); the spike only needs a foreground read.
- Under **Signing**, tick *Automatically manage signing* and pick your team —
  `(Personal Team)` is fine if the gate passed. An empty dropdown means no Apple ID is
  signed in under Xcode → Settings → Accounts, not that you need to pay.

If signing fails here with an error **naming HealthKit**, you are in the gate's FAIL
case above and the account is genuinely required. Any other signing error is not that.

### 4 · Add the Info.plist key

Target → **Info** tab → hover any row → **+**:

| Key | Value |
|---|---|
| `Privacy - Health Share Usage Description` | `Notch reads your weight, steps and workouts so it can score your consistency and progress against your own baseline.` |

The raw key is `NSHealthShareUsageDescription`. **Without it the app crashes the
moment you request authorisation** — not a graceful error, an immediate termination
with a console message about the missing key. If that happens, this step is why.

You do **not** need `NSHealthUpdateUsageDescription`: that is for *writing*, and the
spike passes an empty `toShare` set.

Write the string as if a suspicious user is reading it, because one is. Apple review
rejects vague health justifications (§10 lists App Store rejection as a live risk),
and a specific reason also gets you a higher grant rate from real users.

### 5 · Paste the code

Replace the generated files with these two:

| Xcode file | Replace with |
|---|---|
| `NotchHealthSpikeApp.swift` | [`NotchHealthSpikeApp.swift`](NotchHealthSpikeApp.swift) |
| `ContentView.swift` | **delete it** — `SpikeView` lives in the app file |
| *(new file)* | [`HealthSpike.swift`](HealthSpike.swift) |

### 6 · Run on the device

Plug the phone in, pick it in the run destination, ⌘R.

First run on a new device: the phone shows *"Untrusted Developer"* — Settings →
General → VPN & Device Management → your Apple ID → Trust.

---

## What to do, in order

1. **Request read authorisation.** The Health sheet appears. **Grant everything on
   the first run** — you want to see the happy path work before you test denial.
2. **Read last 30 days.** Watch the Xcode console (⌘⇧C). You should see your own
   step counts and weights printed by day. **That is the exit criterion met.**
3. **Read again.** The anchored query should now report close to zero new samples.
   That difference is the whole point — see below.
4. **Force-quit the app, relaunch, read again.** Still near-zero. This proves the
   anchor survived the launch, which is what makes it useful.
5. **Reset anchors, then read again.** Back to many samples. You have just watched
   the difference between an incremental sync and a full re-read.
6. **Now test denial.** Settings → Health → Data Access & Devices → NotchHealthSpike
   → turn Steps off. Read again. **Note what you get: an empty result, with no error
   and no indication that anything was denied.** Sit with that for a moment — it is
   the finding.

---

## The two things this spike is actually for

### 1 · You cannot detect a denied read

§0.7: *"iOS deliberately will not tell you whether the user denied read access —
this is an anti-fingerprinting measure, since knowing a user hid their heart data is
itself information. You will get back an empty result set that looks identical to
'this user has no data.'"*

`HKHealthStore.authorizationStatus(for:)` exists, and it is a trap: it reports
**write** permission only. There is no read equivalent, and there will not be one.

**The design consequence is the deliverable**, and it is bigger than it sounds:

- There is no permission-denied branch to write. Do not write one.
- Every repository returns an empty collection rather than throwing.
- Every data surface needs a designed empty state from the first commit — not an
  error state, and not a spinner that never resolves.
- The empty-state copy must not claim a permission problem, because the app does not
  know. `docs/design/04-copy-deck.md` words no-data and permission-not-granted
  **identically** for this reason.

This is principle 5 in `docs/design/00-design-principles.md`, and it exists because
of this spike.

### 2 · The persisted anchor is the performance story

§1.4: *"Persist the anchor. This is the entire trick — it gives you incremental sync
instead of re-querying full history on every launch, which is the difference between
an app that opens instantly and one that hangs for four seconds."*

Step 5 above is what makes this concrete: with the anchor cleared, the query walks
your entire history; with it saved, it returns a handful of samples. On a phone with
two years of step data the gap is dramatic, and it is invisible until you look.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| Crash on requesting authorisation | `NSHealthShareUsageDescription` missing — step 4 |
| Signing error naming the HealthKit capability | The free tier really is refused here — buy the account, and record the error string in `07-spike-findings.md` |
| Signing team dropdown empty | No Apple ID added under Xcode → Settings → Accounts. Not a payment problem |
| App stops launching about a week after you installed it | Free-tier 7-day signing. Plug in, ⌘R, carry on |
| Everything returns empty on a real device | Nothing recorded yet, **or** read denied — you cannot tell, and that is the point. Add a manual weight entry in Health to confirm the pipeline works. |
| `bodyMass` returns a number near 235 | You summed a discrete type. Weight is `.discreteAverage`, not `.cumulativeSum` — the code handles this; if you edit it, do not break it. |
| Data appears in the app but not the console | Console filter is on, or you are looking at the wrong device log |
| Works on Simulator, no data | Expected. Simulator has no health data. |

---

## When you're done

1. Note the results in
   [`docs/phase-0/07-spike-findings.md`](../../docs/phase-0/07-spike-findings.md) —
   how many days of each type came back, whether the second read was incremental,
   and what the denied-read case looked like.
2. Take a screenshot of your own real data rendering. §0.7's exit criterion is
   literally *"your own real step and weight history rendering on your own iPhone"* —
   evidence beats a tick in a box, and it is a good image for the write-up.
3. **Delete the Xcode project.** Carry forward only the five items listed at the
   bottom of `HealthSpike.swift`.
