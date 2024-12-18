import UIKit
import VectorExtor

extension UIImage {
	enum ScalingMode {
		case pixels
		case points
	}

	func imageByScaling(scaleFactor: Double) async -> UIImage? {
		let newSize = size * scaleFactor
		return await imageByScaling(toSize: newSize, mode: .pixels)
	}

    /// Resize the image to a max dimension from size parameter - aka scales while keeping the aspect ratio to fit inside the given dimensions.
	func imageByScaling(toSize size: CGSize, mode: ScalingMode = .points) async -> UIImage? {
		guard
			let data = flattened.pngData(),
			let imageSource = CGImageSourceCreateWithData(data as CFData, nil)
		else { return nil }

		let screenScale = await {
			switch mode {
			case .pixels:
				return 1.0
			case .points:
				return await UIScreen.main.scale
			}
		}()

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(size.width * screenScale, size.height * screenScale),
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]

        async let resizedImage = CGImageSourceCreateThumbnailAtIndex(
			imageSource,
			0,
			options as CFDictionary)
		.flatMap {
			UIImage(cgImage: $0, scale: screenScale, orientation: .up)
		}

		return await resizedImage
	}

    /// Renders the image if the pixel data was rotated due to orientation of camera
    var flattened: UIImage {
		guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size, format: imageRendererFormat).image { _ in
            draw(at: .zero)
        }
    }
}
