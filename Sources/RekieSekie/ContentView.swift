import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var selectionState: SelectionState
    @ObservedObject private var localization = LocalizationManager.shared
    @FocusState private var isSearchFocused: Bool
    @State private var follow = ScrollFollowState()
    var onSelect: (ClipItem) -> Void

    private var filteredItems: [ClipItem] {
        monitor.filteredItems(matching: selectionState.searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !monitor.items.isEmpty {
                TextField("", text: $selectionState.searchText, prompt: Text("検索", bundle: localization.bundle))
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .onChange(of: selectionState.searchText) { _ in
                        selectionState.selectedIndex = 0
                    }
            }

            if monitor.items.isEmpty {
                Text("履歴はまだありません", bundle: localization.bundle)
                    .foregroundStyle(.secondary)
            } else if filteredItems.isEmpty {
                Text("見つかりませんでした", bundle: localization.bundle)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            } else {
                GeometryReader { listGeo in
                    ScrollViewReader { proxy in
                        List(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            Button {
                                onSelect(item)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(index < 9 ? "\(index + 1)" : " ")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 14, alignment: .trailing)
                                    if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Text(item.content)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(
                                    index == selectionState.selectedIndex
                                        ? Color.accentColor.opacity(0.25)
                                        : Color.clear
                                )
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                            .background(GeometryReader { rowGeo in
                                Color.clear.preference(
                                    key: ListRowFramesKey.self,
                                    value: [index: rowGeo.frame(in: .global)]
                                )
                            })
                        }
                        .listStyle(.plain)
                        .background(ScrollerThinner())
                        .background(ScrollObserver { offsetY in
                            let delta = offsetY - follow.lastOffsetY
                            follow.lastOffsetY = offsetY
                            guard abs(delta) > 0.1 else { return }
                            followScroll(scrollingDown: delta > 0, listHeight: listGeo.size.height)
                        })
                        .onChange(of: selectionState.selectedIndex) { newIndex in
                            if follow.scrollDrivenChange {
                                follow.scrollDrivenChange = false
                                return
                            }
                            let items = filteredItems
                            guard items.indices.contains(newIndex) else { return }
                            guard !isRowFullyVisible(newIndex, listHeight: listGeo.size.height) else { return }
                            proxy.scrollTo(items[newIndex].id)
                        }
                        .onAppear {
                            let items = filteredItems
                            guard items.indices.contains(selectionState.selectedIndex) else { return }
                            proxy.scrollTo(items[selectionState.selectedIndex].id)
                        }
                        .onPreferenceChange(ListRowFramesKey.self) { frames in
                            // 行もListもglobal空間で測り、差分を取ってList基準(0..height)に揃える
                            let listMinY = listGeo.frame(in: .global).minY
                            follow.updateFrames(frames.mapValues { $0.offsetBy(dx: 0, dy: -listMinY) })
                            ensureSelectionVisible(listHeight: listGeo.size.height)
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: 400, alignment: .topLeading)
        .onChange(of: isSearchFocused) { newValue in
            selectionState.isSearchFieldFocused = newValue
        }
    }

    /// 行がリストの表示範囲内に完全に収まっているか（±2ptはセパレータ等の誤差許容）。
    private func isRowFullyVisible(_ index: Int, listHeight: CGFloat) -> Bool {
        guard let frame = follow.currentFrame(index) else { return false }
        return frame.minY >= -2 && frame.maxY <= listHeight + 2
    }

    /// 速いスクロール中は行フレーム情報が古く追従が取りこぼされることがあるため、
    /// レイアウト更新のたびに選択行が可視範囲外に置き去りになっていないか確認し、
    /// 外れていれば近い側の端の可視行へ戻す。
    private func ensureSelectionVisible(listHeight: CGFloat) {
        let selected = selectionState.selectedIndex
        guard !isRowFullyVisible(selected, listHeight: listHeight) else { return }
        let visible = follow.fullyVisibleIndices(listHeight: listHeight)
        guard let lower = visible.min(), let upper = visible.max() else { return }
        if selected < lower {
            follow.scrollDrivenChange = true
            selectionState.selectedIndex = lower
        } else if selected > upper {
            follow.scrollDrivenChange = true
            selectionState.selectedIndex = upper
        }
    }

    /// 下向きスクロール時に、上端よりどれだけ手前でフォーカスを下の行へ移し始めるか。
    private static let downwardLead: CGFloat = 12
    /// 上向きスクロール時に、下端よりどれだけ手前でフォーカスを上の行へ移し始めるか。
    private static let upwardLead: CGFloat = 12

    /// 手動スクロールに合わせてフォーカスを追従させる。
    /// 下向きスクロール中はフォーカス行が上端の手前（downwardLead）に達した時点で下の可視行へ、
    /// 上向きスクロール中は下端の手前（upwardLead）に達した時点で上の可視行へ押し出す。
    /// それ以外はフォーカスは行に留まる。
    private func followScroll(scrollingDown: Bool, listHeight: CGFloat) {
        let selected = selectionState.selectedIndex
        let selectedFrame = follow.currentFrame(selected)
        if ProcessInfo.processInfo.environment["REKIE_DEBUG_SCROLL"] != nil {
            let f = selectedFrame.map { "\(Int($0.minY))..\(Int($0.maxY))" } ?? "nil"
            print("[follow] down=\(scrollingDown) sel=\(selected) frame=\(f) h=\(Int(listHeight)) offY=\(Int(follow.lastOffsetY))")
        }
        if scrollingDown {
            let limit = Self.downwardLead
            guard selectedFrame == nil || selectedFrame!.minY < limit else { return }
            let candidates = follow.indicesWithin(minY: limit, maxY: listHeight + 2)
            if let lower = candidates.min(), lower > selected {
                follow.scrollDrivenChange = true
                selectionState.selectedIndex = lower
            }
        } else {
            let limit = listHeight - Self.upwardLead
            guard selectedFrame == nil || selectedFrame!.maxY > limit else { return }
            let candidates = follow.indicesWithin(minY: -2, maxY: limit)
            if let upper = candidates.max(), upper < selected {
                follow.scrollDrivenChange = true
                selectionState.selectedIndex = upper
            }
        }
    }
}
