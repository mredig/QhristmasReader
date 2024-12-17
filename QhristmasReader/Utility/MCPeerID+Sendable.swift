import MultipeerConnectivity

extension MCPeerID {
	func getSendableData() throws -> SendableDTO {
		let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
		return .init(data: data)
	}

	static func fromSendableData(_ dto: SendableDTO) throws -> MCPeerID {
		let data = dto.data
		return try NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data).unwrap()
	}

	struct SendableDTO: Sendable {
		let data: Data

		fileprivate init(data: Data) {
			self.data = data
		}
	}
}

