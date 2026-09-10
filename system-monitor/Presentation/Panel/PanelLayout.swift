import CoreGraphics

/// How tall the detail panel is allowed to be on the screen presenting it
/// (NC-12).
///
/// A pure rule over two numbers: `CoreGraphics` alone, no AppKit, no `NSScreen`
/// and no view. `StatusItemController` owns the two facts this cannot know —
/// which display the status button sits on and how tall the panel measures —
/// and `PanelView` owns what a cap does to the tree. That split is what lets
/// the decision be asserted without a screen, a window or a popover.
nonisolated enum PanelLayout {

    /// Gap kept between the panel and the edges of the screen's visible frame.
    ///
    /// 24 pt covers the popover arrow above the panel and leaves a breathing
    /// gap above the Dock, so a capped panel never sits flush against either.
    static let screenMargin: CGFloat = 24

    /// The height a panel taller than the screen must be pinned to, or `nil`
    /// when it fits.
    ///
    /// `nil` is the load-bearing answer: it tells `PanelView` to keep the tree
    /// it has always had rather than to build a scroll view that happens not to
    /// scroll, which is what keeps every existing panel-height assertion (DC-11)
    /// measuring the same thing.
    ///
    /// A visible frame at or below the margin would leave a non-positive cap.
    /// Pinning the panel to it would clip every card, which NC-12 forbids, so
    /// the rule declines to cap at all.
    static func maxHeight(
        fitting: CGFloat,
        visibleFrameHeight: CGFloat,
        margin: CGFloat = screenMargin
    ) -> CGFloat? {
        let cap = visibleFrameHeight - margin
        guard cap > 0, fitting > cap else { return nil }
        return cap
    }

    /// NC-12's named rule: the height the panel is presented at.
    ///
    /// "Shorter than the visible frame" and "exactly at the cap" both return the
    /// fitting height unchanged, because both are the `nil` branch above.
    static func height(
        fitting: CGFloat,
        visibleFrameHeight: CGFloat,
        margin: CGFloat = screenMargin
    ) -> CGFloat {
        maxHeight(fitting: fitting, visibleFrameHeight: visibleFrameHeight, margin: margin)
            ?? fitting
    }
}
