# Releasing System Monitor

How a version of System Monitor becomes something a stranger can download, and
what is true of that build by construction rather than by hope.

## 1. How a release happens

A pushed `v*` tag is the **only** thing that publishes. There is no manual step
between the push and the published asset, and no other trigger on the workflow:
it holds a Developer ID certificate and an App Store Connect key, so any trigger
a contributor could reach would hand both to whoever reached it.

Three files, split by ownership rather than by convenience:

| File | Owns |
|---|---|
| `.github/workflows/release.yml` | The runner, the secrets, the ephemeral keychain, cleanup, and publication — everything that only exists on CI |
| `scripts/release.sh` | The build sequence: archive → export → package → notarize → staple → verify |
| `scripts/appcast.sh` | The update feed: fetch, verify the pinned signing tool, sign one zip, merge one item, emit |

`scripts/release.sh` is a **rehearsal path, not a publishing path**. It contains
no version-control and no release-management invocation of any kind, so it can
neither select a repository nor publish, tag, or retract anything, whatever
directory it is run from. Running it locally produces the same artifact and
publishes nothing — that is what makes the rehearsal a rehearsal rather than an
approximation of one. `scripts/appcast.sh` carries the same prohibition, and
`AppcastScriptContractTests` asserts it.

The workflow invokes the build script **one phase per named step**, so a job log
has one step per stage and a failure names the stage that failed.

## 2. Prerequisites

None of these block merging the pipeline. All of them block the first release.

1. **The repository must be public before the first tag.** Release assets are
   only anonymously downloadable from a public repository, and macOS runner
   minutes are billed at 10× on a private one. The workflow refuses to run on a
   private repository — it fails with an explicit message before any signing or
   notarization work, so it never produces an asset nobody can download.
2. **A Developer ID Application certificate**, exported as a `.p12` **with its
   private key**. Xcode → Settings → Accounts → Manage Certificates → **+** →
   Developer ID Application, then export from Keychain Access.
3. **An App Store Connect API key** (`.p8`), **Developer** role. Note its key id
   and issuer id. One credential serves both `notarytool` and `xcodebuild`'s
   `-authenticationKey*` flags, it is independently revocable, and it never
   prompts for two-factor confirmation.
4. **Seven repository secrets**, named exactly:

   | Secret | Value |
   |---|---|
   | `BUILD_CERTIFICATE_BASE64` | `base64 -i DeveloperID.p12` |
   | `P12_PASSWORD` | The password used when exporting the certificate |
   | `KEYCHAIN_PASSWORD` | Any strong string; it protects the run's throwaway keychain |
   | `APPLE_API_KEY_P8` | The full contents of the App Store Connect `.p8` file |
   | `APPLE_API_KEY_ID` | The key id |
   | `APPLE_API_ISSUER_ID` | The issuer id |
   | `SPARKLE_PRIVATE_KEY` | The EdDSA private key printed by `generate_keys -x` (see 7) |

5. **Actions enabled**, with permission to write releases. The workflow declares
   `contents: write` and uses the run's own `GITHUB_TOKEN`; no personal token is
   involved.
6. **GitHub Pages enabled, with source = GitHub Actions.** Settings → Pages →
   Build and deployment → Source: **GitHub Actions**. This is what serves
   `https://juancasanueva.github.io/SWIFTUI_system_monitor/appcast.xml`, the feed
   every installed copy reads.

   The `github-pages` deployment environment must also allow the refs the
   release job runs on. It is created with a **branch** policy, and this job
   runs on **tag** refs (`v*`), so a deployment from a tag is rejected until a
   tag rule is added: Settings → Environments → `github-pages` → Deployment
   branches and tags → add a **tag** rule matching `v*`. Without it the four
   publication steps run and the deploy step fails at the end of an otherwise
   successful release.
