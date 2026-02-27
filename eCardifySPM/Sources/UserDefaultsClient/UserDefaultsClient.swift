import Dependencies
import Foundation
import IssueReporting

// MARK: - UserDefaultKey

public enum UserDefaultKey: String, CaseIterable {
    case isAuthorized
    case isUserFirstNameEmpty
    case isAskPermissionCompleted
}

// MARK: - UserDefaultsClient

public struct UserDefaultsClient {
    public var boolForKey: @Sendable (String) -> Bool
    public var dataForKey: @Sendable (String) -> Data?
    public var doubleForKey: @Sendable (String) -> Double
    public var integerForKey: @Sendable (String) -> Int
    public var stringForKey: @Sendable (String) -> String
    public var remove: @Sendable (String) async -> Void
    public var setBool: @Sendable (Bool, String) async -> Void
    public var setData: @Sendable (Data?, String) async -> Void
    public var setDouble: @Sendable (Double, String) async -> Void
    public var setInteger: @Sendable (Int, String) async -> Void
    public var setString: @Sendable (String, String) async -> Void
}

// MARK: - DependencyValues

extension DependencyValues {
    public var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}

// MARK: - Live

extension UserDefaultsClient: DependencyKey {
    public static let liveValue: Self = {
        let defaults = { UserDefaults.standard }
        return Self(
            boolForKey: { defaults().bool(forKey: $0) },
            dataForKey: { defaults().data(forKey: $0) },
            doubleForKey: { defaults().double(forKey: $0) },
            integerForKey: { defaults().integer(forKey: $0) },
            stringForKey: { defaults().string(forKey: $0) ?? "" },
            remove: { defaults().removeObject(forKey: $0) },
            setBool: { defaults().set($0, forKey: $1) },
            setData: { defaults().set($0, forKey: $1) },
            setDouble: { defaults().set($0, forKey: $1) },
            setInteger: { defaults().set($0, forKey: $1) },
            setString: { defaults().set($0, forKey: $1) }
        )
    }()
}

// MARK: - Test

extension UserDefaultsClient: TestDependencyKey {
    public static let previewValue = Self.noop

    public static let testValue = Self(
        boolForKey: XCTUnimplemented("\(Self.self).boolForKey", placeholder: false),
        dataForKey: XCTUnimplemented("\(Self.self).dataForKey", placeholder: nil),
        doubleForKey: XCTUnimplemented("\(Self.self).doubleForKey", placeholder: 0),
        integerForKey: XCTUnimplemented("\(Self.self).integerForKey", placeholder: 0),
        stringForKey: XCTUnimplemented("\(Self.self).stringForKey", placeholder: ""),
        remove: XCTUnimplemented("\(Self.self).remove"),
        setBool: XCTUnimplemented("\(Self.self).setBool"),
        setData: XCTUnimplemented("\(Self.self).setData"),
        setDouble: XCTUnimplemented("\(Self.self).setDouble"),
        setInteger: XCTUnimplemented("\(Self.self).setInteger"),
        setString: XCTUnimplemented("\(Self.self).setString")
    )
}

extension UserDefaultsClient {
    public static let noop = Self(
        boolForKey: { _ in false },
        dataForKey: { _ in nil },
        doubleForKey: { _ in 0 },
        integerForKey: { _ in 0 },
        stringForKey: { _ in "" },
        remove: { _ in },
        setBool: { _, _ in },
        setData: { _, _ in },
        setDouble: { _, _ in },
        setInteger: { _, _ in },
        setString: { _, _ in }
    )

    public mutating func override(bool: Bool, forKey key: String) {
        self.boolForKey = { [self] in $0 == key ? bool : self.boolForKey($0) }
    }

    public mutating func override(data: Data, forKey key: String) {
        self.dataForKey = { [self] in $0 == key ? data : self.dataForKey($0) }
    }

    public mutating func override(double: Double, forKey key: String) {
        self.doubleForKey = { [self] in $0 == key ? double : self.doubleForKey($0) }
    }

    public mutating func override(integer: Int, forKey key: String) {
        self.integerForKey = { [self] in $0 == key ? integer : self.integerForKey($0) }
    }
}
