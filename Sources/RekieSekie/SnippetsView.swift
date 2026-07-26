import SwiftUI

/// スニペット一覧を表示し、クリックした項目を貼り付けるためのポップオーバー本体。
struct SnippetsView: View {
    @ObservedObject var snippetManager: SnippetManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject private var localization = LocalizationManager.shared
    var onSelect: (Snippet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if snippetManager.snippets.isEmpty {
                Text("スニペットがありません", bundle: localization.bundle)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(groups, id: \.folder?.id) { group in
                        Section {
                            ForEach(group.snippets) { snippet in
                                row(for: snippet)
                            }
                        } header: {
                            if let folder = group.folder {
                                Text(folder.name)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 320, height: 400, alignment: .topLeading)
    }

    private func row(for snippet: Snippet) -> some View {
        let index = flatIndex(of: snippet)
        return Button {
            onSelect(snippet)
        } label: {
            HStack(spacing: 6) {
                Text(index >= 0 && index < 9 ? "\(index + 1)" : " ")
                    .foregroundStyle(.secondary)
                    .frame(width: 14, alignment: .trailing)
                Text(snippet.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private struct Group {
        var folder: SnippetFolder?
        var snippets: [Snippet]
    }

    private var groups: [Group] {
        var result: [Group] = []
        let rootSnippets = snippetManager.snippets(in: nil)
        if !rootSnippets.isEmpty {
            result.append(Group(folder: nil, snippets: rootSnippets))
        }
        for folder in snippetManager.folders {
            let items = snippetManager.snippets(in: folder.id)
            if !items.isEmpty {
                result.append(Group(folder: folder, snippets: items))
            }
        }
        return result
    }

    private func flatIndex(of snippet: Snippet) -> Int {
        snippetManager.displayOrder.firstIndex(where: { $0.id == snippet.id }) ?? -1
    }
}
