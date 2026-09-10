import SwiftUI

/// One card slot of the detail panel, top to bottom.
///
/// The order lives in `PanelView.cards` as a pure array, the panel analogue of
/// `DiskCardModel.sections`: "CPU, Memory, Disk, Network" (DC-1, NC-1) is an
/// assertion on a value rather than a rendering inspection, and the body is a
/// switch, so the two cannot drift apart.
nonisolated enum PanelCard: Sendable, Equatable, CaseIterable, Identifiable {
    case cpu
    case memory
    case disk
    case network

    var id: Self { self }
}

/// The detail panel shown in the popover.
///
/// Container view: it reads `MetricsState` from the environment and hands plain
/// values to the presentational cards, so every card keeps updating while the
/// popover is open. The panel grows with its cards, and each card renders its
/// full skeleton before its first reading, so the popover does not resize when
/// a snapshot lands.
///
/// Four cards no longer fit every display, so the panel accepts an optional
/// `maxHeight` (NC-12). It is a plain number rather than an `NSScreen` read:
/// `StatusItemController` resolves it per show through `PanelLayout`, which
/// keeps AppKit out of this view and leaves it renderable in previews and in
/// `NSHostingView` tests.
struct PanelView: View {

    @Environment(MetricsState.self) private var state

    /// Height the panel is pinned to, or `nil` when it fits its screen.
    ///
    /// `nil` is not "no limit applied": it is the whole uncapped branch, and the
    /// tree it builds is byte-identical to the one this view had before the cap
    /// existed. That is what keeps the DC-11 fitting-height assertions measuring
    /// the same panel.
    var maxHeight: CGFloat? = nil

    /// Card order, top to bottom (DC-1, NC-1).
    nonisolated static let cards: [PanelCard] = [.cpu, .memory, .disk, .network]

    private static let width: CGFloat = 320
    private static let spacing: CGFloat = 12
    private static let padding: CGFloat = 12

    var body: some View {
        if let maxHeight {
            // The cap is only ever supplied when the cards are known to
            // overflow it, so a fixed frame is what guarantees the scroll
            // rather than relying on the scroll view's ideal size. The
            // background is repeated here so the popover chrome stays painted
            // if the content is ever shorter than the frame.
            ScrollView(.vertical) {
                cardsStack
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: Self.width, height: maxHeight)
            .background(Palette.panelBackground)
        } else {
            cardsStack
        }
    }

    private var cardsStack: some View {
        VStack(spacing: Self.spacing) {
            ForEach(Self.cards) { card in
                self.card(card)
            }
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .background(Palette.panelBackground)
    }

    @ViewBuilder
    private func card(_ card: PanelCard) -> some View {
        switch card {
        case .cpu: CPUCard(snapshot: state.cpu, history: state.cpuHistory)
        case .memory: MemoryCard(snapshot: state.memory, history: state.memoryHistory)
        case .disk: DiskCard(snapshot: state.disk)
        case .network:
            NetworkCard(
                snapshot: state.network,
                downloadHistory: state.networkDownloadHistory,
                uploadHistory: state.networkUploadHistory
            )
        }
    }
}

/// What the popover hosts.
///
/// The `StatusItemRootView` analogue for the panel: the controller keeps one
/// `NSHostingController<PanelRootView>` for the app's whole life and swaps this
/// value to change the cap, which is why the cap can be resolved per show
/// without retyping or rebuilding the hosting controller — and therefore
/// without a second `show` (MBW-13).
struct PanelRootView: View {

    let state: MetricsState

    /// Resolved by `StatusItemController` from the presenting screen (NC-12).
    var maxHeight: CGFloat? = nil

    var body: some View {
        PanelView(maxHeight: maxHeight)
            .environment(state)
    }
}

#Preview("Panel — no snapshot") {
    PanelView()
        .environment(MetricsState())
}

#Preview("Panel — live snapshot") {
    let state = MetricsState()
    let cores = (0..<8).map { CoreUsage(index: $0, usage: 0.7, level: .performance) }
        + (8..<12).map { CoreUsage(index: $0, usage: 0.1, level: .efficiency) }

    for step in 0..<CPUCardModel.graphCapacity {
        state.apply(
            cpu: CPUSnapshot(
                total: 0.45 + 0.35 * sin(Double(step) / 9),
                user: 0.306,
                system: 0.096,
                performanceAverage: 0.706,
                efficiencyAverage: 0.098,
                cores: cores
            )
        )
        state.apply(
            memory: MemorySnapshot(
                total: 8_589_934_592,
                app: 1_460_961_280,
                wired: 1_986_560_000,
                compressed: 1_954_283_520,
                cached: 901_120_000,
                free: 1_762_721_792,
                used: 5_926_092_800
            )
        )
    }

    for step in 0..<NetworkCardModel.graphCapacity {
        state.apply(
            network: NetworkSnapshot(
                totalIn: 3_850_000_000,
                totalOut: 2_760_000_000,
                downloadBytesPerSecond: 5_000 + 3_000 * sin(Double(step) / 9),
                uploadBytesPerSecond: 78_000 + 20_000 * cos(Double(step) / 11)
            )
        )
    }

    state.apply(
        disk: DiskSnapshot(
            total: 494_354_000_000,
            free: 62_286_000_000,
            readBytesPerSecond: 27_100_000,
            writeBytesPerSecond: 2_200_000
        )
    )

    return PanelView()
        .environment(state)
}

/// NC-12 as it looks on a 14" display: the four cards are pinned to
/// 945 − 24 = 921 pt and scroll to reach the Network card.
#Preview("Panel — capped to a 14\" visible frame") {
    let state = MetricsState()

    state.apply(
        cpu: CPUSnapshot(
            total: 0.42,
            user: 0.315,
            system: 0.105,
            performanceAverage: 0.7,
            efficiencyAverage: 0.1,
            cores: (0..<8).map { CoreUsage(index: $0, usage: 0.7, level: .performance) }
                + (8..<12).map { CoreUsage(index: $0, usage: 0.1, level: .efficiency) }
        )
    )
    state.apply(
        memory: MemorySnapshot(
            total: 8_589_934_592,
            app: 1_460_961_280,
            wired: 1_986_560_000,
            compressed: 1_954_283_520,
            cached: 901_120_000,
            free: 1_762_721_792,
            used: 5_926_092_800
        )
    )
    state.apply(
        disk: DiskSnapshot(
            total: 494_354_000_000,
            free: 62_286_000_000,
            readBytesPerSecond: 27_100_000,
            writeBytesPerSecond: 2_200_000
        )
    )
    state.apply(
        network: NetworkSnapshot(
            totalIn: 3_850_000_000,
            totalOut: 2_760_000_000,
            downloadBytesPerSecond: 5_000,
            uploadBytesPerSecond: 78_000
        )
    )

    return PanelRootView(
        state: state,
        maxHeight: PanelLayout.maxHeight(fitting: 1049, visibleFrameHeight: 945)
    )
}
