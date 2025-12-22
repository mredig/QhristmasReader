import Foundation
import Hummingbird
import Logging
import Compression

import SwiftPizzaSnips

enum HTTPHost {
	static let serverLogger = Logger(label: "HTTP Server")

	static func startListening(coreDataStack: CoreDataStack) async throws {
		let router = Router()

		let container = try coreDataStack.configuredContainer
		let sqlStore = container.persistentStoreDescriptions.first?.url

		router.get { request, context in
			"Hello worldddddddddd"
		}

		router.get("db") { request, context in
			guard let sqlURL = sqlStore else { throw HTTPError(.internalServerError) }

			let data = try Data(contentsOf: sqlURL)

			return Response(
				status: .ok,
				headers: [
					.cacheControl: "no-store, no-cache, must-revalidate, max-age=0",
					.expires: "0",
				],
				body: .init(byteBuffer: ByteBuffer(data: data)))
		}

		let giftsLogger = Logger(label: "Gifts Controller")
		let giftsController = GiftsController(logger: giftsLogger, coreDataStack: coreDataStack)
		giftsController.addRoutes(giftsGroup: router.group("gifts"))

		let recipientsLogger = Logger(label: "Recipients Logger")
		let recipientsController = RecipientsController(logger: recipientsLogger, coreDataStack: coreDataStack)
		recipientsController.addRoutes(recipientsGroup: router.group("recipients"))

		let config = ApplicationConfiguration(
			address: .hostname("0.0.0.0", port: 8080),
			serverName: "QRistmasHost")

		let app = Application(
			router: router,
			configuration: config,
			logger: serverLogger)

		try await app.runService()
	}
}
