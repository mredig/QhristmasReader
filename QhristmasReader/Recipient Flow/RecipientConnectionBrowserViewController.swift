import UIKit
@preconcurrency import SwiftPizzaSnips
@preconcurrency import MultipeerConnectivity

class RecipientConnectionBrowserViewController: UIViewController {

	static let serviceTypeIdentifier = "b"

	private nonisolated let peerID: MCPeerID
	private nonisolated let session: MCSession
	private nonisolated let advertiser: MCNearbyServiceAdvertiser?

	private var browser: MCBrowserViewController?

	@MainActor
	private var syncStateViews: [MCPeerID: PeerSyncStateView] = [:]

	private let stackView = UIStackView().with {
		$0.axis = .vertical
		$0.alignment = .fill
		$0.distribution = .fill
	}

	let router: Router

	init(asHost: Bool, username: String, coreDataStack: CoreDataStack) async {
		let peerID = MCPeerID(displayName: username)
		let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)

		let advertiser: MCNearbyServiceAdvertiser?
		if asHost {
			advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceTypeIdentifier)
		} else {
			advertiser = nil
		}

		self.peerID = peerID
		self.session = session
		self.advertiser = advertiser
		self.router = await Router(coreDataStack: coreDataStack, session: session)

		super.init(nibName: nil, bundle: nil)
		advertiser?.delegate = self
		session.delegate = self
		router.delegate = self
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Peer Sync"
		navigationItem.largeTitleDisplayMode = .always
		configureViewLayout()

		if advertiser == nil {
			showBrowser()
		} else {
			startHosting()
		}

		view.backgroundColor = .systemBackground
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		advertiser?.stopAdvertisingPeer()
	}

	private func startHosting() {
		guard let advertiser else { return }
		advertiser.startAdvertisingPeer()
	}

	private func showBrowser() {
		let browser = MCBrowserViewController(serviceType: Self.serviceTypeIdentifier, session: session)
		self.browser = browser
		browser.delegate = self
		browser.maximumNumberOfPeers = 1

		let root = navigationController ?? self

		root.present(browser, animated: true)
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

extension RecipientConnectionBrowserViewController: MCSessionDelegate {
	nonisolated
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		Task {
			switch state {
			case .notConnected:
				print("\(peerID) disconnected")
				await removeSyncView(for: peerID)
			case .connecting:
				print("\(peerID) is connecting")
				updateSyncView(for: peerID) {
					$0.connectedPeer = peerID.displayName
					$0.state = .connecting
				}
			case .connected:
				updateSyncView(for: peerID) { [weak self] in
					$0.connectedPeer = peerID.displayName
					$0.state = .connected
					self?.browser?.dismiss(animated: true)
				}

				Task {
					try await router.send(to: peerID.getSendableData(), request: .listRecipientIDs)
				}
			@unknown default:
				fatalError("Unknown state: \(state)")
			}
		}
	}

	nonisolated
	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		Task {
			try await router.route(data: data, from: peerID.getSendableData())
		}
	}

	nonisolated
	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		print("\(#function): \(peerID) - \(streamName)")
	}

	nonisolated
	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
		print("\(#function): \(peerID) - \(resourceName)")
	}

	nonisolated
	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {
		print("\(#function): \(peerID) - \(resourceName)")
	}
}

extension RecipientConnectionBrowserViewController: MCBrowserViewControllerDelegate {
	nonisolated
	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
		}
	}

	nonisolated
	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
		}
	}

	nonisolated
	func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
		print("\(#function): \(peerID) - \(info as Any)")
		return true
	}
}

extension RecipientConnectionBrowserViewController: MCNearbyServiceAdvertiserDelegate {
	nonisolated
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
		print("\(#function): \(peerID) - \(error)")
	}

	nonisolated
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		print("\(#function): \(peerID) - \(context as Any)")

		invitationHandler(true, session)
	}
}

extension RecipientConnectionBrowserViewController: Router.Delegate {
	nonisolated
	func router(_ router: Router, didUpdatePendingGiftCount count: Int, for peer: MCPeerID.SendableDTO) {
		do {
			let peerID = try MCPeerID.fromSendableData(peer)
			updateSyncView(for: peerID) {
				$0.itemsToSyncCount = count
			}
		} catch {
			print("Error updating peer: \(error)")
		}
	}

	nonisolated
	func router(_ router: Router, didUpdateRecipientPendingCount count: Int, for peer: MCPeerID.SendableDTO) {
		do {
			let peerID = try MCPeerID.fromSendableData(peer)
			updateSyncView(for: peerID) {
				$0.itemsToSyncCount = count
			}
		} catch {
			print("Error updating peer: \(error)")
		}
	}
}