7. **The Sparkle EdDSA key pair.**

   **System Monitor shares the existing key pair with Home-Cellar.** The public
   half is already committed, in `Resources/SystemMonitor-Info.plist` as
   `SUPublicEDKey`, and it is what every installed copy checks an update's
   signature against. `SPARKLE_PRIVATE_KEY` is the **same private key** that
   repository's release job uses; it lives in the login Keychain of the machine
   that generated it and is exported with:

   ```
   ./bin/generate_keys -x sparkle-private.key
   ```

   from the Sparkle 2.9.6 distribution, which is itself pinned by digest:

   ```
   curl -fsSLO https://github.com/sparkle-project/Sparkle/releases/download/2.9.6/Sparkle-2.9.6.tar.xz
   shasum -a 256 Sparkle-2.9.6.tar.xz    # 52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192
   tar -xJf Sparkle-2.9.6.tar.xz
   ```

   Move the exported file to offline storage or a password manager, then
   `rm -P sparkle-private.key`. Verify it once with `./bin/sign_update` against
   any zip before deleting the local copy.

   **This is a one-way door.** Losing the private key permanently severs the
   update channel for every copy already installed of **both** apps: rotation
   requires shipping a new `SUPublicEDKey` through some channel that is not
   Sparkle. The public key is *not* a secret — it is compiled into every copy —
   and must never be handled as one.

The team identifier `Z3S5JK8E38` lives in the repository and is not a secret.

## 3. Tag-and-release runbook

**Preflight.** `main` up to date, the suite green, and the version you are about
to tag is the version you mean.

```sh
git tag -a v1.0.0 -m "System Monitor 1.0.0"
git push origin v1.0.0
```

Then watch the run under the repository's Actions tab. The stages, in order:

| Stage | What it does | What stops the run |
|---|---|---|
| Private-repository gate | Refuses to publish an unreachable asset | The repository is not public |
| Distinct-commit gate | Asks the Pages deployments API whether this commit has already deployed the feed | This commit has deployed before (stable tags only) |
| Pin Xcode | Selects `Xcode_26.6.app`, the SDK a macOS 26.5 deployment target needs | The runner image no longer carries it |
| Archive | Release archive stamped with the tag and the run number | Any build failure |
| Export | Developer ID export, then gates version and architecture | `CFBundleShortVersionString` ≠ the tag, or any slice other than `arm64` |
| Package | `ditto` into `System-Monitor-<version>.zip` | — |
| Notarize | `notarytool submit --wait` | Apple rejects it; the diagnostic log is printed |
| Staple | Staples the ticket and repackages | Stapling fails |
| Verify | Eight gates against the copy extracted from the zip (the `spctl` assessment runs online here; the offline assessment is manual evidence) | Any gate |
| Publish | `gh release create --verify-tag --generate-notes` | — |
| Build the appcast | Signs the zip and writes the whole feed to a directory outside the checkout | Signing or emission fails (stable tags only) |
| Configure Pages / Upload | Uploads that directory as the `github-pages` artifact | — |
| Deploy to Pages | `actions/deploy-pages`, which deploys the artifact under this commit as its build version | The deployment reports a failure state, or its 10 minutes elapse |
| Cleanup | Deletes the keychain and the API key, always | — |

**Every stable release must be cut from its own commit.** GitHub Pages keys a
deployment by its *build version*, and the deployments API accepts only a build
version that is a commit in this repository — a `<commit>-<run number>` string
is rejected with a 404, and so is any invented SHA. The commit is therefore not
a default that could be improved on; it is the only value the API takes, and it
is exactly what `actions/deploy-pages` sends.

That leaves one hazard, and it is silent. Asking Pages to deploy a commit it has
already deployed does not fail: the request is accepted, the deployment reports
`succeed`, and the previously published site keeps being served. Two stable tags
can point at one commit, and on that path the second tag publishes a release,
uploads a correct feed, goes green, and leaves every installed copy reading the
older one.

