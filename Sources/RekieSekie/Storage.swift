import Foundation
import GRDB

final class Storage {
    private let dbQueue: DatabaseQueue

    init(path: String? = nil) throws {
        if let path {
            dbQueue = try DatabaseQueue(path: path)
        } else {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent("rekie-sekie", isDirectory: true)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            let dbURL = dir.appendingPathComponent("history.sqlite")
            dbQueue = try DatabaseQueue(path: dbURL.path)
        }
        try migrator.migrate(dbQueue)
        try deduplicateKeepingNewest()
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createClipItem") { db in
            try db.create(table: "clipItem") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }
        migrator.registerMigration("addImageData") { db in
            try db.alter(table: "clipItem") { t in
                t.add(column: "imageData", .blob)
            }
        }
        migrator.registerMigration("createSnippetTables") { db in
            try db.create(table: "snippetFolder") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }
            try db.create(table: "snippet") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("folderID", .integer).indexed().references("snippetFolder", onDelete: .setNull)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }
        }
        return migrator
    }

    func insert(_ item: inout ClipItem) throws {
        try dbQueue.write { db in
            try item.insert(db)
        }
    }

    func touch(_ item: inout ClipItem) throws {
        try dbQueue.write { db in
            try item.update(db)
        }
    }

    func fetchRecent(limit: Int) throws -> [ClipItem] {
        try dbQueue.read { db in
            try ClipItem
                .order(Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Snippet

    func fetchSnippets() throws -> [Snippet] {
        try dbQueue.read { db in
            try Snippet.order(Column("sortOrder")).fetchAll(db)
        }
    }

    func fetchSnippetFolders() throws -> [SnippetFolder] {
        try dbQueue.read { db in
            try SnippetFolder.order(Column("sortOrder")).fetchAll(db)
        }
    }

    func insert(_ snippet: inout Snippet) throws {
        try dbQueue.write { db in
            try snippet.insert(db)
        }
    }

    func update(_ snippet: inout Snippet) throws {
        try dbQueue.write { db in
            try snippet.update(db)
        }
    }

    func delete(_ snippet: Snippet) throws {
        _ = try dbQueue.write { db in
            try snippet.delete(db)
        }
    }

    func insert(_ folder: inout SnippetFolder) throws {
        try dbQueue.write { db in
            try folder.insert(db)
        }
    }

    func delete(_ folder: SnippetFolder) throws {
        _ = try dbQueue.write { db in
            try folder.delete(db)
        }
    }

    /// 同一content・imageDataの重複行のうち、最新(createdAt降順)の1件だけを残して削除する。
    /// 画像はcontentが常に空文字のため、imageDataも含めてパーティションしないと別画像同士が誤って統合される。
    private func deduplicateKeepingNewest() throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                DELETE FROM clipItem
                WHERE id NOT IN (
                    SELECT id FROM (
                        SELECT id,
                               ROW_NUMBER() OVER (
                                   PARTITION BY content, imageData
                                   ORDER BY createdAt DESC, id DESC
                               ) AS rn
                        FROM clipItem
                    )
                    WHERE rn = 1
                )
                """)
        }
    }
}
