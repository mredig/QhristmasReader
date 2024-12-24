import UIKit
@preconcurrency import SwiftPizzaSnips
@preconcurrency import MultipeerConnectivity

class SyncController: UIViewController {

	enum Mode {
		case server(LocalNetworkEngineServer)
		case client(LocalNetworkEngineClient)
	}

	let mode: Mode
	let coreDataStack: CoreDataStack

	@MainActor
	private var syncStateViews: [MCPeerID: PeerSyncStateView] = [:]

	private let stackView = UIStackView().with {
		$0.axis = .vertical
		$0.alignment = .fill
		$0.distribution = .fill
	}

	init(asHost: Bool, username: String, coreDataStack: CoreDataStack) async {
		if asHost {
			let server = await LocalNetworkEngineServer(username: username, coreDataStack: coreDataStack)
			mode = .server(server)
		} else {
			let client = LocalNetworkEngineClient(username: username)
			mode = .client(client)
		}
		self.coreDataStack = coreDataStack

		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Peer Sync"
		navigationItem.largeTitleDisplayMode = .always
		configureViewLayout()

		switch mode {
		case .server(let localNetworkEngineServer):
			localNetworkEngineServer.delegate = self
			startHosting(server: localNetworkEngineServer)
		case .client(let localNetworkEngineClient):
			localNetworkEngineClient.delegate = self
			showBrowser(client: localNetworkEngineClient)
		}

		view.backgroundColor = .systemBackground
	}

	private func startHosting(server: LocalNetworkEngineServer) {
		server.start()
	}

	private func showBrowser(client: LocalNetworkEngineClient) {
		client.showBrowser(on: navigationController ?? self)
	}

	private func configureViewLayout() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(stackView)
		constraints += view.constrain(stackView, inset: NSDirectionalEdgeInsets(scalar: 24), safeAreaDirections: .all, directions: .init(top: .create, leading: .create, bottom: .skip, trailing: .create))

		constraints += [
			stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 24)
		]
	}

	private func getSyncView(for peerID: MCPeerID) -> PeerSyncStateView {
		if let existing = syncStateViews[peerID] {
			return existing
		} else {
			let new = PeerSyncStateView()
			new.connectedPeer = peerID.displayName
			syncStateViews[peerID] = new
			stackView.addArrangedSubview(new)

			return new
		}
	}

	private nonisolated func updateSyncView(for peerID: MCPeerID, _ block: @MainActor @escaping (PeerSyncStateView) -> Void) {
		Task { @MainActor in
			let view = getSyncView(for: peerID)

			block(view)
		}
	}

	private func removeSyncView(for peerID: MCPeerID) {
		syncStateViews[peerID]?.removeFromSuperview()
		syncStateViews[peerID] = nil
	}
}

extension SyncController: LocalNetworkEngine.Delegate {
	nonisolated
	func localNetworkEngine(
		_ localNetworkEngine: LocalNetworkEngine,
		didStartConnectingToNewPeer peer: MCPeerID
	) {}
	
	nonisolated
	func localNetworkEngine(
		_ localNetworkEngine: LocalNetworkEngine,
		didConnectToNewPeer peer: MCPeerID
	) {
		Task { @MainActor [self] in
			switch mode {
			case.client(let client):
				try await syncRecipientList(with: client, syncGiftsToo: true)
			case .server(_):
				print("dno")
			}
		}
	}
	
	nonisolated
	func localNetworkEngine(
		_ localNetworkEngine: LocalNetworkEngine,
		didDisconnectFromPeer peer: MCPeerID
	) {}
}

