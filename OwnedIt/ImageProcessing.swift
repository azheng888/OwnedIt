import UIKit

enum ImageProcessing {
    /// Longest edge for stored photos. Full camera images (~12–48 MP) bloat the store and iCloud.
    static let maxPhotoDimension: CGFloat = 2048
    static let thumbnailDimension: CGFloat = 240

    /// Downscales (if needed) and JPEG-encodes an image for storage.
    static func preparedPhotoData(from image: UIImage) -> Data? {
        resized(image, maxDimension: maxPhotoDimension).jpegData(compressionQuality: 0.8)
    }

    static func preparedPhotoData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return preparedPhotoData(from: image)
    }

    static func thumbnailData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return resized(image, maxDimension: thumbnailDimension).jpegData(compressionQuality: 0.7)
    }

    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image.normalizedOrientation() }
        let scale = maxDimension / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

private extension UIImage {
    /// Bakes EXIF orientation into the pixels so every consumer (PDF, thumbnails) renders upright.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
