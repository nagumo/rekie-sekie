import SwiftUI

/// スニペット・フォルダの追加/編集/削除を行う管理ウィンドウ。
struct SnippetManagementView: View {
    @ObservedObject var snippetManager: SnippetManager
    @ObservedObject private var localization = LocalizationManager.shared
    var onClose: () -> Void

    @State private var selectedFolderID: Int64?
    @State private var newFolderName = ""
    @State private var editingSnippetID: Int64?
    @State private var editTitle = ""
    @State private var editContent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            HStack(spacing: 0) {
                folderList
                Divider()
                snippetList
            }
            .frame(height: 260)

            Divider()
            editorPane
        }
        .frame(width: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)

            Text("スニペット管理", bundle: localization.bundle)
                .font(.headline)

            Spacer()
        }
        .padding(16)
    }

    private var folderList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { selectedFolderID = nil }) {
                Text("すべて", bundle: localization.bundle)
                    .fontWeight(selectedFolderID == nil ? .bold : .regular)
            }
            .buttonStyle(.plain)

            ForEach(snippetManager.folders) { folder in
                HStack {
                    Button(action: { selectedFolderID = folder.id }) {
                        Text(folder.name)
                            .fontWeight(selectedFolderID == folder.id ? .bold : .regular)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: { deleteFolder(folder) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("新規フォルダ", bundle: localization.bundle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                    Button(action: addFolder) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 160)
    }

    private var snippetList: some View {
        VStack(alignment: .leading, spacing: 8) {
            List(snippetManager.snippets(in: selectedFolderID)) { snippet in
                HStack {
                    Button(action: { selectSnippetForEditing(snippet) }) {
                        Text(snippet.title)
                            .fontWeight(editingSnippetID == snippet.id ? .bold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Button(action: { deleteSnippet(snippet) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)

            Button(action: addNewSnippet) {
                Text("新規スニペット", bundle: localization.bundle)
            }
        }
        .padding(12)
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タイトル", bundle: localization.bundle)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $editTitle)
                .textFieldStyle(.roundedBorder)
                .disabled(editingSnippetID == nil)

            Text("本文", bundle: localization.bundle)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $editContent)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .frame(height: 80)
                .border(Color.secondary.opacity(0.3))
                .disabled(editingSnippetID == nil)

            HStack {
                Text("{date} {time} {datetime} が使えます", bundle: localization.bundle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: saveEdit) {
                    Text("保存", bundle: localization.bundle)
                }
                .disabled(editingSnippetID == nil)
            }
        }
        .padding(16)
    }

    private func addFolder() {
        guard !newFolderName.isEmpty else { return }
        snippetManager.addFolder(name: newFolderName)
        newFolderName = ""
    }

    private func deleteFolder(_ folder: SnippetFolder) {
        if selectedFolderID == folder.id {
            selectedFolderID = nil
        }
        snippetManager.deleteFolder(folder)
    }

    private func addNewSnippet() {
        let untitled = String(localized: "無題", bundle: localization.bundle)
        guard let created = snippetManager.addSnippet(title: untitled, content: "", folderID: selectedFolderID) else {
            return
        }
        selectSnippetForEditing(created)
    }

    private func deleteSnippet(_ snippet: Snippet) {
        if editingSnippetID == snippet.id {
            editingSnippetID = nil
            editTitle = ""
            editContent = ""
        }
        snippetManager.deleteSnippet(snippet)
    }

    private func selectSnippetForEditing(_ snippet: Snippet) {
        editingSnippetID = snippet.id
        editTitle = snippet.title
        editContent = snippet.content
    }

    private func saveEdit() {
        guard let editingSnippetID,
              let snippet = snippetManager.snippets.first(where: { $0.id == editingSnippetID }) else { return }

        var updated = snippet
        updated.title = editTitle
        updated.content = editContent
        snippetManager.updateSnippet(updated)
    }
}
