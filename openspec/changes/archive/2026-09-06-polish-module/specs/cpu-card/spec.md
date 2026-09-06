# Delta for cpu-card

Purpose unchanged. This delta promotes the reduce-motion rule from an inspection-only environment check to a unit-testable model decision (debt from the M3 verify report, MC-10 twin).

## MODIFIED Requirements

### Requirement: Palette and card surface (Layer: Presentation) — 7.1, R2.3, PRD 6.5

`Palette` MUST expose the section 7.1 tokens as constants; the card MUST use `cardBackground` with a 12 pt corner radius and no border. Animations MUST be disabled when `accessibilityReduceMotion` is on. The animation choice MUST live in `CPUCardModel.gaugeAnimation(reduceMotion:)`, which MUST return `nil` when reduce motion is on and the card's standard gauge animation otherwise; the view MUST apply exactly that result and MUST NOT decide the animation itself.
(Previously: the reduce-motion rule was applied inline in the view and verifiable only by inspection.)
Non-destructive: the original scenario is retained; archive should still confirm the merge.

#### Scenario: Token values

- GIVEN `Palette`
- WHEN `cpuAccent`, `cpuEfficiency`, `cardBackground`, `textSecondary` are read
- THEN they equal `#4D8DFF`, `#3FC1C9`, `#1A2131`, `#8A93A6`

#### Scenario: Reduce motion yields no animation

- GIVEN `reduceMotion == true`
- WHEN `CPUCardModel.gaugeAnimation(reduceMotion:)` is evaluated
- THEN the result is `nil`

#### Scenario: Motion allowed yields the gauge animation

- GIVEN `reduceMotion == false`
- WHEN `CPUCardModel.gaugeAnimation(reduceMotion:)` is evaluated
- THEN the result is non-nil

## Verification notes

- `CPUCardTests` (Presentation, existing file): both `gaugeAnimation(reduceMotion:)` scenarios; existing token and row tests unchanged. Test file names follow the design's File Changes table (`design.md`, revision 2).
- The view keeps reading `@Environment(\.accessibilityReduceMotion)` and passes it to the model; that wiring remains inspection-only.
