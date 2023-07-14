import GRDB
import ECardifySharedModels

extension WalletPass: FetchableRecord {
    public static let databaseTableName = collectionName

    enum Columns {
        static let _id = Column(CodingKeys._id)
        static let ownerId = Column(CodingKeys.ownerId)
        static let pass = Column(CodingKeys.pass)
        static let imageURLs = Column(CodingKeys.imageURLs)
        static let isPaid = Column(CodingKeys.isPaid)
        static let isDataSavedOnServer = Column(CodingKeys.isDataSavedOnServer)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

extension WalletPass.CodingKeys: ColumnExpression {}

