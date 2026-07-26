import Foundation

final class SnippetManager: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published private(set) var folders: [SnippetFolder] = []

    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
        reload()
    }

    func reload() {
        snippets = (try? storage.fetchSnippets()) ?? []
        folders = (try? storage.fetchSnippetFolders()) ?? []
    }

    @discardableResult
    func addSnippet(title: String, content: String, folderID: Int64?) -> Snippet? {
        var snippet = Snippet(title: title, content: content, folderID: folderID, sortOrder: snippets.count)
        do {
            try storage.insert(&snippet)
        } catch {
            print("スニペットの保存に失敗しました: \(error)")
            return nil
        }
        reload()
        return snippet
    }

    func updateSnippet(_ snippet: Snippet) {
        var updated = snippet
        do {
            try storage.update(&updated)
        } catch {
            print("スニペットの更新に失敗しました: \(error)")
            return
        }
        reload()
    }

    func deleteSnippet(_ snippet: Snippet) {
        do {
            try storage.delete(snippet)
        } catch {
            print("スニペットの削除に失敗しました: \(error)")
            return
        }
        reload()
    }

    @discardableResult
    func addFolder(name: String) -> SnippetFolder? {
        var folder = SnippetFolder(name: name, sortOrder: folders.count)
        do {
            try storage.insert(&folder)
        } catch {
            print("フォルダの保存に失敗しました: \(error)")
            return nil
        }
        reload()
        return folder
    }

    func deleteFolder(_ folder: SnippetFolder) {
        do {
            try storage.delete(folder)
        } catch {
            print("フォルダの削除に失敗しました: \(error)")
            return
        }
        reload()
    }

    func snippets(in folderID: Int64?) -> [Snippet] {
        snippets.filter { $0.folderID == folderID }
    }

    /// SnippetsViewの表示順（フォルダなし→フォルダ順）に一致するフラットな並び。
    /// キーボード操作（矢印/数字キー）でSnippetsViewと同じインデックスを参照するために使う。
    var displayOrder: [Snippet] {
        var result = snippets(in: nil)
        for folder in folders {
            result += snippets(in: folder.id)
        }
        return result
    }

    func expandedContent(for snippet: Snippet) -> String {
        SnippetVariableExpander.expand(snippet.content)
    }
}