The distinct-commit gate is what makes that impossible. It reads
`GET /repos/<owner>/<repo>/pages/deployments/<commit>` before anything is signed
or notarized. The endpoint answers `200` for any SHA, so the `status` in the
body is the discriminator: an empty string means the commit has never deployed
and the release may proceed; `succeed` means it has, and the run stops there —
before Apple is asked for a round trip and before a release exists on the tag.

**A failure publishes nothing.** Every gate runs before the publish step, so a
failed run leaves no release, no asset, and no draft. To retry, delete the
**tag** and tag again — on the same commit, which is fine here precisely because
the run never reached the deploy: no deployment exists for that commit yet, so
the distinct-commit gate still lets it through. Once a run *has* deployed the
feed, that commit is spent; the next version needs a new commit.

```sh
git push --delete origin v1.0.0
git tag -d v1.0.0
```

**Never delete or unflag a published release.** The Sparkle appcast points at
published assets, and unflagging one strands every installed copy that trusted
it. A bad release is withdrawn by cutting a new patch tag, and the automation is
structurally incapable of doing anything else: the only release-management
command in the workflow is `gh release create`.

A tag containing a hyphen (`v0.0.1-rc.1`) publishes as a **prerelease**, which
is how the pipeline is rehearsed against the real repository. A prerelease
publishes a release and **no feed entry**, so an installed copy is never offered
one.

## 4. Version policy

**The tag is the source of truth.** The workflow supplies both values at build
time:

- `MARKETING_VERSION` ← the tag with its leading `v` removed
- `CURRENT_PROJECT_VERSION` ← `GITHUB_RUN_NUMBER`, which only increases — so
  `CFBundleVersion` is strictly greater on every later release, including a
  re-cut tag for the same marketing version. That monotonicity is what the
  Sparkle version comparison needs.

**The project file is never bumped per release.** `MARKETING_VERSION` stays
`1.0.0` and `CURRENT_PROJECT_VERSION` stays `1` in `project.pbxproj`, so a
release changes no tracked file and leaves no commit behind.

The cost, recorded rather than left as a trap: **a local Release build reports
`1.0.0 (1)` forever**, and the About window shows exactly that regardless of the
current tag. To produce a correctly stamped local build, override both on the
command line:

```sh
xcodebuild archive -project system-monitor.xcodeproj -scheme system-monitor -configuration Release -archivePath build/system-monitor.xcarchive MARKETING_VERSION=1.2.3 CURRENT_PROJECT_VERSION=42
```

## 5. Local rehearsal

```sh
# `all` includes `notarize`, so the App Store Connect key is required even for a rehearsal.
VERSION=1.0.0 BUILD_NUMBER=1 \
ASC_KEY_PATH=~/.private_keys/AuthKey_XXXXXXXXXX.p8 ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=<issuer-uuid> \
scripts/release.sh all

# Without the key, rehearse the phases that need none:
VERSION=1.0.0 BUILD_NUMBER=1 SIGNING_STYLE=manual scripts/release.sh archive
```

| Variable | Required for | Meaning |
|---|---|---|
| `VERSION` | all phases | Marketing version, e.g. `1.0.0` |
| `BUILD_NUMBER` | `archive`, `export`, `verify` | `CURRENT_PROJECT_VERSION` |
| `ASC_KEY_PATH` | `notarize`; also `archive`/`export` under automatic signing | Path to the App Store Connect `.p8` |
| `ASC_KEY_ID` | as above | App Store Connect key id |
| `ASC_ISSUER_ID` | as above | App Store Connect issuer id |
| `SIGNING_STYLE` | optional, default `manual` | `manual` pins the Developer ID identity on the archive line; `automatic` adds `-allowProvisioningUpdates` and the three `-authenticationKey*` flags |
| `RELEASE_BUILD_DIR` | optional, default `build` | Output root; excluded from version control |

Phases: `archive`, `export`, `package`, `notarize`, `staple`, `verify`, and
`all`. Each can be run on its own, which is how a failing stage is reproduced
without repeating the ones before it.

