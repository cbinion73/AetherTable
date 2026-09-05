---
title: Verify and reconcile the AetherTable scaffold
type: chore
created: 2026-09-04
status: done
route: one-shot
---

# Verify and reconcile the AetherTable scaffold

## Intent

**Problem:** The requested project and initial scaffold already exist, but the README and PRD do not clearly distinguish the current implementation from the full requested platform. The project also lacks GDS configuration.

**Approach:** Preserve the existing AetherTable repository and its initial commit `bea798b`; reconcile the README, architecture, and product scope with the source; add GDS configuration for continued work. Multiplayer and multiple playable systems remain full-product requirements. This completed chore verifies the scaffold milestone only, not completion of the full game.

Verification on 2026-09-04: existing simulator test suite and iOS simulator app build both passed using Xcode 27. No physical-device or live Apple Intelligence behavior was tested in this change. All five independent adversarial review findings were patched: missing GDS output directory, inaccurate target count, overstated campaign-packet fidelity, stale playable-flow instructions, and overstated event merge semantics. No findings were deferred or rejected.

## Suggested Review Order

1. [README](../../README.md) — implementation status, remaining requirements, build instructions.
2. [Architecture](../Architecture.md) — actual module and synchronization boundaries.
3. [Product requirements](../PRD.md) — full product scope and incremental delivery.
4. [GDS configuration](../../_bmad/gds/config.yaml) — project and artifact locations.
