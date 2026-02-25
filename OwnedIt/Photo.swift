import Foundation
import SwiftData

@Model
final class Photo {
    @Attribute(.externalStorage)
    var imageData: Data?
    var item: Item?

    init(imageData: Data) {
        self.imageData = imageData
    }
}
