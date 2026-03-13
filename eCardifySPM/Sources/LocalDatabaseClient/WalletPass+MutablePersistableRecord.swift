import GRDB
import ECSharedModels

extension WalletPass: @retroactive MutablePersistableRecord {
    // WalletPass uses text-based ObjectId primary keys (not auto-incremented),
    // so didInsert does not need to update the id.
}


