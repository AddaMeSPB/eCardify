import Foundation
import GRDB
import ECardifySharedModels

/// AppDatabase lets the application access the database.
///
/// It applies the pratices recommended at
/// <https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md>
public struct AppDatabase {
    /// Creates an `AppDatabase`, and make sure the database schema is ready.
    public init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    /// Provides access to the database.
    ///
    /// Application can use a `DatabasePool`, while SwiftUI previews and tests
    /// can use a fast in-memory `DatabaseQueue`.
    ///
    /// See <https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections>
    private let dbWriter: any DatabaseWriter

    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("createWalletPass") { db in
            // Create a table
            // See https://github.com/groue/GRDB.swift#create-tables
            try db.create(table: "wallet_passes") { t in
                t.column("_id", .text).notNull().unique()
                t.primaryKey(["_id"])
                t.column("ownerId", .text)
                t.column("vCard", .text).notNull()
                t.column("colorPalette", .text).notNull()
                t.column("isPaid", .boolean).notNull().defaults(to: false)
                t.column("isDataSavedOnServer", .boolean).notNull().defaults(to: false)

                t.column("createdAt", .datetime)
                t.column("updatedAt", .datetime)
            }

        }

        return migrator
    }
}

extension AppDatabase {}

// MARK: - Database Access: Reads

// This demo app does not provide any specific reading method, and instead
// gives an unrestricted read-only access to the rest of the application.
// In your app, you are free to choose another path, and define focused
// reading methods.
extension AppDatabase {
    /// Provides a read-only access to the database
    var databaseReader: DatabaseReader {
        dbWriter
    }
}

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()

    private static func makeShared() -> AppDatabase {
        do {
            // Pick a folder for storing the SQLite database, as well as
            // the various temporary files created during normal database
            // operations (https://sqlite.org/tempfiles.html).
            let fileManager = FileManager()
            let folderURL = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("database", isDirectory: true)

            // Support for tests: delete the database if requested
            if CommandLine.arguments.contains("-reset") {
                try? fileManager.removeItem(at: folderURL)
            }

            // Create the database folder if needed
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // Connect to a database on disk
            // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)

            // Create the AppDatabase
            let appDatabase = try AppDatabase(dbPool)

            return appDatabase

        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            //
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            fatalError("Unresolved error \(error)")
        }
    }

    /// Creates an empty database for SwiftUI previews
    static func empty() -> AppDatabase {
        // Connect to an in-memory database
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
        let dbQueue = try! DatabaseQueue()
        return try! AppDatabase(dbQueue)
    }

    /// Creates a database full of random players for SwiftUI previews
    static func random() -> AppDatabase {
        let appDatabase = empty()

        return appDatabase
    }
}


protocol AppDatabaseClient {
    @Sendable func create(wp: WalletPass) async throws -> Void
    @Sendable func update(wp: WalletPass) async throws -> Void
    @Sendable func find() async throws -> [WalletPass]
    @Sendable func findBy(id: WalletPass.ID) async throws -> WalletPass?
    @Sendable func deleteBy(id: WalletPass.ID) async throws -> Void
    @Sendable func deleteAll() async throws -> Int
    @Sendable func findAllThenUpdareAll() async throws -> Void
}

// MARK: - Database Access: Writes
extension AppDatabase: AppDatabaseClient {

    public func create(wp: WalletPass) async throws {
        var walletPass = wp
        walletPass = try await dbWriter.write { [walletPass] db in
            try walletPass.saved(db)
        }
    }

    public func find() async throws -> [WalletPass] {
        try await dbWriter.write { db in
            try WalletPass.all().fetchAll(db)
        }
    }

    public func findBy(id: WalletPass.ID) async throws -> WalletPass? {
        try await dbWriter.write { db in
            try WalletPass.fetchOne(db, id: id)
        }
    }

    public func update(wp: WalletPass) async throws {
        try await dbWriter.write { db in
            if var wp = try WalletPass.fetchOne(db, id: wp.id) {
                wp = wp
                try wp.update(db)
            }
        }
    }

    public func deleteBy(id: WalletPass.ID) async throws {
        try await dbWriter.write { db in
            if let wp = try WalletPass.fetchOne(db, id: id) {
                try wp.delete(db)
            }
        }
    }

    public func deleteAll() async throws -> Int {
        try await dbWriter.write { db in
            try WalletPass.deleteAll(db)
        }
    }

    func findAllThenUpdareAll() async throws {

    }

}

