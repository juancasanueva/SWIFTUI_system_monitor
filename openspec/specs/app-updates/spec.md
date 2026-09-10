# app-updates Specification

## Purpose

What must be true of System Monitor's in-app update surface: what feed the running bundle trusts and how that trust is fixed, when the app is allowed to reach the network to look for an update, what the user can always do by hand, what the update surfaces are allowed to say, and what the update code is allowed to reach. Serves PRD milestone "Ship". The updater framework is confined to a single Infrastructure adapter behind a Domain port, so every requirement below is stated as an observable property of the app and never as a property of Sparkle. Proposal conventions 1, 2, 4, 6, 9, 10, 14, 15 apply to every type and test named here. How the appcast is produced, signed and published, and how the release workflow injects versions, belong to the release slice and are deliberately absent.

## Requirements

### Requirement: AU-1 Updater port (Layer: Domain) — PRD 6.1, 6.4

The system MUST define an `AppUpdating` port with exactly four members: `canCheckForUpdates: Bool { get }`, `automaticallyChecksForUpdates: Bool { get set }`, `lastUpdateCheckDate: Date? { get }` and `checkForUpdates()`. The port MUST be `@MainActor`, MUST refine `AnyObject` so every surface observes one instance, and MUST refine `Observable` so a view holding `any AppUpdating` still re-renders through the existential. No surface MAY name a type from the updater framework; an in-memory `FakeAppUpdater` MUST satisfy the port for tests (convention 4).

#### Scenario: The automatic-check flag round-trips

- GIVEN an updater whose automatic-check flag is off
- WHEN the flag is set to on and read back, then to off and read back
- THEN it reports on and then off

#### Scenario: Readiness is independent of automatic checking

- GIVEN one updater that can check with automatic checking off, and one that cannot check with automatic checking on
- WHEN both are read
- THEN readiness follows `canCheckForUpdates` alone and never the automatic-check flag

#### Scenario: The recorded check date starts absent

- GIVEN an updater that has never checked
- WHEN its recorded check date is read
- THEN it is `nil`, and it reports a date only after a check is recorded

### Requirement: AU-2 The update dependency is declared once and pinned (Layer: App) — PRD 6.1

`system-monitor.xcodeproj` MUST declare exactly one remote package reference to `https://github.com/sparkle-project/Sparkle`, pinned with `kind = exactVersion` at `2.9.6`, linked to the app target through exactly one build file and one product dependency. The project MUST NOT contain a copy-files (Embed Frameworks) build phase: the framework embeds itself, and a second embed silently double-signs it.

Both app configurations MUST agree, because a Debug build that differs proves nothing about a Release one: `ENABLE_APP_SANDBOX = NO` (the updater replaces the bundle in place), `ENABLE_HARDENED_RUNTIME = YES`, `ARCHS = arm64`, `PRODUCT_NAME = "System-Monitor"`, `INFOPLIST_KEY_CFBundleDisplayName = "System-Monitor"` and `PRODUCT_MODULE_NAME = system_monitor`, so renaming the product never renames the Swift module the tests import. The unit-test bundle's `TEST_HOST` MUST name the renamed host.

#### Scenario: Exactly one pinned package, with no embed phase

- GIVEN the project file
- WHEN its package references are inspected
- THEN exactly one Sparkle reference exists, pinned to exact version 2.9.6
- AND exactly one build file and one product dependency link it to the app target
- AND no copy-files build phase exists

#### Scenario: Both app configurations ship unsandboxed on Apple Silicon

- GIVEN the two app-target build configurations
- WHEN their build settings are inspected
- THEN both declare `ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES` and `ARCHS = arm64`
- AND neither declares `ENABLE_APP_SANDBOX = YES`

#### Scenario: The product is renamed without renaming the module