The feed step rehearses the same way, and needs no repository:

```sh
VERSION=1.0.0 BUILD_NUMBER=1 GITHUB_REF_NAME=v1.0.0 \
ASSET_URL=https://github.com/juancasanueva/SWIFTUI_system_monitor/releases/download/v1.0.0/System-Monitor-1.0.0.zip \
ZIP_PATH=build/System-Monitor-1.0.0.zip \
FEED_URL=https://juancasanueva.github.io/SWIFTUI_system_monitor/appcast.xml \
OUTPUT_DIR=/tmp/site SPARKLE_PRIVATE_KEY="$(cat ~/offline/sparkle-private.key)" scripts/appcast.sh
```

`SIGNING_STYLE` defaults to `manual`, and `scripts/release.sh` refuses to run
when it disagrees with `signingStyle` in `scripts/ExportOptions.plist` — the two
are one decision expressed twice, and a build that signs one way and exports
another fails late, after Apple has been asked for a round trip.

## 6. Entitlements and hardened runtime

**The posture.** Hardened runtime **on**, app sandbox **off**. The sandbox
prevents an app from replacing its own bundle, and in-app updates are exactly
that: Sparkle downloads the new build and swaps it in place. Both are pinned in
the project file and asserted by `system-monitorTests`, and the delivered bundle
is re-checked at release time: the run fails, publishing nothing, if the
hardened-runtime flag is missing or an app-sandbox entitlement is present.

**There is no `.entitlements` file in this repository, and none is added.** The
entitlements dictionary the delivered build carries is the one Xcode
synthesises. Three hardened-runtime exceptions are **deliberately absent**:

- `allow-jit`
- `allow-unsigned-executable-memory`
- `disable-library-validation`

None is required. System Monitor reads Mach, IOKit and `sysctl` counters through
public C APIs in its own address space, and Sparkle is a signed framework
embedded in the bundle and loaded by the ordinary dynamic loader. That is
neither just-in-time compilation nor foreign, unsigned code loaded into the
process, so no hardened-runtime exception applies.

**`ENABLE_USER_SELECTED_FILES` and `REGISTER_APP_GROUPS`.** Both are set in the
project file (`readonly` and `YES`), and both are sandbox-era settings sitting
inert beside a disabled sandbox. The first one **does** emit an entitlement —
`com.apple.security.files.user-selected.read-only` — but with
`ENABLE_APP_SANDBOX = NO` it grants nothing and costs nothing, because that
entitlement is only meaningful inside a sandbox. They matter as a tripwire:
introducing **any** `.entitlements` file would make them live, which is why the
absence of such a file is asserted by a test rather than left to discipline.

**The rule going forward.** No entitlement is added without a measured failure
that requires it, and every addition is visible in the notarization audit trail.

**Measured evidence.** None yet. The first notarized build has not been cut, so
this section states the *intended* posture and the gates that enforce it, and
deliberately quotes no `codesign` output it has not seen. Record the accepted
`spctl` assessment, the `codesign -dvvv` line and the complete entitlements
dictionary here after the first stable tag, replacing this paragraph.

## 7. The contract the delivery channels inherit

The update feed and the Homebrew cask both bind against these, and none of them
may change without a coordinated change there:

| Property | Value |
|---|---|
| Asset URL | `https://github.com/juancasanueva/SWIFTUI_system_monitor/releases/download/v<version>/System-Monitor-<version>.zip` |
| Asset name | `System-Monitor-<version>.zip`, exactly one per release |
| Bundle inside it | `System-Monitor.app`, display name `System-Monitor`, executable `Contents/MacOS/System-Monitor` |
| Bundle identifier | `com.juancasanueva.system-monitor` |
| Version stamping | `CFBundleShortVersionString` = tag minus `v`; `CFBundleVersion` = run number, strictly increasing |
| Signature | Developer ID Application, team `Z3S5JK8E38`, hardened runtime, notarized and stapled |
| Floor | macOS 15.0, Apple Silicon (`arm64` only) for the app executable; the embedded `Sparkle.framework` is universal, which does not change the floor |
| Update feed | `https://juancasanueva.github.io/SWIFTUI_system_monitor/appcast.xml`, republished by the same job on every **stable** tag; a prerelease publishes a release and no feed entry |

