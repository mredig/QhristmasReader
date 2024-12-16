import SwiftUI
import AVFoundation

struct ContentView: View {
	@State private var scannedCode: String?

	@State
	var viewModel = ScannerViewModel()

	var body: some View {
		switch viewModel.state {
		case .scanningCodes:
			QRCodeScannerView { code in
				viewModel.foundCode(code)
			}
			.edgesIgnoringSafeArea(.all)
		case .capturingImage(let id):
			PhotoCaptureView { image in
				viewModel.storeImage(image, for: id)
			}
		case .displayingImage(let image):
			ZStack(alignment: .bottom) {
				Image(uiImage: image)
					.resizable(resizingMode: .stretch)
					.aspectRatio(contentMode: .fill)

				Button(
					action: {
						viewModel.state = .scanningCodes
					},
					label: {
						Text("Done")
					})
			}
		}
	}
}
//#Preview {
//    ContentView()
//}
