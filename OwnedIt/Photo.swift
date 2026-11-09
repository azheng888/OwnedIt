import Foundation
import SwiftData

@Model
final class Photo {
    @Attribute(.externalStorage)
    var imageData: Data?
    /// Small JPEG used by list rows so they don't have to load full-size images.
    @Attribute(.externalStorage)
    var thumbnailData: Data?
    /// SwiftData/CloudKit to-many relationships are unordered, so order is stored explicitly.
    var sortIndex: Int = 0
    var item: Item?

    init(imageData: Data, sortIndex: Int = 0) {
        self.imageData = imageData
        self.thumbnailData = ImageProcessing.thumbnailData(from: imageData)
        self.sortIndex = sortIndex
    }
}
