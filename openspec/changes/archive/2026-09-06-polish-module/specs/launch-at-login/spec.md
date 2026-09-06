# launch-at-login Specification

## Purpose

Register the app as a login item over `SMAppService.mainApp` behind a Domain port, with the registration status read live from the system every time it is shown and never persisted by the app. The status-item context menu carries a "Launch at Login" item whose checkmark mirrors that status and which routes the user to System Settings when approval is pending. Serves PRD F5, R1.5, R6.1, milestone M4. Proposal conventions 1, 2, 4, 8, 12, 13 apply.

## Requirements

### Requirement: LAL-1 Launch-at-login status value (Layer: Domain) — F5

`LaunchAtLoginStatus` MUST be a `nonisolated`, `Sendable`, `Equatable`, `CaseIterable` enum with exactly the cases `notRegistered`, `enabled`, `requiresApproval`, `notFound`. `isEnabled` MUST be `true` only for `.enabled`; `needsApproval` MUST be `true` only for `.requiresApproval`.

#### Scenario: Only enabled counts as enabled

- GIVEN every case of `LaunchAtLoginStatus`
- WHEN `isEnabled` is read
- THEN it is `true` for `.enabled` and `false` for the other three

#### Scenario: Only requiresApproval needs approval

- GIVEN every case of `LaunchAtLoginStatus`
- WHEN `needsApproval` is read
- THEN it is `true` for `.requiresApproval` and `false` for the other three

### Requirement: LAL-2 Launch-at-login port (Layer: Domain) — PRD 6.1, 6.4

The system MUST define a `LaunchAtLoginService` port with `var status: LaunchAtLoginStatus { get }`, `enable() throws`, `disable() throws` and `openLoginItemsSettings()`. The port MUST be `nonisolated` and `Sendable`. A Mutex-backed `FakeLaunchAtLoginService` MUST satisfy it, script the status, record every call and support `throwOnCall` (convention 4).

#### Scenario: Fake reports the scripted status

- GIVEN a fake scripted with `.requiresApproval`
- WHEN `status` is read
- THEN it is `.requiresApproval`

#### Scenario: Fake records and throws on demand

- GIVEN a fake scripted to throw on `enable()` call 0 (zero-based)
- WHEN `enable()` is called twice
- THEN the first call throws, the second succeeds and two `enable` calls are recorded

### Requirement: LAL-3 SMAppService adapter (Layer: Infrastructure) — F5, R6.1; conventions 8, 12, 13

`SMAppServiceLaunchAtLogin` MUST implement LAL-2 over `SMAppService.mainApp`: `status` MUST be read from the system on every access and MUST NOT be cached or persisted anywhere by the app; `enable()` registers, `disable()` unregisters, `openLoginItemsSettings()` opens the Login Items pane. The mapping from the system status MUST be a pure function: notRegistered → `.notRegistered`, enabled → `.enabled`, requiresApproval → `.requiresApproval`, notFound → `.notFound`. Unit and integration tests MUST NOT call `enable()` or `disable()` on the real adapter; only the `.integration` status read is exercised.

#### Scenario: Status mapping table

- GIVEN each of the four system status values
- WHEN mapped
- THEN the result is the LAL-1 case of the same name

#### Scenario: Live status read in the sandbox (`.integration`)

- GIVEN the real adapter inside the sandboxed test host
- WHEN `status` is read twice
- THEN both reads succeed without throwing and return one of the four LAL-1 cases

#### Scenario: Nothing persisted

- GIVEN a `UserDefaultsSettingsStore` that has saved a `Settings` value
- WHEN the suite's keys are listed
- THEN none of them refers to launch at login

### Requirement: LAL-4 Launch at Login menu item (Layer: Presentation) — R1.5, F5

The context menu (MBW-10) MUST contain an item titled "Launch at Login" whose state is derived from `LaunchAtLoginService.status` read when the menu is built: `.enabled` → on; `.notRegistered` and `.notFound` → off. For `.requiresApproval` the item MUST be off, its title MUST carry an annotation that approval is pending (exact wording design-owned) and its action MUST call `openLoginItemsSettings()` instead of toggling. Otherwise the action MUST call `disable()` when enabled and `enable()` when not. An error from `enable()` or `disable()` MUST NOT crash the app and MUST leave the item reflecting the live status on the next menu build.

#### Scenario: Enabled shows a checkmark

- GIVEN a fake service scripted with `.enabled`
- WHEN the context menu is built
- THEN the "Launch at Login" item state is on

#### Scenario: Not registered shows no checkmark

- GIVEN a fake scripted with `.notRegistered`
- WHEN the context menu is built
- THEN the item state is off and its title is exactly "Launch at Login"

#### Scenario: Approval pending routes to Login Items

- GIVEN a fake scripted with `.requiresApproval`
- WHEN the menu is built and the item's action fires
- THEN the item state is off, the title is annotated, `openLoginItemsSettings` was called once and `enable`/`disable` were not called

#### Scenario: Toggle on calls enable once

- GIVEN a fake scripted with `.notRegistered`
- WHEN the item's action fires
- THEN `enable` was called exactly once

#### Scenario: Toggle off calls disable once

- GIVEN a fake scripted with `.enabled`
- WHEN the item's action fires
- THEN `disable` was called exactly once

#### Scenario: Enable failure does not crash

- GIVEN a fake scripted with `.notRegistered` that throws on `enable()` call 0
- WHEN the item's action fires and the menu is rebuilt
- THEN no error propagates and the item state is off

#### Scenario: Status is re-read on every build

- GIVEN a fake whose scripted status changes from `.notRegistered` to `.enabled` between two menu builds
- WHEN the second menu is built
- THEN the item state is on

## Verification notes

- `LaunchAtLoginStatusTests` (Domain): LAL-1, parameterised over `allCases`.
- `FakeLaunchAtLoginService` under `system-monitorTests/Support`: LAL-2, with zero-based `throwOnEnable`/`throwOnDisable` sets (convention 4).
- `SMAppServiceLaunchAtLoginTests` (Infrastructure): LAL-3 mapping table as a pure unit test; the live status read tagged `.integration`; no `enable()`/`disable()` on the real adapter ever (convention 13). LAL-3 "Nothing persisted" lives in `UserDefaultsSettingsStoreTests`.
- `ContextMenuModelTests` (Presentation): LAL-4 title, state and action per `LaunchAtLoginStatus` case as a pure table over `ContextMenuModel.items(launchAtLogin:)`.
- `StatusItemControllerMenuTests` (Presentation): LAL-4 controller behaviour (`makeContextMenu()`, `toggleLaunchAtLogin()`, approval routing, error handling, live re-read) with the fake injected into `StatusItemController`; every `NSStatusItem` created is removed (convention 16).
- Test file names follow the design's File Changes table (`design.md`, revision 2).
- Manual: full round trip in System Settings including the `.requiresApproval` path; a stale `.notFound` item from a moved DerivedData build is expected during development.
