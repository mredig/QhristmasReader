import SwiftUI
import SwiftPizzaSnips

class GiftDetailController: UIHostingController<GiftDetailView> {

	let viewModel: GiftDetailViewModel

	private let editButton = UIBarButtonItem(systemItem: .edit)
	private let saveButton = UIBarButtonItem(systemItem: .done)

	init(viewModel: GiftDetailViewModel) {
		self.viewModel = viewModel
		super.init(rootView: GiftDetailView(viewModel: viewModel))
	}
	
	@MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		configureBarButtonItems()
	}

	private func configureBarButtonItems() {
		if viewModel.canEdit {
			let saveAction = UIAction { [weak self] _ in
				self?.toggleEditingState()
				self?.viewModel.saveGift()
			}
			saveButton.primaryAction = saveAction

			let editAction = UIAction { [weak self] _ in
				self?.toggleEditingState()
			}

			editButton.primaryAction = editAction

			navigationItem.rightBarButtonItems = [editButton, saveButton]
			updateEditButton()
		}
	}

	private func updateEditButton() {
		if viewModel.isEditing {
			editButton.isHidden = true
			saveButton.isHidden = false
		} else {
			editButton.isHidden = false
			saveButton.isHidden = true
		}
	}

	private func toggleEditingState() {
		viewModel.toggleEditState()
		updateEditButton()
	}
//	private let image: UIImage
//	private let gift: Gift
//
//	let coreDataStack: CoreDataStack
//
//	private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
//
//	init(imageID: UUID, coreDataStack: CoreDataStack) throws {
//		let imageURL = ScannerViewModel.url(for: imageID)
//		let imageData = try Data(contentsOf: imageURL)
//		guard
//			let image = UIImage(data: imageData)
//		else { throw SimpleError(message: "Image not found") }
//
//		let context = coreDataStack.mainContext
//		let gift = (try? context.performAndWait({
//			let fr = Gift.fetchRequest()
//			fr.predicate = NSPredicate(format: "imageID == %@", imageID as NSUUID)
//
//			return try context.fetch(fr).first
//		})) ?? Gift(imageID: imageID, context: context)
//
//		self.gift = gift
//		self.image = image
//		self.coreDataStack = coreDataStack
//
//		super.init(nibName: nil, bundle: nil)
//	}
//	
//	required init?(coder: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
//
//	override func viewDidLoad() {
//		super.viewDidLoad()
//
//
//	}
}
