# The brief

The source document the whole project derives from. Dated 27 July 2026, 20 pages,
names the product **TIER** — now Ninety ([ADR 0014](../decisions/0014-rename-to-ninety.md)).

| File | What it is |
|---|---|
| `project-brief.pdf` | **Canonical.** The document as written |
| `project-brief.md` | Machine text extraction, so the brief is greppable |

## Read the repo before you read this

The brief is cited ~300 times across this repository as `§01`, `§2.2`, `§10` and so on.
Nearly always, what you want is the derived artefact rather than the source, because the
derived one is newer and testable:

| If you want | Read |
|---|---|
| A locked decision and why | [`docs/decisions/`](../decisions/) — 14 ADRs, index first |
| §10, the safety section | [`safety-requirements.md`](../safety/safety-requirements.md) — numbered rules S1–S7 with test names |
| What the product is, for whom | [`PRODUCT.md`](../../PRODUCT.md) |
| What Phase 0 measured | [`07-spike-findings.md`](../phase-0/07-spike-findings.md) |

**What only the brief has:** §2.2's scoring maths and §2.3's anti-gaming rules. Phase 2
builds from those and no other file carries them in full.

## The brief is not the truth any more

It is a record of what was decided on 27 July 2026, before anything was built or
measured. Several of its claims have since been tested and changed — and where the repo
disagrees with the brief, **the repo is right and an ADR says why**:

- **The thesis is narrower.** §01 claims *"every fitness app compares you to other
  people"*. Strava's Local Legend already rewards pace-agnostic consistency, so the
  claim is now the sharper one ([ADR 0013](../decisions/0013-narrowed-thesis-claim.md)).
- **Photo accuracy is a benchmark, not a gate**
  ([ADR 0010](../decisions/0010-anthropic-as-vision-provider.md)).
- **Vision cost was overestimated by 12–35×** — measured at $0.000862/image.
- **The visual world is Matchday**, not the brief's direction
  ([ADR 0011](../decisions/0011-dark-first-visual-direction.md), reversed in part).

Do not edit the brief to match. A brief you keep editing stops being evidence of what
you believed and when.