The feed's minimum system version is emitted by `scripts/appcast.sh` as
`MINIMUM_SYSTEM_VERSION="15.0"` and required by the offline validator as
`AppcastDocument.expectedMinimumSystemVersion`. A test reads both and fails when
they disagree, because a feed emitted with a floor the validator rejects is a
feed every installed copy refuses — discovered only after publication.

The release job gains **no cross-repository reach**: it names no repository
other than the one it runs in, declares no dispatch, and holds no credential for
the tap. The tap keeps itself current by **pulling** (§8). That keeps the
seven-secret set closed and keeps a successful, notarized release from being
reported as a failure because of a channel that is not on the critical path.

**A Pages deploy is a full-site replacement.** A Pages deployment serves
whatever the uploaded artifact contains and nothing else, so the release job is
the *only* thing that may deploy to Pages. If a landing page is ever wanted, it
must be built by this same job into the same artifact directory; a second
workflow deploying a site would silently overwrite `appcast.xml` and every
installed copy would stop finding updates.

## 8. The Homebrew tap

The second delivery channel. It publishes **no second artifact**: the cask points
at the same `System-Monitor-<version>.zip` §7 specifies.

| Thing | Value |
|---|---|
| Tap repository | `juancasanueva/homebrew-system-monitor` (public) |
| Tap name | `juancasanueva/system-monitor` |
| Cask token | `system-monitor` |
| Canonical install | `brew tap juancasanueva/system-monitor`, then `brew trust juancasanueva/system-monitor`, then `brew install --cask system-monitor` |
| Unambiguous form | `brew install --cask juancasanueva/system-monitor/system-monitor` |
| Installed path | `/Applications/System-Monitor.app` — the same bundle name the zip carries |

**Homebrew 6 requires tap trust.** It refuses to load a cask from a non-official
tap until the tap is trusted, so the short install form needs
`brew trust juancasanueva/system-monitor` first. Naming the tap or the
fully-qualified cask on the command line is itself the grant.

**A direct-download copy blocks a plain install.** A user who dragged the zip
already has `/Applications/System-Monitor.app` — the same path and the same
bundle name the cask installs — and `brew install --cask system-monitor` stops
with `It seems there is already an App at '/Applications/System-Monitor.app'`
rather than overwrite an app it did not place. The documented answer is
`brew install --cask --adopt system-monitor`. Adoption moves nothing and
compares nothing: Homebrew skips the bundle-version check for casks that declare
`auto_updates`, so a copy Sparkle has already carried past the cask's `version`
is adopted as-is. That is the intended outcome, since the next `brew upgrade`
also defers to Sparkle for this cask. `--adopt` cannot be combined with
`--force`.

### How the cask stays current

The tap's `bump.yml` runs on a schedule and on `workflow_dispatch`. It **pulls**:
it reads this repository's `releases/latest` anonymously, exits 0 when the cask
already declares that version, downloads the published asset, computes the
checksum from those bytes, rewrites `version` and `sha256`, runs `brew style`
and both audits, and only then commits.

Three properties are deliberate:

1. **Nothing here pushes to it.** `release.yml` names no other repository and
   holds no credential for one. A missed scheduled run is corrected by the next;
   a missed dispatch would have been lost forever.
2. **The checksum comes from the published asset**, not from the build runner.
   That proves the URL a stranger will use serves exactly those bytes.
3. **It is idempotent on `version`**, so repeated runs produce at most one
   commit per release. It never tags, never releases here, and never touches
   Pages, so it cannot interact with the distinct-commit gate of §3.

