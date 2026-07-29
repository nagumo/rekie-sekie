import AppKit
import SwiftUI

/// スクロール中のフォーカス追従に使う共有状態。
/// onPreferenceChangeで取り込んだ行フレーム（List座標系）は、スクロール中は更新が
/// 連続的に来ないため、取り込み時点のスクロールオフセットを併せて記録し、
/// 以後はオフセット差分で現在の行位置を補正して使う。
final class ScrollFollowState {
    private var rowFrames: [Int: CGRect] = [:]
    private var capturedOffsetY: CGFloat = 0
    var lastOffsetY: CGFloat = 0
    /// スクロール追従による選択変更中はtrue。この間はonChange側のscrollToを抑止し、
    /// ユーザーのスクロールとscrollToが引っ張り合わないようにする。
    var scrollDrivenChange = false

    func updateFrames(_ frames: [Int: CGRect]) {
        rowFrames = frames
        capturedOffsetY = lastOffsetY
        if ProcessInfo.processInfo.environment["REKIE_DEBUG_SCROLL"] != nil {
            let sample = frames.sorted { $0.key < $1.key }.prefix(3)
                .map { "\($0.key):\(Int($0.value.minY))..\(Int($0.value.maxY))" }
                .joined(separator: " ")
            print("[frames] n=\(frames.count) capturedY=\(Int(capturedOffsetY)) \(sample)")
        }
    }

    /// 現在のスクロール位置に補正した行フレーム。描画されていない行はnil。
    func currentFrame(_ index: Int) -> CGRect? {
        guard let frame = rowFrames[index] else { return nil }
        return frame.offsetBy(dx: 0, dy: capturedOffsetY - lastOffsetY)
    }

    /// 現在のスクロール位置で、指定したY範囲に完全に収まっている行のインデックス集合。
    func indicesWithin(minY: CGFloat, maxY: CGFloat) -> [Int] {
        rowFrames.keys.filter { index in
            guard let frame = currentFrame(index) else { return false }
            return frame.minY >= minY && frame.maxY <= maxY
        }
    }

    /// 現在のスクロール位置で表示範囲内に完全に収まっている行のインデックス集合。
    func fullyVisibleIndices(listHeight: CGFloat) -> [Int] {
        indicesWithin(minY: -2, maxY: listHeight + 2)
    }
}

/// リスト内部のNSClipViewのboundsDidChangeを監視し、スクロールのたびに
/// 現在のオフセットYを通知する。SwiftUIのonPreferenceChangeはスクロール中に
/// 連続発火しないため、リアルタイムのフォーカス追従はこちらで駆動する。
struct ScrollObserver: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.onScroll = onScroll
        // makeNSView直後はまだビュー階層にNSScrollViewが繋がっていないことがあるため、
        // ThinScrollerと同様、SwiftUIの更新のたびに未接続なら張り直しを試みる
        DispatchQueue.main.async { nsView.attachIfNeeded() }
    }

    final class ObserverView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var observation: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }

        func attachIfNeeded() {
            if observation == nil { attach() }
        }

        private func attach() {
            let debug = ProcessInfo.processInfo.environment["REKIE_DEBUG_SCROLL"] != nil
            // ポップオーバー再表示などでスクロールビューが変わる場合に備え、毎回張り直す
            if let observation {
                NotificationCenter.default.removeObserver(observation)
                self.observation = nil
            }
            // 背面ビューの祖先にNSScrollViewはいない（ListはNSHostingView配下の別サブツリー）ため、
            // ウィンドウのcontentViewから下方向に探索する。このビューが属するウィンドウには
            // List由来のNSScrollViewが1つだけある前提。
            guard let root = window?.contentView, let scrollView = findScrollView(under: root) else {
                if debug { print("[attach] FAILED: no scroll view under window content view") }
                return
            }
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            observation = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self, weak clipView] _ in
                guard let clipView else { return }
                self?.onScroll?(clipView.bounds.origin.y)
            }
            if debug { print("[attach] ok: \(type(of: scrollView))") }
        }

        deinit {
            if let observation {
                NotificationCenter.default.removeObserver(observation)
            }
        }
    }
}

/// rootから下方向に幅優先で探索して最初のNSScrollViewを返す。
/// SwiftUIのList内部のNSScrollViewは、背面ビュー(NSViewRepresentable)の祖先方向には
/// 存在しない（NSHostingView配下の別サブツリーにいる）ため、ウィンドウのcontentViewを
/// 起点にこの関数で探す。
func findScrollView(under root: NSView) -> NSScrollView? {
    var queue: [NSView] = [root]
    while !queue.isEmpty {
        let view = queue.removeFirst()
        if let scrollView = view as? NSScrollView { return scrollView }
        queue.append(contentsOf: view.subviews)
    }
    return nil
}
