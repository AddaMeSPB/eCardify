import BSON
import GRDB
import ECSharedModels

extension WalletPass : MutablePersistableRecord {
    /// The values persisted in the database
    // Update auto-incremented id upon successful insertion
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowIDColumn ?? ObjectId().hexString
    }
}


