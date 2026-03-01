import GRDB
import ECSharedModels

extension WalletPass: @retroactive FetchableRecord {
    public static let databaseTableName = collectionName

    public enum Columns {
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

extension WalletPass.CodingKeys: @retroactive ColumnExpression {}

