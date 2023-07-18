import GRDB
import ECardifySharedModels

extension WalletPass: FetchableRecord {
    public static let databaseTableName = collectionName

    enum Columns {
        static let _id = Column(CodingKeys._id)
        static let ownerId = Column(CodingKeys.ownerId)
        static let vCard = Column(CodingKeys.vCard)
        static let colorPalette = Column(CodingKeys.colorPalette)
        static let isPaid = Column(CodingKeys.isPaid)
        static let isDataSavedOnServer = Column(CodingKeys.isDataSavedOnServer)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

extension WalletPass.CodingKeys: ColumnExpression {}