extension SyncController {
	private func syncRecipientList(with client: LocalNetworkEngineClient, syncGiftsToo: Bool) async throws {
		let availableRecipients = try await client.sendRecipientChangelistRequest()

		let needRecipientIDs = try await withThrowingTaskGroup(of: UUID?.self) { group in
			for (id, info) in availableRecipients {
				group.addTask { [self] in
					let context = await coreDataStack.newBackgroundContext()
					return try await context.perform {
						let fr = Recipient.fetchRequest()
						fr.fetchLimit = 1
						fr.predicate = NSPredicate(format: "id == %@", id as NSUUID)

						if let recipient = try context.fetch(fr).first {
							guard info.originID == recipient.originID else { return nil }
							guard info.lastUpdated > (recipient.lastUpdated ?? .distantPast) else { return nil }
							return recipient.id
						} else {
							return id
						}
					}
				}
			}

			var needUpdateIDs: [UUID] = []
			for try await id in group {
				guard let id else { continue }
				needUpdateIDs.append(id)
			}
			return needUpdateIDs
		}

//		delegate?.router(self, didUpdateRecipientPendingCount: needRecipientIDs.count, for: peer)
//		pendingRecipientCounts[peer] = needRecipientIDs.count

		guard needRecipientIDs.isOccupied else {
			guard syncGiftsToo else { return }
			try await syncGiftList(with: client)
			return
		}

		for id in needRecipientIDs {
			let recipient = try await client.sendRetrieveRecipientRequest(id)
			try await storeRecipient(recipient)
		}

		guard syncGiftsToo else { return }
		try await syncGiftList(with: client)
	}

	private func syncGiftList(with client: LocalNetworkEngineClient) async throws {
		let availableGifts = try await client.sendGiftListRequest()

		let needGiftIDs = try await withThrowingTaskGroup(of: UUID?.self) { group in
			for (id, info) in availableGifts {
				group.addTask { [self] in
					let context = await coreDataStack.newBackgroundContext()
					return try await context.perform { @Sendable in
						let fr = Gift.fetchRequest()
						fr.fetchLimit = 1
						fr.predicate = NSPredicate(format: "imageID == %@", id as NSUUID)

						if let gift = try context.fetch(fr).first {
							guard gift.originID == info.originID else { return nil }

							guard info.isDeleted == false else {
								gift.isArchived = true
								try context.save()
								return nil
							}

							guard info.lastUpdated > (gift.lastUpdated ?? .distantPast) else { return nil }
							return gift.imageID
						} else {
							return id
						}
					}
				}
			}

			var needUpdateIDs: [UUID] = []
			for try await id in group {
				guard let id else { continue }
				needUpdateIDs.append(id)
			}
			return needUpdateIDs
		}

//		delegate?.router(self, didUpdateRecipientPendingCount: needGiftIDs.count, for: peer)
//		pendingGiftCounts[peer] = needGiftIDs.count

		for id in needGiftIDs {
			let giftDTO = try await client.sendRetrieveGiftRequest(id)
			try await storeGift(giftDTO)
		}
	}

	private func storeRecipient(_ recipientDTO: Recipient.DTO) async throws {
		let context = coreDataStack.newBackgroundContext()
		try await context.perform { @Sendable in
			let fr = Recipient.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "id == %@", recipientDTO.id as NSUUID)

			if let recipient = try context.fetch(fr).first {
				recipient.update(from: recipientDTO)
			} else {
				_ = try Recipient(from: recipientDTO, context: context)
			}

			try context.save()
		}
	}

	private func storeGift(_ giftDTO: Gift.DTO) async throws {
		async let imageURL = Gift.url(for: giftDTO.imageID)

		let context = coreDataStack.newBackgroundContext()
		try await context.perform { @Sendable in
			let fr = Gift.fetchRequest()
			fr.fetchLimit = 1
			fr.predicate = NSPredicate(format: "imageID == %@", giftDTO.imageID as NSUUID)

			let gift = try context.fetch(fr).first
			if let gift {
				try gift.update(from: giftDTO, context: context)
			} else {
				_ = try Gift(from: giftDTO, context: context)
			}

			try context.save()
		}

		do {
			try FileManager.default.createDirectory(at: ScannerViewModel.storageDirectory, withIntermediateDirectories: true)
		} catch {
			print("Error creating storage directory: \(error)")
		}
		if let imageData = giftDTO.imageData {
			try await imageData.write(to: imageURL)
		}

//		let currentCount = pendingGiftCounts[peer, default: 0]
//		let newCount = currentCount - 1
//		pendingGiftCounts[peer] = newCount
//		delegate?.router(self, didUpdatePendingGiftCount: newCount, for: peer)
	}
}
