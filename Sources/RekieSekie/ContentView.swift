import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var selectionState: SelectionState
    @ObservedObject private var localization = LocalizationManager.shared
    @FocusState private var isSearchFocused: Bool
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
                }
                .listStyle(.plain)
                .background(ScrollerThinner())
            }
        }
        .frame(width: 320, height: 400, alignment: .topLeading)
        .onChange(of: isSearchFocused) { newValue in
            selectionState.isSearchFieldFocused = newValue
        }
    }
}