- GIVEN the two app-target build configurations and the two unit-test configurations
- WHEN their build settings are inspected
- THEN both app configurations declare `PRODUCT_NAME = "System-Monitor"`, `INFOPLIST_KEY_CFBundleDisplayName = "System-Monitor"` and `PRODUCT_MODULE_NAME = system_monitor`
- AND both test configurations point `TEST_HOST` at `System-Monitor.app/Contents/MacOS/System-Monitor`

### Requirement: AU-3 The feed the running app trusts is fixed inside the bundle (Layer: App) — PRD 6.4

The running bundle MUST carry, readable from its own information dictionary, both the update feed location and the public key used to verify update signatures. Both MUST be merged into the generated information dictionary from a partial property list at `Resources/SystemMonitor-Info.plist` that carries **exactly those two keys**, with `GENERATE_INFOPLIST_FILE = YES` still in force in both app configurations so the merge never becomes a replacement.

The feed location MUST be exactly `https://juancasanueva.github.io/SWIFTUI_system_monitor/appcast.xml`; an `http` feed, a feed on another host, or a missing feed MUST be treated as a build defect that fails a test rather than as a runtime condition to recover from. The verification key MUST base64-decode to exactly 32 bytes.

Neither value MUST be overridable at run time: no user setting, environment variable, command-line argument, configuration file, updater delegate, or network response MUST be able to substitute a different feed or a different verification key. A key supplied at run time is a key an attacker can supply. The public key is public by construction — it ships inside every copy of the app — and MUST NOT be handled as a secret; the corresponding private key MUST NOT exist anywhere in the repository in any form.

The bundle MUST also report `LSApplicationCategoryType` as `public.app-category.utilities`.

#### Scenario: The bundle carries the exact feed URL

- GIVEN the running application bundle's information dictionary
- WHEN the update feed value is read
- THEN it is exactly `https://juancasanueva.github.io/SWIFTUI_system_monitor/appcast.xml` and its scheme is `https`

#### Scenario: The bundle carries a well-formed verification key

- GIVEN the running application bundle's information dictionary
- WHEN the update public key value is read
- THEN it is present, non-empty, and base64-decodes to exactly 32 bytes

#### Scenario: Nothing in the app can substitute a different feed or key

- GIVEN every Swift file of the app target, with comments stripped
- WHEN it is inspected for an updater delegate, a per-call feed URL, a feed setter, or either bundle key by name
- THEN none of them appears

#### Scenario: The repository carries exactly one key-shaped literal

- GIVEN every text file in the repository outside version-control internals and build output
- WHEN it is searched for a 44-character base64 literal, the shape a raw Ed25519 key has
- THEN exactly one is found, in the partial property list, and it is the bundled public key

### Requirement: AU-4 Automatic checks stay off until the user asks (Layer: Infrastructure) — PRD 6.4

An update check is network egress. Automatic update checking MUST be **off on a fresh install** and MUST stay off until the user turns it on.

The app's own persisted setting MUST be the authority. It MUST live under the key `updates.automaticChecksEnabled` in an injected `UserDefaults` domain, a missing key MUST read as `false`, turning it off MUST record a stored `false` rather than remove the key, and the preference MUST write that one key and nothing else. At every launch the app MUST write that setting to the updater — unconditionally and exactly once — so that neither a value baked into the bundle nor a value the updater framework persisted on its own can decide whether the app reaches the network. The write MUST happen **before** the updater starts, so the framework's own second-launch prompt asking the user to enable automatic checks never appears.

No bundled key MUST enable automatic checking: `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate` and `SUScheduledCheckInterval` MUST be absent from the partial property list and from the merged bundle.

#### Scenario: A fresh install does not check automatically

- GIVEN a defaults domain with no stored update preference
- WHEN the preference is read
- THEN automatic update checking is off, and no key exists in the domain

#### Scenario: The user's choice survives a relaunch

- GIVEN a user who has turned automatic update checking on
- WHEN the preference is read back through a second reader over the same domain
- THEN it still reads as on, and turning it off and reading back reads as off

#### Scenario: The persisted preference is written to the updater at launch

