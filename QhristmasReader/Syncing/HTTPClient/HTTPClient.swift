import Foundation
import NetworkHandler
import NetworkHandlerURLSessionEngine

final class HTTPClient: Sendable {
	private let baseURL: URL
	private static let recipientsEndpoint = "recipients"
	private static let giftsEndpoint = "gifts"

	private let nh: NetworkHandler<URLSession>

	init(baseURL: URL) {
		self.baseURL = baseURL

		let engine = URLSession.asEngine(withConfiguration: .networkHandlerDefault)
		nh = NetworkHandler(
			name: "QRliet",
			engine: engine,
			logger: .init(label: "QRlient"),
			cacheLogger: .init(label: "QRache"))
	}

	// MARK: - Recipients
	func sendRecipientChangelistRequest() async throws -> [UUID: ListItemInfo] {
		let url = baseURL
			.appending(components: Self.recipientsEndpoint, "listChangeStates")

		return try await nh.downloadMahCodableDatas(for: url.generalRequest).decoded
	}

	func sendRecipientListRequest() async throws -> [Recipient.ListDTO] {
		let url = baseURL
			.appending(components: Self.recipientsEndpoint, "list")

		return try await nh.downloadMahCodableDatas(for: url.generalRequest).decoded
	}

	func getRecipient(id: UUID) async throws -> Recipient.DTO {
		let url = baseURL
			.appending(components: Self.recipientsEndpoint, "id", id.uuidString)

		return try await nh.downloadMahCodableDatas(for: url.generalRequest).decoded
	}

	// MARK: - Gifts
	func sendGiftChangelistRequest() async throws -> [UUID: ListItemInfo] {
		let url = baseURL
			.appending(components: Self.giftsEndpoint, "listChangeStates")

		return try await nh.downloadMahCodableDatas(for: url.generalRequest).decoded
	}

	func queryGift(id: UUID, for recipients: Set<UUID>) async throws -> GiftsController.GiftQueryResponse {
		let url = baseURL
			.appending(components: Self.giftsEndpoint, "query")

		let payload = GiftsController.GiftQueryRequest(
			imageID: id,
			representedRecipientIDs: recipients)

		var request = url.generalRequest
		try request.encodeData(payload)
		request.method = .post

		return try await nh.downloadMahCodableDatas(for: request).decoded
	}

	func getGift(id: UUID) async throws -> Gift.DTO {
		let url = baseURL
			.appending(components: Self.giftsEndpoint, "id", id.uuidString)

		return try await nh.downloadMahCodableDatas(for: url.generalRequest).decoded
	}
}
