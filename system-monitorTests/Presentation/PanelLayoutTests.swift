import SwiftUI
import Testing
@testable import system_monitor

// network-card NC-12 — "Visible-frame scroll cap".
//
// The rule is pure and screenless: it takes two numbers and answers with a
// number. Everything AppKit knows — which display the status button sits on,
// how tall its `visibleFrame` is — stays in `StatusItemController`, so the
// decision itself is asserted here without a screen, a popover or a window.
@Suite("Panel layout visible-frame cap")
struct PanelLayoutTests {

    // network-card — "Taller than the visible frame"
    //
    // A four-card panel (1 049 pt measured, 1 050 pt in the spec's round
    // figure) against a 14" display's ≈945 pt visible frame: the panel is
    // pinned to 945 − 24 = 921 pt and its cards scroll.
    @Test func aPanelTallerThanTheVisibleFrameIsPinnedBelowIt() {
        #expect(PanelLayout.maxHeight(fitting: 1050, visibleFrameHeight: 945) == 921)
        #expect(PanelLayout.height(fitting: 1050, visibleFrameHeight: 945) == 921)
    }

    // network-card — "Shorter than the visible frame"
    //
    // The three-card panel on a 16" display. `maxHeight` answers `nil`, which
    // is what keeps `PanelView`'s tree byte-identical to today: no scroll view
    // is built at all, rather than one that happens not to scroll.
    @Test func aPanelShorterThanTheVisibleFrameKeepsItsFittingHeight() {
        #expect(PanelLayout.maxHeight(fitting: 871, visibleFrameHeight: 1132) == nil)
        #expect(PanelLayout.height(fitting: 871, visibleFrameHeight: 1132) == 871)
    }

    // network-card — "Exactly at the cap"
    //
    // The boundary belongs to the uncapped side: a panel that fits exactly is
    // not scrolled.
    @Test func aPanelExactlyAtTheCapIsNotCapped() {
        #expect(PanelLayout.maxHeight(fitting: 921, visibleFrameHeight: 945) == nil)
        #expect(PanelLayout.height(fitting: 921, visibleFrameHeight: 945) == 921)
    }

    // network-card — NC-12 "Content MUST NOT be clipped".
    //
    // A visible frame smaller than the margin would leave a non-positive cap.
    // Pinning the panel to −4 pt would clip every card, so the rule declines to
    // cap and the panel keeps its fitting height.
    @Test func aNonPositiveCapIsNotApplied() {
        #expect(PanelLayout.maxHeight(fitting: 1050, visibleFrameHeight: 20) == nil)
        #expect(PanelLayout.maxHeight(fitting: 1050, visibleFrameHeight: 24) == nil)
        #expect(PanelLayout.height(fitting: 1050, visibleFrameHeight: 20) == 1050)
    }

    // network-card — NC-12 "minus a design-owned margin": the margin is a
    // parameter with a default, so the same rule can be asserted against a
    // different gap without restating the production constant.
    @Test func aCustomMarginIsHonoured() {
        #expect(PanelLayout.screenMargin == 24)
        #expect(PanelLayout.maxHeight(fitting: 1050, visibleFrameHeight: 945, margin: 0) == 945)
        #expect(PanelLayout.maxHeight(fitting: 1050, visibleFrameHeight: 945, margin: 100) == 845)
        #expect(PanelLayout.height(fitting: 1050, visibleFrameHeight: 945, margin: 100) == 845)
        // 945 − 200 = 745 is still below the 1 050 pt panel, so it still caps;
        // 945 − 900 = 45 caps far harder. The margin moves the answer, it does
        // not switch the branch.
        #expect(PanelLayout.maxHeight(fitting: 1050, visibleFrameHeight: 945, margin: 900) == 45)
    }

    // network-card — the margin also moves the branch when the panel is close
    // to the frame: 900 pt fits under a 24 pt margin on a 945 pt frame, and
    // does not fit under a 100 pt one.
    @Test func theMarginDecidesWhetherAPanelNearTheFrameIsCapped() {
        #expect(PanelLayout.maxHeight(fitting: 900, visibleFrameHeight: 945) == nil)
        #expect(PanelLayout.maxHeight(fitting: 900, visibleFrameHeight: 945, margin: 100) == 845)
    }
}
