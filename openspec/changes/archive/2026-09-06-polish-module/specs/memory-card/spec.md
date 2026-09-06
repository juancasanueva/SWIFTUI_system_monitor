# Delta for memory-card

Purpose unchanged. This delta promotes MC-10's reduce-motion rule from inspection-only to a unit-testable model decision (debt from the M3 verify report), mirroring the `cpu-card` delta.

## MODIFIED Requirements

### Requirement: MC-10 Card surface and reduce motion (Layer: Presentation) — R2.3, 7.1, PRD 6.5

The card MUST use `cardBackground` with a 12 pt corner radius and no border. Animations MUST be disabled when `accessibilityReduceMotion` is on, using the same mechanism as `CPUCard`: `MemoryCardModel.gaugeAnimation(reduceMotion:)` MUST return `nil` when reduce motion is on and the card's standard gauge animation otherwise, and the view MUST apply exactly that result.
(Previously: the rule was applied inline in the view and the scenario was verifiable only by inspection.)
Non-destructive: the original scenario is retained; archive should still confirm the merge.

#### Scenario: Reduce motion

- GIVEN `reduceMotion == true`
- WHEN `MemoryCardModel.gaugeAnimation(reduceMotion:)` is evaluated
- THEN the result is `nil` and the gauge value changes without animation

#### Scenario: Motion allowed

- GIVEN `reduceMotion == false`
- WHEN `MemoryCardModel.gaugeAnimation(reduceMotion:)` is evaluated
- THEN the result is non-nil and equals the CPU card's gauge animation

## Verification notes

- `MemoryCardModelTests` (Presentation, existing file): both scenarios; existing MC-1..MC-9 tests unchanged. Test file names follow the design's File Changes table (`design.md`, revision 2).
- The environment-to-model wiring in `MemoryCard` remains inspection-only.
