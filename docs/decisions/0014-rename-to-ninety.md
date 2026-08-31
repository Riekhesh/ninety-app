# ADR 0014 — Rename the product from Notch to Ninety

**Status:** Locked
**Date:** 2026-08-31
**Phase:** 0 → 1 boundary

## Context

"Notch" named a mechanic that no longer exists. The tier badge was a shield with N
notches cut into its edge, and the name was the mechanic's tally-mark reading: a notch
is "one more than before". [ADR 0012](0012-tier-carried-by-count-not-colour.md) recorded
that tie explicitly.

The Matchday redesign replaced the badge with **stacked chevrons**
([ADR 0011](0011-dark-first-visual-direction.md), reversed in part). Nothing on any
screen is a notch any more, so the name described nothing.

This is the last cheap moment to change it. No app has shipped, no bundle ID is
registered with the App Store, no user knows the product by either name. In three
months the same decision costs a migration.

## Decision

**The product is Ninety.**

Ninety minutes: a football reference for anyone who wants one, and a clean number for
anyone who does not.

## Reasoning

**The name should not carry the metaphor — the app already does.** The interior is
committed football: Matchday, Sub On, The Table, The Squad, On the Bench, First and
Second Half, Form, Divisions. A name that also shouted football would read as a
*football* app, and the closest rejected candidates ("Match Fit", "Matchday") collide
directly with existing App Store football-stats apps. Confusing a calorie tracker for a
five-a-side stats logger is a real acquisition cost, not a hypothetical one.

**Descriptive names are weak names, and taken ones.** "Baseline" was the most
on-thesis candidate and is already occupied. Names that describe the product are the
names everyone else also thought of; Strava, Whoop, Oura and Zwift all mean nothing and
all work. The App Store's 30-character subtitle is where description belongs:
*"Ranked on consistency, not calories."*

**Ninety splits its audience deliberately.** Someone who follows football gets the
reference immediately and feels let in on something. Someone who does not sees a
confident number and is not misled about the category. That split was the explicit
requirement.

**It survives the interior.** "The full ninety" — going the distance rather than coming
off — is the consistency thesis in three words, available whenever the copy wants it.

## Trade-off accepted

**The name means nothing until the product explains it.** A first-time reader learns
nothing from "Ninety" that they would have learned from "Calorie Rank". That cost is
carried by the subtitle and the icon, and it is the same trade every strong consumer
name makes.

**A rename is never free even when it is cheap.** 344 occurrences across docs, tokens,
the Python package, the Swift generator and the design specs. Done in one pass; the
risk is a missed reference surfacing later, which is why the token namespace
(`ninety.*`) and the package (`ninetyvision`) were renamed together rather than left as
"we'll get to it".

**The GitHub repository is still `Notch-App`.** Renaming it is the owner's action, not
a commit. GitHub redirects the old URL, so nothing breaks if it is never done.

## Reversal trigger

- An App Store or trademark conflict on "Ninety" in class 9 that a subtitle cannot
  resolve. Record the conflicting mark.
- Phase 3 testers cannot say what the app is after a week of use *and* name recall is
  the identified cause. Naming is not usually the cause; record the evidence rather
  than assuming it.

A dislike of the name is not a trigger. This one was chosen against a stated brief —
ownable, not football-confusable, not already taken — and it meets all three.