- GIVEN a persisted preference and an updater whose automatic-check flag currently disagrees with it
- WHEN the launch-time policy runs
- THEN the updater's flag equals the preference, written exactly once
- AND this holds for both the on and the off case, and for a run where the two already agree

#### Scenario: The preference is applied before the updater starts

- GIVEN the source of the updater adapter, with comments stripped
- WHEN the order of its two calls is inspected
- THEN the preference is applied before the updater is started, and the controller is created without starting itself

#### Scenario: No bundled default can enable checking

- GIVEN the partial property list and the running bundle's information dictionary
- WHEN both are inspected
- THEN the partial property list carries exactly the feed and the key
- AND neither carries any key that enables automatic checking

### Requirement: AU-5 An explicit update check is always reachable (Layer: Presentation) — R1.5, R6.4

An explicit user action is its own consent, so a **"Check for Updates…"** item MUST be present in the status-item context menu on every launch — including when automatic checking is off, which is the default. It MUST be the second item, directly after "About System Monitor" (MBW-10).

The item MUST be disabled **only** while a check genuinely cannot run, which in practice means a check is already in flight. It MUST NOT be disabled because automatic checking is off, because no update was found last time, or because the app has never checked. The decision MUST come from a pure `UpdateCommandEnablement.isEnabled(canCheckForUpdates:)` and from nothing else; the menu MUST apply that answer and MUST NOT let AppKit's own item validation override it. The readiness MUST be re-read on every menu build. Choosing the item MUST start exactly one check. With no updater injected the item MUST still be present, disabled, and inert rather than absent.

#### Scenario: The command is enabled exactly while a check can run

- GIVEN an updater that can check, and one that cannot
- WHEN the menu is built for each
- THEN the update item is enabled for the first and disabled for the second
- AND every other item stays enabled in both cases

#### Scenario: Automatic checking does not decide the command's enablement

- GIVEN two updaters that can check and differ only in their automatic-check flag
- WHEN the enablement rule is evaluated for each
- THEN both are enabled

#### Scenario: Readiness is re-read on every build

- GIVEN a menu built from an updater that cannot check
- WHEN the updater becomes able to check and the menu is built again
- THEN the item is disabled in the first build and enabled in the second

#### Scenario: Invoking the command starts exactly one check

- GIVEN a menu built from an updater that can check
- WHEN the update item's action fires once
- THEN exactly one update check is started

#### Scenario: Without an updater the item is present and inert

- GIVEN a controller built with no updater
- WHEN the menu is built and the update item fires
- THEN the menu still carries five action items, the update item is disabled, and firing it does nothing

### Requirement: AU-6 No update surface states something untrue, and no inert surface is rendered (Layer: Presentation) — R6.3

Every update surface MUST describe the state the app is actually in. An app that has never checked MUST say so in words — `"Never checked"` — and MUST NOT display a fabricated, defaulted, or zero date; the wording MUST contain no digits. Once a check has completed the surface MUST report that check, as `"Last checked "` followed by a relative phrase derived from the recorded date. The wording MUST come from a pure `UpdateCheckPresentation` value over an injected `now`, so the label is a function of its two dates and never of the clock.

The settings form MUST render an **Updates** section containing exactly two rows, both with behaviour behind them: a toggle titled "Check for updates automatically" (accessibility identifier `updates-automatic-toggle`) bound to the updater's automatic-check flag, and a "Last check" row (accessibility identifier `updates-last-checked`) showing that label. Any control the design sketches for a capability the app does not have — notably an update-channel picker — MUST be absent rather than present-but-inert. The section MUST be rendered only when an updater reaches the form through the environment; with none, the section MUST be absent and the rest of the form unchanged.

#### Scenario: A never-checked app says so

- GIVEN no recorded last-check date
- WHEN the last-checked text is produced
- THEN it is `"Never checked"` and contains no digit

#### Scenario: A checked app reports the date it checked

