//
//  DatabaseManager.swift
//  MemoryMonitor
//
//  SQLite database manager for storing historical metrics
//

import Foundation
import SQLite3

class DatabaseManager {
    private var db: OpaquePointer?
    private let dbPath: String

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MemoryMonitor", isDirectory: true)

        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

        dbPath = appDir.appendingPathComponent("metrics.db").path
        openDatabase()
        createTable()
    }

    deinit {
        closeDatabase()
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func createTable() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS metrics (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            swap_total REAL,
            swap_used REAL,
            swap_free REAL,
            pages_free INTEGER,
            pages_active INTEGER,
            pages_wired INTEGER,
            pages_compressed INTEGER,
            pages_occupied_by_compressor INTEGER,
            swapins INTEGER,
            swapouts INTEGER,
            compressions INTEGER,
            decompressions INTEGER,
            windowserver_memory REAL,
            windowserver_percent REAL,
            load_avg_1m REAL,
            load_avg_5m REAL,
            load_avg_15m REAL
        );

        CREATE INDEX IF NOT EXISTS idx_timestamp ON metrics(timestamp DESC);
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error creating table")
            }
        }
        sqlite3_finalize(statement)
    }

    func saveMetrics(_ metrics: SystemMetrics) throws {
        let insertQuery = """
        INSERT INTO metrics (
            id, timestamp, swap_total, swap_used, swap_free,
            pages_free, pages_active, pages_wired, pages_compressed, pages_occupied_by_compressor,
            swapins, swapouts, compressions, decompressions,
            windowserver_memory, windowserver_percent,
            load_avg_1m, load_avg_5m, load_avg_15m
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareError
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, metrics.id.uuidString, -1, nil)
        sqlite3_bind_double(statement, 2, metrics.timestamp.timeIntervalSince1970)
        sqlite3_bind_double(statement, 3, metrics.swapTotal)
        sqlite3_bind_double(statement, 4, metrics.swapUsed)
        sqlite3_bind_double(statement, 5, metrics.swapFree)
        sqlite3_bind_int64(statement, 6, metrics.pagesFree)
        sqlite3_bind_int64(statement, 7, metrics.pagesActive)
        sqlite3_bind_int64(statement, 8, metrics.pagesWired)
        sqlite3_bind_int64(statement, 9, metrics.pagesCompressed)
        sqlite3_bind_int64(statement, 10, metrics.pagesOccupiedByCompressor)
        sqlite3_bind_int64(statement, 11, metrics.swapins)
        sqlite3_bind_int64(statement, 12, metrics.swapouts)
        sqlite3_bind_int64(statement, 13, metrics.compressions)
        sqlite3_bind_int64(statement, 14, metrics.decompressions)
        sqlite3_bind_double(statement, 15, metrics.windowServerMemory)
        sqlite3_bind_double(statement, 16, metrics.windowServerPercent)
        sqlite3_bind_double(statement, 17, metrics.loadAverage1m)
        sqlite3_bind_double(statement, 18, metrics.loadAverage5m)
        sqlite3_bind_double(statement, 19, metrics.loadAverage15m)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.insertError
        }

        // Clean up old data (keep last 7 days)
        try cleanOldData()
    }

    func loadRecentMetrics(limit: Int) throws -> [SystemMetrics] {
        let query = """
        SELECT * FROM metrics
        ORDER BY timestamp DESC
        LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareError
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var metrics: [SystemMetrics] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) ?? UUID()
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
            let swapTotal = sqlite3_column_double(statement, 2)
            let swapUsed = sqlite3_column_double(statement, 3)
            let swapFree = sqlite3_column_double(statement, 4)
            let pagesFree = sqlite3_column_int64(statement, 5)
            let pagesActive = sqlite3_column_int64(statement, 6)
            let pagesWired = sqlite3_column_int64(statement, 7)
            let pagesCompressed = sqlite3_column_int64(statement, 8)
            let pagesOccupiedByCompressor = sqlite3_column_int64(statement, 9)
            let swapins = sqlite3_column_int64(statement, 10)
            let swapouts = sqlite3_column_int64(statement, 11)
            let compressions = sqlite3_column_int64(statement, 12)
            let decompressions = sqlite3_column_int64(statement, 13)
            let windowServerMemory = sqlite3_column_double(statement, 14)
            let windowServerPercent = sqlite3_column_double(statement, 15)
            let loadAverage1m = sqlite3_column_double(statement, 16)
            let loadAverage5m = sqlite3_column_double(statement, 17)
            let loadAverage15m = sqlite3_column_double(statement, 18)

            let metric = SystemMetrics(
                id: id,
                timestamp: timestamp,
                swapTotal: swapTotal,
                swapUsed: swapUsed,
                swapFree: swapFree,
                pagesFree: pagesFree,
                pagesActive: pagesActive,
                pagesWired: pagesWired,
                pagesCompressed: pagesCompressed,
                pagesOccupiedByCompressor: pagesOccupiedByCompressor,
                swapins: swapins,
                swapouts: swapouts,
                compressions: compressions,
                decompressions: decompressions,
                windowServerMemory: windowServerMemory,
                windowServerPercent: windowServerPercent,
                loadAverage1m: loadAverage1m,
                loadAverage5m: loadAverage5m,
                loadAverage15m: loadAverage15m
            )

            metrics.append(metric)
        }

        return metrics.reversed()  // Return chronological order
    }

    private func cleanOldData() throws {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let deleteQuery = "DELETE FROM metrics WHERE timestamp < ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareError
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, sevenDaysAgo.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.deleteError
        }
    }

    enum DatabaseError: Error {
        case prepareError
        case insertError
        case deleteError
    }
}
