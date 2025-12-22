import SwiftUI
@preconcurrency import SwiftPizzaSnips
@preconcurrency import MultipeerConnectivity

class SyncViewController: UIHostingController<SyncView> {
	let coreDataStack: CoreDataStack
	private let syncClient: LocalNetworkEngineClient

	let viewModel: SyncView.ViewModel

	init(username: String, coreDataStack: CoreDataStack) async {
		self.syncClient = LocalNetworkEngineClient(username: username)
		self.coreDataStack = coreDataStack

		let vm = SyncView.ViewModel()
		self.viewModel = vm

		super.init(rootView: SyncView(viewModel: vm))

		vm.onSearch = { [weak self, syncClient] in
			self?.showBrowser(client: syncClient)
		}

		syncClient.delegate = self
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		syncClient.disconnect()
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Peer Sync"
		navigationItem.largeTitleDisplayMode = .always

		view.backgroundColor = .systemBackground
	}

	private func showBrowser(client: LocalNetworkEngineClient) {
		client.showBrowser(on: navigationController ?? self)
	}
}

extension SyncViewController: LocalNetworkEngine.Delegate {
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
		Task { @MainActor in
			defer { syncClient.disconnect() }
			do {
				viewModel.peers.append(peer)

				syncClient.dismissBrowser()

				let ipURL = try await syncClient.sendHostAddressRequest()

				let client = HTTPClient(baseURL: ipURL)

				try await syncRecipientList(with: client, syncGiftsToo: true)

				let alertVC = UIAlertController(title: "Complete", message: "Sync Completed!", preferredStyle: .alert)
				let okayButton = UIAlertAction(title: "Ok", style: .default)
				alertVC.addAction(okayButton)

				present(alertVC, animated: true)
			} catch {
				print("Error syncing with host: \(error)")
			}
		}
	}
	
	nonisolated
	func localNetworkEngine(
		_ localNetworkEngine: LocalNetworkEngine,
		didDisconnectFromPeer peer: MCPeerID
	) {
		Task { @MainActor in
			viewModel.peers.removeAll(where: {
				$0 === peer
			})
		}
	}
}

extension SyncViewController {
	private func syncRecipientList(with client: HTTPClient, syncGiftsToo: Bool) async throws {
		let availableRecipients = try await client.sendRecipientChangelistRequest()

		let needRecipientIDs = try await withThrowingTaskGroup(of: UUID?.self) { group in
			for (id, info) in availableRecipients {
				group.addTask { [self] in
					let context = coreDataStack.newBackgroundContext()
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
			let recipient = try await client.getRecipient(id: id)
			try await storeRecipient(recipient)
		}

		guard syncGiftsToo else { return }
		try await syncGiftList(with: client)
	}

	private func syncGiftList(with client: HTTPClient) async throws {
		let availableGifts = try await client.sendGiftChangelistRequest()

		let needGiftIDs = try await withThrowingTaskGroup(of: UUID?.self) { group in
			for (id, info) in availableGifts {
				group.addTask { [self] in
					let context = coreDataStack.newBackgroundContext()
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
			let giftDTO = try await client.getGift(id: id)
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
