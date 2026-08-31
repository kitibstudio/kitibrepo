import Foundation
import SQLite3

// MARK: - SearchHit

/// One hit from a full-text search.
struct SearchHit: Equatable {
    let id: String
    let title: String?
    let snippet: String
}

// MARK: - SearchIndex

/// In-memory FTS5 full-text search index.
///
/// Indexes documents by `(id, title?, content)`. Search returns ranked results
/// with highlighted snippets. Boolean AND (default), OR, NOT, and quoted-phrase
/// syntax are supported via FTS5's native query language.
///
/// Uses SQLite3 directly — no wrapper library, no new dependency.
final class SearchIndex {

    /// SQLITE_TRANSIENT is a C macro, not a constant, so Swift does not import
    /// it.  The value tells SQLite to copy the string immediately.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private var db: OpaquePointer?

    // MARK: - Lifecycle

    init() throws {
        var handle: OpaquePointer?
        let rc = sqlite3_open(":memory:", &handle)
        guard rc == SQLITE_OK, let db = handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw Error.openFailed(msg)
        }
        self.db = db
        try createSchema()
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    // MARK: - Indexing

    /// Adds or replaces a document in the index. Providing the same `id` a
    /// second time replaces the previous content atomically.
    func index(id: String, title: String?, content: String) throws {
        guard let db = db else { throw Error.closed }

        // Remove any existing row for this id, then insert.
        try execute(db, "DELETE FROM docs WHERE doc_id = ?", bind: { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, Self.transient)
        })

        try execute(db,
            "INSERT INTO docs (doc_id, title, content) VALUES (?, ?, ?)",
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, id, -1, Self.transient)
                if let t = title {
                    sqlite3_bind_text(stmt, 2, t, -1, Self.transient)
                } else {
                    sqlite3_bind_null(stmt, 2)
                }
                sqlite3_bind_text(stmt, 3, content, -1, Self.transient)
            })
    }

    /// Removes a document from the index. No-op if the id is not present.
    func remove(id: String) throws {
        guard let db = db else { throw Error.closed }
        try execute(db, "DELETE FROM docs WHERE doc_id = ?", bind: { stmt in
            sqlite3_bind_text(stmt, 1, id, -1, Self.transient)
        })
    }

    // MARK: - Search

    /// Full-text search. Returns results ranked by relevance, each with a
    /// highlighted snippet from the document content.
    ///
    /// Query syntax (FTS5 native):
    /// - `cable schedule` — implicit AND
    /// - `cable OR schedule` — OR
    /// - `cable NOT schedule` — exclude
    /// - `"voltage drop"` — exact phrase
    func search(_ query: String) throws -> [SearchHit] {
        guard let db = db else { throw Error.closed }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var results: [SearchHit] = []

        let sql = """
            SELECT doc_id, title, snippet(docs, 2, '<b>', '</b>', '...', 40)
            FROM docs
            WHERE docs MATCH ?
            ORDER BY rank
            LIMIT 50
            """

        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            throw Error.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(s) }

        let queryC = trimmed as NSString
        sqlite3_bind_text(s, 1, queryC.utf8String, -1, Self.transient)

        while sqlite3_step(s) == SQLITE_ROW {
            let docID = String(cString: sqlite3_column_text(s, 0))
            let title: String? = {
                guard let c = sqlite3_column_text(s, 1) else { return nil }
                return String(cString: c)
            }()
            let snippet = String(cString: sqlite3_column_text(s, 2))
            results.append(SearchHit(id: docID, title: title, snippet: snippet))
        }

        return results
    }

    // MARK: - Internals

    private func createSchema() throws {
        guard let db = db else { throw Error.closed }
        let sql = """
            CREATE VIRTUAL TABLE IF NOT EXISTS docs USING fts5(
                doc_id UNINDEXED,
                title,
                content,
                tokenize='unicode61'
            )
            """
        try execute(db, sql)
    }

    private func execute(
        _ db: OpaquePointer,
        _ sql: String,
        bind: ((OpaquePointer) -> Void)? = nil
    ) throws {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            throw Error.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(s) }

        bind?(s)

        let stepRC = sqlite3_step(s)
        guard stepRC == SQLITE_DONE || stepRC == SQLITE_OK else {
            throw Error.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Error

    enum Error: Swift.Error, Equatable {
        case openFailed(String)
        case closed
        case queryFailed(String)
    }
}
