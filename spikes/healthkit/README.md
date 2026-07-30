# Spike A — HealthKit read access

> **Throwaway code.** The deliverable is *"your own real step and weight history
> rendering on your own iPhone"* (§0.7 exit criteria) plus what you learn. Delete the
> project afterwards.

**Blocked until the Apple Developer Program clears.** HealthKit is a paid-programme
entitlement — free provisioning gives you 7-day certificates and no HealthKit at all,
so you cannot complete this spike without paying. §0.1 moves the purchase to week one
for exactly this reason, and enrolment can take several days.

Do the design work and Spike B while you wait. This spike is roughly 90 minutes once
you can actually build.

---

## What you need

| | |
|---|---|
| Mac | macOS Tahoe 26.2+ (Xcode 26.6's hard floor), ~40 GB free |
| Xcode | 26.6 stable. **Not** the Xcode 27 beta — §04 |
| iPhone | Physical device, iOS 18+. **The Simulator will not do.** |
| Apple Developer Program | Active. Non-negotiable for HealthKit. |

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
- Under **Signing**, tick *Automatically manage signing* and pick your team. If the
  team dropdown is empty, your Developer Program membership has not finished
  activating.

**If "HealthKit" is not in the capability list, your membership is not active.** That
is the single most common blocker here — it is not a missing setting.

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
| "HealthKit" absent from capabilities | Developer Program not active |
| Signing team dropdown empty | Same |
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