The `releases/latest` read is unauthenticated, so it draws on GitHub's anonymous
per-IP API allowance. Two dispatches in the same minute can return `403` and
fail the run. That failure is inert by design: nothing is committed, and the next
run recomputes the same answer from scratch.

### Manual fallback

If the tap's Actions are down, the bump is two lines and one command:

```sh
gh release view --repo juancasanueva/SWIFTUI_system_monitor --json tagName --jq .tagName
curl -fsSLO https://github.com/juancasanueva/SWIFTUI_system_monitor/releases/download/v<version>/System-Monitor-<version>.zip
shasum -a 256 System-Monitor-<version>.zip
# edit version and sha256 in Casks/system-monitor.rb, then, from a checkout tapped
# into $(brew --repository)/Library/Taps/juancasanueva/homebrew-system-monitor:
brew style juancasanueva/system-monitor
brew audit --cask --online --strict juancasanueva/system-monitor/system-monitor
git commit -am "chore(cask): system-monitor <version>" && git push
```

Never commit a checksum that the online audit has not verified.

### What an uninstall removes

`brew uninstall --cask --zap system-monitor` removes the bundle and the roots
the cask's `zap` stanza declares. System Monitor's only persistent state is its
`UserDefaults` domain, `com.juancasanueva.system-monitor`, plus the caches macOS
frameworks write under the same identifier. Every one of them derives from the
bundle identifier and from no product name.

System Monitor creates **no Keychain items**, so nothing survives an uninstall
in the Keychain. That is worth stating rather than leaving to inference: a
missing "and here is what we cannot remove" section reads as an omission, not as
an absence.

## 9. Troubleshooting

**Notarization rejected.** The run prints `notarytool log` output for the failed
submission before it exits. The usual causes are an unsigned nested binary, a
missing hardened-runtime flag, or a signature made with the wrong identity.
Nothing was published; fix, delete the tag, tag again.

**Keychain import failed.** Either `BUILD_CERTIFICATE_BASE64` is not the base64
of a `.p12` exported **with its private key**, or `P12_PASSWORD` does not match
it. Re-export from Keychain Access and re-encode.

**The archive fails on the deployment target.** The app targets macOS 15.0, and
the SDK that can build it ships with Xcode 26.6. If the runner image drops
`/Applications/Xcode_26.6.app`, the Pin Xcode step fails immediately — which is
the right place to fail. Update the pin rather than lowering the target.

**Signing failed locally.** `SIGNING_STYLE=manual` needs a *Developer ID
Application* identity in the login keychain; `security find-identity -v -p
codesigning` lists what is there. Automatic signing needs the App Store Connect
key instead, and `scripts/ExportOptions.plist` must be switched to
`signingStyle = automatic` in the same change — the script refuses to run when
the two disagree. Flipping the project file itself to Manual is a different and
larger decision: it would break the Debug/Release parity that
`system-monitorTests` asserts, so that assertion must be **explicitly relaxed**
— with the reason recorded in the test — rather than deleted.

**The run stopped at the distinct-commit gate.** This commit has already
deployed the update feed, and Pages will not deploy it twice. Nothing is wrong
with the tag: put the new version on a new commit and tag that. There is no flag
to force the deployment, because forcing it is the failure — Pages would accept
the request, report `succeed`, and keep serving the old feed.

**The run is green but the feed still advertises the previous version.** The
gate makes the stale-feed case unreachable for a stable tag, so the remaining
explanation is the CDN: the deployment succeeded and the edge has not yet
purged. Compare `last-modified` on the feed URL before assuming otherwise. If
the feed really is stale, check that the run was a stable tag at all — a
hyphenated tag skips every publication step, the deploy included, by design.

**`spctl` accepts locally but a downloader sees a refusal.** The published
archive must be the post-staple one. `scripts/release.sh staple` deletes the
pre-notarization zip before repackaging precisely because `ditto` into an
existing archive path adds to it rather than replacing it.
