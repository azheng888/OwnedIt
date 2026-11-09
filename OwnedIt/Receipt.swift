import Foundation
import SwiftData

@Model
final class Receipt {
    @Attribute(.externalStorage)
    var fileData: Data?
    var filename: String = ""
    var item: Item?

    init(fileData: Data, filename: String) {
        self.fileData = fileData
        self.filename = filename
    }

    var isPDF: Bool { Receipt.isPDF(fileData) }

    var displayName: String { filename.isEmpty ? "Document" : filename }

    static func isPDF(_ data: Data?) -> Bool {
        data?.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]) // "%PDF"
    }
}
