import AppKit
import SwiftUI

/// SwiftUIのListは内部のNSScrollView/NSScrollerに直接アクセスできないため、
/// 背面に仕込んだ空ビューからビュー階層を遡ってNSScrollViewを探し、
/// スクローラーを半分の太さのサブクラスに差し替える。
final class ThinScroller: NSScroller {
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        super.scrollerWidth(for: controlSize, scrollerStyle: scrollerStyle) / 2
    }
}

struct ScrollerThinner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { applyThinScroller(startingFrom: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { applyThinScroller(startingFrom: nsView) }
    }

    private func applyThinScroller(startingFrom view: NSView) {
        var current = view.superview
        while let candidate = current {
            if let scrollView = candidate as? NSScrollView {
                if !(scrollView.verticalScroller is ThinScroller) {
                    let scroller = ThinScroller()
                    scroller.scrollerStyle = scrollView.verticalScroller?.scrollerStyle ?? .legacy
                    scrollView.verticalScroller = scroller
                }
                return
            }
            current = candidate.superview
        }
    }
}
