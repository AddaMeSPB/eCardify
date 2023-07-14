import Foundation
import Dependencies
import GRDB

// MARK: - Player Database Requests

/// Define some player requests used by the application.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#requests>
/// See <https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md>
//extension DerivableRequest<WordGetObjectWithoutUser> {}

extension AppDatabase: DependencyKey {
//    public static var liveValue: LocalDatabaseClient = .liveV
    public static var liveValue: AppDatabase = AppDatabase.shared
}

extension DependencyValues {
    public var localDatabase: AppDatabase {
        get { self[AppDatabase.self] }
        set { self[AppDatabase.self] = newValue }
    }
}