- GIVEN three different recorded last-check dates against one fixed `now`
- WHEN the last-checked text is produced for each
- THEN each begins with `"Last checked "` and the three labels are distinct

#### Scenario: The label is a pure function of the two dates

- GIVEN the same pair of dates twice
- WHEN the label is produced twice
- THEN the two values are equal

#### Scenario: The toggle writes through in both directions

- GIVEN an updater with automatic checking off
- WHEN the toggle's intent commits on and then off
- THEN the updater's flag follows, with one write per commit

#### Scenario: The Updates section renders only with an updater

- GIVEN the settings form with an updater and the same form without one
- WHEN both are measured
- THEN the form with an updater is taller and the form without one is unchanged in width
- AND the section declares exactly the two accessibility identifiers and no channel picker

#### Scenario: The window presents the whole three-section form

- GIVEN a settings window given an updater
- WHEN it is shown for the first time
- THEN its content is `SettingsView.formWidth` wide and at least as tall as both `SettingsView.formHeight` and the form's own fitting height

### Requirement: AU-7 The updater reaches nothing but the updater (Layer: App) — PRD 6.1

The dependency on the third-party updater framework MUST be confined to **exactly one file**, `SparkleUpdateChecker.swift`, proven by a source sweep over the comment-stripped app target rather than by convention. No other file MUST import it and no file outside it MUST name its updater types. No `Presentation` file MUST name the concrete checker; only the adapter and the composition root MUST name it at all.

The composition root MUST build exactly one updater and hand that instance to both the status-item controller and the settings window. It MUST expose a substitution seam so that a test launching the real delegate never constructs the real checker, and therefore can never start an updater, reach the feed, write the user's real preference, or open the framework's window.

#### Scenario: Exactly one file imports the updater framework

- GIVEN every Swift file of the app target, with comments stripped
- WHEN imports of the updater framework are counted
- THEN exactly one file imports it, and it is `SparkleUpdateChecker.swift`

#### Scenario: No user-interface file names the framework's types

- GIVEN the same sweep
- WHEN it is inspected for the framework's updater and updater-controller types
- THEN none appears outside the adapter
- AND no `Presentation` file names the concrete checker, which only the adapter and the composition root do

#### Scenario: One updater reaches both surfaces

- GIVEN a launched composition root
- WHEN the updater held by the delegate, by the status-item controller and by the settings window are compared
- THEN all three are the same instance

#### Scenario: The context menu drives that updater

- GIVEN a launched composition root
- WHEN the context menu's "Check for Updates…" item fires
- THEN exactly one check is started on the delegate's updater

## Verification notes

- `AppUpdatingTests` and `UpdatePolicyTests` (Domain): AU-1, and the AU-4 and AU-5 decisions, driven over `FakeAppUpdater` under `system-monitorTests/Support`.
- `UpdateCheckPresentationTests` (Presentation): AU-6 wording, with `now` injected so every case is deterministic.
- `AutomaticUpdateChecksTests` (Infrastructure): AU-4 persistence, with a unique `suiteName` per test and `removePersistentDomain(forName:)` cleanup (convention 14).
- `BundleUpdateKeysTests`, `UpdateProjectFileTests`, `UpdateKeyMaterialTests` and `UpdateCompositionTests` (App): the structural halves of AU-2, AU-3, AU-4 and AU-7, each self-contained and anchored to `#filePath` because the test runner promises nothing about the working directory.
- `ContextMenuModelTests` and `StatusItemControllerMenuTests` (Presentation): AU-5, as the pure table and as real `NSMenuItem`s.
- `SettingsViewTests` and `SettingsWindowControllerTests` (Presentation): AU-6, including the floor `SettingsView.formHeight` must clear.
- `AppDelegateCompositionTests` (App): AU-7's composition half, with every case injecting `FakeAppUpdater` through the delegate's seam.
- Manual: an installed build actually replaces itself from the published feed. No harness can cover it until a tag is published and the feed is live; it is a release checklist item, not an open defect.
