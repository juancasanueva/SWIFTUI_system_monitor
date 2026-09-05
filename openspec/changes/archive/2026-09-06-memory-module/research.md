---
schema: gentle-ai.sdd-research/v1
change: memory-module
project: system-monitor
revision: 2
status: done
outcome: q1-answered; q2-answered; q3-answered
phase: sdd-research
collected_on: 2026-09-05
collector: sdd-research (Fable 5.1)
persistence: orchestrator-owned
supersedes_revision: 1
admission:
  schema: gentle-ai.sdd-research-capability/v1
  change: memory-module
  grants:
    documentation: granted   # WebFetch of vendor documentation and source headers (Apple docs, XNU/opensource.apple.com, Swift Evolution)
    open-web: granted        # WebSearch + WebFetch of third-party sources (GitHub repos, Apple Developer Forums, blog posts)
  persistence: orchestrator-owned
observed_grants:
  documentation: used   # WebFetch: support.apple.com, developer.apple.com, raw.githubusercontent.com (apple-oss-distributions/xnu, swiftlang/swift-foundation, swiftlang/swift-evolution)
  open-web: used        # WebSearch + WebFetch: github.com (zfdang/free-for-macOS, swiftlang/swift issue), api.github.com, developer.apple.com/forums, forums.swift.org, cpufun.substack.com
questions:
  - id: Q1
    lane: primary
    classes: [documentation, open-web]
    text: How does macOS Activity Monitor compute Memory Used, App Memory, Wired Memory, Compressed and Cached Files from host_statistics64(HOST_VM_INFO64) / vm_statistics64 fields, and what is the size and explanation of the App+Wired+Compressed vs Memory Used gap on Apple Silicon?
  - id: Q2
    lane: secondary
    classes: [documentation]
    text: Is referencing the C global vm_kernel_page_size a Swift 6 strict-concurrency diagnostic (warning or error), and do host_page_size() and sysctl hw.pagesize return the same value (16384 on arm64, 4096 on x86_64)? Which page size do vm_statistics64 counts use?
  - id: Q3
    lane: secondary
    classes: [documentation]
    text: Which Foundation ByteCountFormatStyle configuration reproduces Activity Monitor's display (e.g. "8 GB", "5.52 GB")? Does .memory use base 1024, how are units labelled, what is FormatInput, and how does locale affect output?
---

# Research: memory-module

## Outcome

