import SwiftUI

@Observable
class ScannerViewModel {
	protocol Delegate: AnyObject {
		func scannerViewModel(_ scannerViewModel: ScannerViewModel, didFindCodeMatch code: UUID, withImage image: UIImage)
		func scannerViewModel(_ scannerViewModel: ScannerViewModel, didNotFindCodeMatch code: UUID)
	}

	private(set) var capturingImageID: UUID?

	var storedItems: [URL]

	weak var delegate: Delegate?

	static private let storageDirectory: URL = .applicationSupportDirectory.appending(component: "Images")

	init() {
		self.storedItems = Self.storedItems()
	}

	static private func url(for id: UUID) -> URL {
		storageDirectory.appending(component: id.uuidString.lowercased()).appendingPathExtension("jpg")
	}

	static private func storedItems() -> [URL] {
		do {
			let content = try FileManager
				.default
				.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
				.filter { $0.pathExtension == "jpg" }
				.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
			
			return content
		} catch {
			print("Error listing content: \(error)")
			return []
		}
	}	

	func foundCode(_ code: UUID) {
		let url = Self.url(for: code)

		do {
			let imageData = try Data(contentsOf: url)
			guard
				let image = UIImage(data: imageData)
			else { throw Error.notImage }
			delegate?.scannerViewModel(self, didFindCodeMatch: code, withImage: image)
		} catch {
			capturingImageID = code
			delegate?.scannerViewModel(self, didNotFindCodeMatch: code)
		}
	}

	func storeImage(_ image: UIImage?, for id: UUID?) {
		defer { capturingImageID = nil }
		guard let image else { return }
		guard let id = id ?? capturingImageID else { return }

		guard
			let imageData = image.jpegData(compressionQuality: 0.85)
		else { return }

		let url = Self.url(for: id)
		do {
			try FileManager.default.createDirectory(at: Self.storageDirectory, withIntermediateDirectories: true)
			try imageData.write(to: url)
			storedItems.append(url)
		} catch {
			print("Cant save cuz \(error.localizedDescription)")
		}
	}

	enum Error: Swift.Error {
		case notImage
	}
}
