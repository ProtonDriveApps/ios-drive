// Copyright (c) 2023 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Foundation
import SQLite3

/// Writes logs to a SQLite DB.
public actor SQLiteLogger: StructuredLogger {

    private let databaseFilename = "ProtonDrive.sqlite"
    private let tableName = "Logs"
    private let runId = Date().ISO8601Format().prefix(10) + "-" + UUID().uuidString
    private let system: LogSystem

    private var db: OpaquePointer?

    public init(system: LogSystem) {
        self.system = system
        Task {
            await openDatabase()
            await createTableIfNecessary()
        }
    }

    deinit {
        // TODO: Close the database (requires Swift 6.1)
        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0371-isolated-synchronous-deinit.md
        // closeDatabase()
    }

    nonisolated public func log(_ logEntry: StructuredLogEntry) {
        Task {
            await logToDB(
                level: logEntry.level.rawValue,
                message: logEntry.message,
                timestamp: logEntry.timestamp,
                threadNumber: logEntry.threadNumber,
                system: logEntry.system.suffix,
                domain: logEntry.domain.name
            )
        }
    }

    // MARK: - Database Operations

    private func openDatabase() {
        guard let dbFileUrl = self.dbFileURL else {
            Log.error("Missing db file url", error: nil, domain: .logs)
            return
        }

        if sqlite3_open(dbFileUrl.path, &db) != SQLITE_OK {
            Log.error("Could not open database", error: nil, domain: .logs)
        }
    }

    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            Log.error("Could not close database", error: nil, domain: .logs)
        }
        db = nil
    }

    private func createTableIfNecessary() {
        let createTableStatement = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          RunId TEXT NOT NULL,
          LogLevel TEXT NOT NULL,
          Message TEXT NOT NULL,
          Timestamp TEXT NOT NULL,
          ThreadNumber TEXT NOT NULL,
          System TEXT NOT NULL,
          Domain TEXT NOT NULL
        );
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableStatement, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                Log.error("Could not execute CREATE statement", error: nil, domain: .logs)
            }
        } else {
            Log.error("Could not prepare CREATE statement", error: nil, domain: .logs)
        }
        sqlite3_finalize(statement)
    }

    // swiftlint:disable:next function_parameter_count
    private func logToDB(
        level: String,
        message: String,
        timestamp: String,
        threadNumber: String,
        system: String,
        domain: String
    ) {
        let insertStatement = """
        INSERT INTO \(tableName) (RunId, LogLevel, Message, Timestamp, ThreadNumber, System, Domain) VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertStatement, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, self.runId, -1, nil)
            sqlite3_bind_text(statement, 2, level, -1, nil)
            sqlite3_bind_text(statement, 3, message, -1, nil)
            sqlite3_bind_text(statement, 4, timestamp, -1, nil)
            sqlite3_bind_text(statement, 5, threadNumber, -1, nil)
            sqlite3_bind_text(statement, 6, system, -1, nil)
            sqlite3_bind_text(statement, 7, domain, -1, nil)

            let result = sqlite3_step(statement)
            if result != SQLITE_DONE {
                Log.error("Could not execute insert statement", domain: .logs, context: LogContext(String(cString: sqlite3_errmsg(db))))
            }
        } else {
            Log.error("Could not prepare statement", domain: .logs, context: LogContext(String(cString: sqlite3_errmsg(db))))
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Private

    private var dbFileURL: URL? {
        return PDFileManager.logsDirectory.appendingPathComponent(databaseFilename)
    }
}
