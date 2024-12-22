import UIKit
import SwiftPizzaSnips

class PeerSyncStateView: UIView {
	var connectedPeer: String {
		get { connectedPeerLabel.text ?? "" }
		set { connectedPeerLabel.text = newValue }
	}

	var itemsToSyncCount: Int {
		get { itemSyncCountLabel.text.flatMap(Int.init) ?? 0 }
		set { itemSyncCountLabel.text = newValue.description }
	}

	enum SyncState: String {
		case connecting = "connecting"
		case connected = "connected"
		case syncing = "syncing"
		case fullySynced = "fully Synced"
		case errored = "errored"
	}

	var state: SyncState = .connecting {
		didSet {
			syncStateLabel.text = state.rawValue.capitalized
		}
	}

	private let stackview = UIStackView().with {
		$0.axis = .vertical
		$0.alignment = .fill
		$0.distribution = .fill
	}
	private let connectedPeerLabel = UILabel().with {
		$0.font = .boldSystemFont(ofSize: 24)
	}

	private let itemSyncCountLabel = UILabel().with {
		$0.font = .systemFont(ofSize: 14)
	}

	private let syncStateLabel = UILabel().with {
		$0.font = .systemFont(ofSize: 24)
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	private func commonInit() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		addSubview(stackview)
		constraints += constrain(stackview)

		stackview.addArrangedSubview(connectedPeerLabel)
		stackview.addArrangedSubview(itemSyncCountLabel)
		stackview.addArrangedSubview(syncStateLabel)

		connectedPeer = "No One"
		itemsToSyncCount = 0
		state = .connecting
	}
}