- Q1: **answered**. The formula set confirmed by the product decision is documented (definitions) by Apple and implemented verbatim by an open-source clone; the "speculative pages are inside free_count" rule is stated in the XNU header. The Apple Silicon gap is quantified by one field report and given a first-party mechanism (boot-time memory carve-outs) by XNU's sysctl source.
- Q2: **answered**. Page-size API semantics are sourced from XNU (`host_page_size()` returns `vm_kernel_page_size`; `hw.pagesize` returns the calling task's map page size); concrete values (16 KiB arm64 kernel maximum, observed `hw.pagesize: 16384` on M1; 4096 on x86_64) are sourced from XNU headers and a field measurement. Swift 6 strict-concurrency treatment of imported C globals is sourced from SE-0412 plus two field reports; the proposal text ("warning") and observed behaviour ("error") disagree and are recorded as contradiction X3. Design conclusion: call `host_page_size()` rather than referencing the global.
- Q3: **answered** from the swift-foundation source and Apple's ByteCountFormatStyle reference.

## Sources

| id | class | title | publisher | URL | accessed_at | excerpt |
|----|-------|-------|-----------|-----|-------------|---------|
| S1 | documentation | View memory usage in Activity Monitor on Mac (Activity Monitor User Guide) | Apple Inc. | https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac | 2026-09-05 | "Memory Used: The amount of RAM being used. To the right, you can see where the memory is allocated." / "App Memory: The amount of memory being used by apps." / "Wired Memory: Memory required by the system to operate. This memory can't be cached and must stay in RAM, so it's not available to other apps." / "Compressed: The amount of memory that has been compressed to make more RAM available." / "Cached Files: The size of files cached by the system into unused memory to improve performance. Until this memory is overwritten, it remains cached, so it can help improve performance when you reopen the app." |
| S2 | documentation | xnu `osfmk/mach/vm_statistics.h` (main branch) | Apple Inc. (apple-oss-distributions) | https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/vm_statistics.h | 2026-09-05 | `natural_t free_count; /* # of pages free */` ... `natural_t wire_count; /* # of pages wired down */` ... `natural_t purgeable_count; /* # of pages purgeable */` `natural_t speculative_count; /* # of pages speculative */` ... `natural_t compressor_page_count; /* # of pages used by the compressed pager to hold all the compressed data */` ... `natural_t external_page_count; /* # of pages that are file-backed (non-swap) */` `natural_t internal_page_count; /* # of pages that are anonymous */` — and: "speculative pages are already accounted for in 'free_count', so 'speculative_count' is the number of 'free' pages that are used to hold data that was read speculatively from disk but haven't actually been used by anyone so far." |
| S3 | open-web | free-for-macOS `free.c` | zfdang (GitHub) | https://github.com/zfdang/free-for-macOS/blob/master/free.c | 2026-09-05 | `host_page_size(host, &page_size)`; free: `(vm_stat.free_count - vm_stat.speculative_count) * page_size`; wired: `vm_stat.wire_count * page_size`; cached: `(vm_stat.purgeable_count + vm_stat.external_page_count) * page_size`; app: `(vm_stat.internal_page_count - vm_stat.purgeable_count) * page_size`; used: `hbi.max_mem - (vm_stat.free_count - vm_stat.speculative_count + vm_stat.purgeable_count + vm_stat.external_page_count) * page_size` |
| S4 | open-web | "Memory used does not add up on M1 mac in activity monitor" (thread 702498) | Apple Developer Forums (user post, 0 replies) | https://developer.apple.com/forums/thread/702498 | 2026-09-05 | On Intel, App Memory + Wired + Compressed ≈ Memory Used; on M1: App memory 4.21 GB + Wired 983.4 MB + Compressed 137.3 MB = 5.3 GB, while Activity Monitor shows Memory Used = 5.88 GB (about 0.58 GB unaccounted). No replies. |
| S5 | documentation | xnu `bsd/kern/kern_mib.c` (main branch) | Apple Inc. (apple-oss-distributions) | https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_mib.c | 2026-09-05 | macOS: `SYSCTL_QUAD(_hw, HW_MEMSIZE, memsize, ..., &max_mem_actual, "");` `SYSCTL_QUAD(_hw, OID_AUTO, memsize_usable, ..., &max_mem, "");` Comment: "historically macOS's hw.memsize provided the value of the actual physical memory size, whereas on non-macOS it is the memory size minus any carveouts." `sysctl_pagesize`: `vm_map_t map = get_task_map(current_task()); long long l = vm_map_page_size(map);` `sysctl_pagesize32`: `#if __arm64__ l = (long long) (1 << page_shift_user32); #else l = (long long) PAGE_SIZE;` |
| S6 | documentation | xnu `libsyscall/mach/mach_init.c` (main branch) | Apple Inc. (apple-oss-distributions) | https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/mach/mach_init.c | 2026-09-05 | `vm_size_t vm_kernel_page_size = 0; vm_size_t vm_kernel_page_mask = 0; int vm_kernel_page_shift = 0; vm_size_t vm_page_size = 0; vm_size_t vm_page_mask = 0; int vm_page_shift = 0;` In `mach_init_doit()`: `vm_kernel_page_shift = COMM_PAGE_READ(uint8_t, KERNEL_PAGE_SHIFT); vm_kernel_page_size = 1 << vm_kernel_page_shift;` arm64: `vm_page_shift = COMM_PAGE_READ(uint8_t, USER_PAGE_SHIFT_64); vm_page_size = 1 << vm_page_shift;` And: `kern_return_t host_page_size(__unused host_t host, vm_size_t *out_page_size) { *out_page_size = vm_kernel_page_size; return KERN_SUCCESS; }` |
| S7 | documentation | swift-foundation `Sources/FoundationInternationalization/Formatting/ByteCountFormatStyle.swift` (main branch) | Swift project (swiftlang) | https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationInternationalization/Formatting/ByteCountFormatStyle.swift | 2026-09-05 | `public func format(_ value: Int64) -> String`; `public enum Style: Int, Codable, Hashable, Sendable { case file = 0; case memory; case decimal; case binary }` ("memory": "The style for representing memory usage"); `switch style { case .file, .decimal: decimal = true; case .memory, .binary: decimal = false }` then `decimal ? bestUnit.decimalSize : bestUnit.binarySize`; binary sizes `[1, 1024, 1048576, 1073741824, ...]`, binary thresholds `[1023, 1048063, 1073689395, ...]`; precision: `.byte, .kilobyte: "."`, `.megabyte: ".#"`, default `".##"`; ICU skeleton `"measure-unit/digital-\(bestUnit.name)"` for all styles; `Locale` parameter; `localizedParens()` for `includesActualByteCount`. |
| S8 | documentation | ByteCountFormatStyle — Foundation reference | Apple Inc. (Apple Developer Documentation) | https://developer.apple.com/documentation/foundation/bytecountformatstyle | 2026-09-05 | `init(style: ByteCountFormatStyle.Style, allowedUnits: ByteCountFormatStyle.Units, spellsOutZero: Bool, includesActualByteCount: Bool, locale: Locale)`; example: `let count: Int64 = 1024; count.formatted(.byteCount(style: .memory)) // "1 kB"`; example with `.memory`, `allowedUnits: [.kb]`, `spellsOutZero: true`, `Locale(identifier: "en_US")` over `[0, 1024, 2048, 4096, 8192, 16384, 32768, 65536]` → `["Zero kB", "1 kB", "2 kB", "4 kB", "8 kB", "16 kB", "32 kB", "64 kB"]`. |
| S9 | documentation | SE-0412: Strict concurrency for global variables | Swift project (swift-evolution) | https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md | 2026-09-05 | Status: "Implemented (Swift 5.10)", "Upcoming Feature Flag: `GlobalConcurrency` (Enabled in Swift 6 language mode)". Rule: "require every global variable to either be isolated to a global actor or be both: 1. immutable 2. of `Sendable` type". "Note that imports from other languages are implicitly `@preconcurrency`." "Any use of a `@preconcurrency import`ed concurrency-unsafe global variable will produce a warning at the use site." "Importing a module via `@preconcurrency import` suppresses any potential errors resulting from data isolation checking of imported global variables that lack explicit concurrency annotations." "There remain tools for enforcing safety for imported global variables from other languages, such as isolating to a global actor using for example `__attribute__((swift_attr("@MainActor")))` in C or Obj-C, or wrapping access within a safer API that declares the correct isolation or locks appropriately." "The attribute `nonisolated(unsafe)` can be used to annotate the global variable (or any form of storage)". |
| S10 | open-web | "Accessing C global variable with Swift 6 strict Concurrency" (thread 77512) | Swift Forums (forums.swift.org), user post with replies incl. Quinn "The Eskimo!" (Apple DTS) | https://forums.swift.org/t/accessing-c-global-variable-with-swift-6-strict-concurrency/77512 | 2026-09-05 | Posted 2025-01-28. Compiler output for the imported C global `environ` (from `<unistd.h>`): `error: reference to var 'environ' is not concurrency-safe because it involves shared mutable state` (no "; this is an error in Swift 6" suffix). Replies: wrap access in C function calls (`getenv()`/`setenv()`) instead of touching the global; Quinn: `environ` "It's not safe and never can be", and `getenv`/`setenv` have internal locking on Darwin while direct `environ` access cannot participate in it. |
| S11 | open-web | swiftlang/swift issue #72187: "`@preconcurrency import` doesn't suppress warning on use of imported global variable" | swiftlang/swift (GitHub issue; state via api.github.com) | https://github.com/swiftlang/swift/issues/72187 | 2026-09-05 | State: open; created 2024-03-08; labels bug, concurrency; Swift 5.10. Diagnostic: "Reference to static property 'screenChanged' is not concurrency-safe because it involves shared mutable state; this is an error in Swift 6". Comments: reporter found the cause was import order (`import SwiftUI` before `@preconcurrency import UIKit`); Doug Gregor (2024-06-14): "The ordering issue is addressed by https://github.com/apple/swift/pull/74413, but we're not modeling the submodule import (of UIKit.UIAccessibility) completely." |
| S12 | documentation | Addressing architectural differences in your macOS code | Apple Inc. (Apple Developer Documentation) | https://developer.apple.com/documentation/apple-silicon/addressing-architectural-differences-in-your-macos-code | 2026-09-05 | "Instead of hardcoding values related to the underlying system, fetch those values dynamically from system global variables whenever possible. For example, fetch the size of virtual memory pages from the `vm_page_size` global variable." / "Some features of Apple silicon are decidedly different than those of Intel-based Mac computers ... Virtual memory page sizes are different. Fetch the value from the `vm_page_size` global variable." |
| S13 | documentation | xnu `osfmk/mach/arm/vm_param.h` (main branch) | Apple Inc. (apple-oss-distributions) | https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/arm/vm_param.h | 2026-09-05 | `#define PAGE_MAX_SHIFT 14` `#define PAGE_MAX_SIZE (1 << PAGE_MAX_SHIFT)` `#define PAGE_MIN_SHIFT 12` `#define PAGE_MIN_SIZE (1 << PAGE_MIN_SHIFT)`; default: `extern int PAGE_SHIFT_CONST; #define PAGE_SHIFT PAGE_SHIFT_CONST; #define PAGE_SIZE (1 << PAGE_SHIFT)`; with `__ARM_16K_PG__`: `#define PAGE_SHIFT ARM_PGSHIFT`. |
| S14 | documentation | xnu `osfmk/mach/i386/vm_param.h` (main branch) | Apple Inc. (apple-oss-distributions) | https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/i386/vm_param.h | 2026-09-05 | `#define I386_PGBYTES 4096 /* bytes per 80386 page */` `#define I386_PGSHIFT 12 /* bitshift for pages */` `#define PAGE_SIZE I386_PGBYTES` `#define PAGE_SHIFT I386_PGSHIFT` |
| S15 | open-web | "More M1 fun: hardware information" | cpufun (Substack), Jim Cownie, 2021-02-17 | https://cpufun.substack.com/p/more-m1-fun-hardware-information | 2026-09-05 | `sysctl` dump on a Mac mini M1: "hw.pagesize: 16384", "hw.pagesize32: 16384", "hw.memsize: 8589934592"; the article notes the 16 KiB page differs from the x86_64 default of 4 KiB. |

## Validated claims

### Q1 — Activity Monitor memory categories

- C1 [S1]: Apple documents "Memory Used" as "The amount of RAM being used" and presents its allocation to the right as three categories: App Memory, Wired Memory and Compressed. Cached Files is documented separately as file cache placed "into unused memory" that "remains cached" until overwritten, i.e. it is not part of Memory Used.
- C2 [S2]: `vm_statistics64` exposes the raw counters used by every mapping below: `free_count`, `wire_count`, `purgeable_count`, `speculative_count`, `compressor_page_count`, `external_page_count` ("file-backed (non-swap)") and `internal_page_count` ("anonymous"). All are `natural_t` page counts.
- C3 [S2]: The XNU header states that speculative pages "are already accounted for in 'free_count'", and that `speculative_count` is the number of those free pages holding speculatively read disk data. This is the documented basis for computing `Free = free_count - speculative_count` when "free" is meant as truly unused memory.
- C4 [S3]: The open-source `free` clone for macOS (which reproduces Activity Monitor's summary) implements: Free = `(free_count - speculative_count) * page_size`; Wired = `wire_count * page_size`; Cached Files = `(purgeable_count + external_page_count) * page_size`; App Memory = `(internal_page_count - purgeable_count) * page_size`; Used = `max_mem - (free_count - speculative_count + purgeable_count + external_page_count) * page_size`, i.e. Used = Total - Free - Cached. This matches the confirmed product formula exactly.
- C5 [S3, S2]: Compressed corresponds to `compressor_page_count` ("# of pages used by the compressed pager to hold all the compressed data"); the `free` clone's (commented-out) dump exposes the same counter. Wired corresponds to `wire_count`.
- C6 [S4]: On an M1 Mac (2022 report), App Memory 4.21 GB + Wired 983.4 MB + Compressed 137.3 MB = 5.3 GB while Activity Monitor displayed Memory Used = 5.88 GB, a gap of roughly 0.58 GB (about 10 % of Memory Used on that machine); the same poster reports the three categories summing to Memory Used on Intel. The thread has no answer from Apple.
- C7 [S5]: XNU's sysctl layer documents that on macOS `hw.memsize` exposes `max_mem_actual` ("the actual physical memory size") whereas `hw.memsize_usable` exposes `max_mem`, which is "the memory size minus any carveouts". Consequently, any "Used = Total - Free - Cached" computation whose Total is the actual physical memory (`hw.memsize`) counts boot-time carve-outs (memory never managed as pages by the VM pager) as used, while the App/Wired/Compressed counters cannot contain them. This is a first-party mechanism that produces a positive App+Wired+Compressed vs Memory Used gap. Whether it accounts for the entire 0.58 GB in C6 is not verified (see Uncertainty).
- C8 [S3, S6]: Both the `free` clone and XNU's own `host_page_size()` use the kernel page size (`vm_kernel_page_size`) when converting `vm_statistics64` counts to bytes.

### Q2 — page size and Swift 6

- C9 [S6]: `host_page_size()` is a user-space libsyscall function that returns the global `vm_kernel_page_size` and `KERN_SUCCESS`; it does not perform a Mach call.
- C10 [S6]: `vm_page_size` and `vm_kernel_page_size` are distinct, non-`const` `vm_size_t` C globals (with `int` shifts) initialised at process start in `mach_init_doit()` from separate comm-page fields (`USER_PAGE_SHIFT_64`/`USER_PAGE_SHIFT_32` vs `KERNEL_PAGE_SHIFT`). Because they derive from different fields, the user page size and the kernel page size can legitimately differ for a given process.
- C11 [S5]: `sysctl hw.pagesize` returns `vm_map_page_size()` of the calling task's map (the caller's user page size), and on arm64 `hw.pagesize32` returns `1 << page_shift_user32`. Therefore `hw.pagesize` and `host_page_size()` read different quantities (task map page size vs kernel page size); they coincide only when the task's map page size equals the kernel page size.
- C12 [S6]: Because `vm_kernel_page_size` is a mutable C global written during `mach_init_doit()`, code that must avoid touching a mutable global under strict concurrency can obtain the identical value by calling the function `host_page_size(mach_host_self(), &size)` instead (C9).
- C19 [S9]: SE-0412 (implemented in Swift 5.10, enabled by default in Swift 6 language mode via the `GlobalConcurrency` upcoming feature) requires every global variable to be either global-actor-isolated or both immutable and `Sendable`. A mutable `vm_size_t` C global such as `vm_kernel_page_size` (C10) fails the immutability half of that rule, so a direct reference is subject to the diagnostic.
- C20 [S9]: The proposal states that "imports from other languages are implicitly `@preconcurrency`" and that "Any use of a `@preconcurrency import`ed concurrency-unsafe global variable will produce a warning at the use site", with `@preconcurrency import` suppressing "any potential errors" from isolation checking of unannotated imported globals. By the proposal text, referencing an imported C global should therefore yield a warning, not an error, in Swift 6 mode.
- C21 [S10]: Observed behaviour (2025-01-28) for an imported C global under Swift 6 strict concurrency: the compiler emitted `error: reference to var 'environ' is not concurrency-safe because it involves shared mutable state`. Apple DTS (Quinn) confirmed `environ` is genuinely unsafe to touch directly; the accepted workaround was to route access through C function calls (`getenv`/`setenv`) rather than the global.
- C22 [S11]: In Swift 5.10, an imported (UIKit) global/static accessed despite `@preconcurrency import` produced "Reference to static property 'screenChanged' is not concurrency-safe because it involves shared mutable state; this is an error in Swift 6"; the cause was import-order/submodule modelling, partially fixed by swift PR 74413 (Doug Gregor, 2024-06-14), and the issue remains open. Suppression of the diagnostic for imported globals is therefore not reliable across import configurations.
- C23 [S9, S10, S12]: For imported C globals the available mitigations are on the C side (`__attribute__((swift_attr("@MainActor")))`) or wrapping access in a function API; Swift-side `nonisolated(unsafe)` annotates a declaration and is not applicable to a declaration the module does not own. For page size the wrapping API already exists: `host_page_size()` (C9, C12). Apple's guidance to read the page size dynamically (S12) is satisfied equally by that call.
- C24 [S13, S14]: XNU's kernel page-size constants are architecture-specific: on arm64 `PAGE_SHIFT` is the runtime-selected `PAGE_SHIFT_CONST` (or `ARM_PGSHIFT` when built with `__ARM_16K_PG__`), bounded by `PAGE_MIN_SHIFT 12` (4096 B) and `PAGE_MAX_SHIFT 14` (16384 B); on i386/x86_64 `PAGE_SIZE` is the fixed `I386_PGBYTES 4096`.
- C25 [S15, S5, S13]: A Mac mini M1 reports `hw.pagesize: 16384` and `hw.pagesize32: 16384`. Since `hw.pagesize` is the calling task's map page size (C11) and 16384 is the arm64 kernel maximum (C24), the kernel page size on that Apple Silicon Mac is 16384 and a native arm64 process shares it; on x86_64 Macs both are 4096 (C24). Inference: `host_page_size()` and `hw.pagesize` agree for native processes on both architectures; divergence is only possible where the task map page size is smaller than the kernel's (C10, C11).
- C26 [S12]: Apple explicitly warns that "Virtual memory page sizes are different" between Apple silicon and Intel Macs and instructs developers to fetch the value at run time rather than hard-coding it.

### Q3 — ByteCountFormatStyle

- C13 [S7, S8]: `ByteCountFormatStyle.FormatInput` is `Int64` (`format(_ value: Int64) -> String`); the public initialiser is `init(style:allowedUnits:spellsOutZero:includesActualByteCount:locale:)`.
- C14 [S7]: `.memory` and `.binary` styles divide by binary unit sizes (1024, 1 048 576, 1 073 741 824, ...); `.file` and `.decimal` divide by 1000-based sizes.
- C15 [S7, S8]: Unit labels come from ICU "digital" measure units (`measure-unit/digital-kilobyte` etc.) for all styles, so the binary `.memory` style still prints "kB", "MB", "GB" (never "KiB"/"MiB"); Apple's reference example shows `Int64(1024).formatted(.byteCount(style: .memory)) == "1 kB"`.
- C16 [S7]: Fraction digits depend on the chosen unit: bytes and kB use 0 fraction digits ("."), MB up to 1 (".#"), GB and above up to 2 (".##"); "#" digits are optional, so exact values print without trailing zeros. Derived arithmetic (from C14/C16, not a separate source): 8 589 934 592 B = 8 × 1024³ → "8 GB"; a value of 5 926 000 000 B → 5.519 GiB → "5.52 GB".
- C17 [S7]: Unit selection walks `allowedUnits` in ascending order and stops at the first unit whose binary threshold (1023, 1 048 063, 1 073 689 395, ...) exceeds the absolute value, so values just under a unit boundary (e.g. 1 073 689 395 B and above) already render in the next unit ("1 GB").
- C18 [S7, S8]: Output is locale-dependent through the `locale` parameter (ICU number formatting, localized parentheses for `includesActualByteCount`); `spellsOutZero: true` renders zero as "Zero kB" in `en_US`.

## Contradictions

- X1: S1 (Apple) describes Memory Used as allocated across App + Wired + Compressed, while S4 shows a concrete Apple Silicon case where the three categories sum to less than Memory Used. S5 supplies a mechanism (carve-outs included in actual physical memory) consistent with S3's "Total - Free - Cached" implementation rather than with a literal sum of the three categories. The confirmed product formula (Used = Total - Free - Cached) is therefore the one consistent with S3 and S4; a literal App + Wired + Compressed sum would under-report on Apple Silicon.
- X2: `hw.pagesize` (S5, task map page size) and `host_page_size()` (S6, kernel page size) are commonly assumed to be the same value; XNU shows they are different variables. No admitted source demonstrates a macOS process where they differ (see G2 note under Gaps; S15 shows them equal for a native arm64 process).
- X3: SE-0412 (S9) says an implicitly `@preconcurrency`-imported concurrency-unsafe global produces a *warning* at the use site and that `@preconcurrency import` suppresses errors; field evidence shows an *error* for the imported C global `environ` under Swift 6 (S10) and a Swift 5.10 warning carrying the "this is an error in Swift 6" suffix for an imported static despite `@preconcurrency import` (S11, still open). Resolution adopted for this change: treat a direct reference to `vm_kernel_page_size`/`vm_page_size` as a build-breaking diagnostic in Swift 6 mode and avoid it via `host_page_size()` (C12, C23); the disagreement itself is left to upstream.

## Uncertainty

- U1: It is not established from an admitted source that Activity Monitor's "Physical Memory"/Total is `hw.memsize` (= `max_mem_actual`) rather than `hw.memsize_usable` or `host_basic_info.max_mem`. The carve-out mechanism (C7) explains a positive gap qualitatively; the magnitude in C6 (0.58 GB on an 2022 M1 machine) is a single unanswered report and may also include kernel-managed pages that are neither internal, external, wired, compressed nor free.
- U2: The `vm_statistics64` header (S2) does not state the page unit; the inference that counts are in kernel pages rests on the kernel counting its own pages and on S3/S6 using `host_page_size()`. Third-party tools that multiply by `vm_page_size` (not admitted) give identical results only where user and kernel page sizes coincide.
- U3: Whether Activity Monitor itself uses `ByteCountFormatStyle`/`ByteCountFormatter` with the `.memory` style is not documented; C13–C18 establish only that `.memory` reproduces the base-1024, "kB/MB/GB", two-decimal display convention.
- U4: The observed `error:` in S10 concerns `environ`, whose Swift type is a non-`Sendable` pointer; `vm_kernel_page_size` is a `Sendable` `vm_size_t`. Both fail SE-0412's immutability requirement, but no admitted source shows the exact severity for a `Sendable` mutable imported C global in Swift 6 language mode. X3's resolution (avoid the global) is robust to either outcome.
- U5: S15 is a single 2021 measurement on one M1 machine; `PAGE_SHIFT_CONST` is runtime-selected on arm64 (S13), so the 16384 value is treated as the observed Apple Silicon Mac configuration, not a compile-time guarantee — consistent with Apple's instruction to read it dynamically (S12).

## Freshness

- S1: current Apple user guide, undated page (accessed 2026-09-05).
- S2, S5, S6, S13, S14: `main` branch of apple-oss-distributions/xnu as of 2026-09-05; the quoted declarations (`vm_statistics64` fields, `host_page_size`, `hw.memsize`/`hw.memsize_usable`, page-size constants) are long-standing APIs.
- S3: repository master branch; implementation predates Apple Silicon but uses only stable APIs.
- S4: user report from 2022, unanswered as of access.
- S7: swift-foundation `main` as of 2026-09-05 (the implementation shipped in Foundation for macOS 13+/Swift 5.9+ era; behaviour may drift in future releases).
- S8, S12: current Apple reference pages (accessed 2026-09-05).
- S9: proposal marked "Implemented (Swift 5.10)"; text as of 2026-09-05.
- S10: forum thread dated 2025-01-28; compiler version not stated by the poster.
- S11: issue opened 2024-03-08 against Swift 5.10; still open as of 2026-09-05 (state read via GitHub API).
- S15: measurement published 2021-02-17 on macOS Big Sur-era firmware.

## Gaps

- G1, G2: converted into claims C19–C26 and contradiction X3 in revision 2 (no longer open).
- G3 (Q1, corroboration not admitted): htop `darwin/Platform.c` (active = `internal_page_count - purgeable_count`, compressed = `compressor_page_count`, wired = `wire_count`, multiplied by `vm_page_size`); nickdowell/vm_info `Sources/vm_info/vm_info.swift` (same formula set as S3, Total = `ProcessInfo.processInfo.physicalMemory`, page size via `host_page_size`); exelban/stats `Modules/RAM/readers.swift` uses a different decomposition (`used = active + inactive + speculative + wired + compressed - purgeable - external`, `app = used - wired - compressed`) that does not match Apple's App Memory definition.
- G4 (Q1, Total source): `host_basic_info.max_mem` is filled from `machine_info.max_mem` (xnu `osfmk/kern/host.c`); whether that equals `max_mem` or `max_mem_actual` on macOS was not traced. Design should decide between `hw.memsize`, `hw.memsize_usable` and `ProcessInfo.physicalMemory` explicitly and record which one Activity Monitor's "Physical Memory" matches on the developer's machine.
- G5 (Q3, locale evidence): swift-foundation tests (`Tests/FoundationInternationalizationTests/Formatting/ByteCountFormatStyleTests.swift`, not admitted) show `.memory` in `fr_FR` producing "1 ko", "1 Mo", "1 Go" and `zh_TW` "1 kB（1,024 byte）" — locale changes unit words and parentheses.

## Risks

- R1: If the module's Total uses `hw.memsize_usable` while Activity Monitor uses actual physical memory (or vice versa), Memory Used will differ by the carve-out size (hundreds of MB on Apple Silicon) even with an identical formula (C7, U1).
- R2: Multiplying `vm_statistics64` counts by `vm_page_size` instead of `host_page_size()` would under-report by 4× for any process whose user page size is 4 KiB while the kernel uses 16 KiB (C10, C11, C24).
- R3: Referencing the mutable C global `vm_kernel_page_size` (or `vm_page_size`) directly is diagnosed under Swift 6 strict concurrency — at least a warning by SE-0412's text and an error in observed builds (C19–C22, X3); `host_page_size()` avoids it (C12, C23).
- R4: `.memory` style renders exact multiples without trailing zeros ("8 GB", not "8.00 GB") and switches units slightly below 1 GiB (C16, C17); tests asserting fixed decimal places or byte-exact unit boundaries will fail.
- R5: `natural_t` is 32-bit; page-count arithmetic such as `internal_page_count - purgeable_count` must be done in a wider type (or saturating) to avoid wraparound when counters are sampled non-atomically (S2 field types; htop uses `saturatingSub`, G3).

## Next recommended

1. Proceed to `sdd-propose`: amend PRD R4.2 with the formula set (C3, C4, C5) citing S1–S3, and add the "Used includes memory not visible in App/Wired/Compressed" note citing S4/S5.
2. In design, read page size with `host_page_size(mach_host_self(), &size)` (C9, C12, C23) and never reference `vm_page_size`/`vm_kernel_page_size` directly (X3); read Total from a single documented sysctl and record the choice (G4); format with `ByteCountFormatStyle(style: .memory)` on `Int64` (C13–C16).
3. Add a unit test asserting the page size read at run time is one of 4096 or 16384 (C24, C25) rather than hard-coding either value (C26).

## Product choices (orchestrator-owned, non-authoritative restatement)

These decisions were confirmed by the user before research (Engram 8218, `state.yaml`) and are restated here only for traceability; research neither re-decided nor validated them as product choices:

- Used formula matches Activity Monitor: Used = Total - Free - Cached, with Free = `free_count - speculative_count` and Cached = `external_page_count + purgeable_count`.
- The memory card graph is placed at the bottom of the card.
- Memory publishes on its first sampling iteration.

Research finding relative to these choices: the Used/Free/Cached formula is consistent with S1–S3 and with the Apple Silicon behaviour reported in S4 (see X1); no admitted source contradicts it.
