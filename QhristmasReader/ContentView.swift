import SwiftUI
import AVFoundation

struct ContentView: View {
	@State private var scannedCode: String?

	var body: some View {
		NavigationView {
			VStack {
				QRCodeScannerView { code in
					self.scannedCode = code
				}
				.edgesIgnoringSafeArea(.all)

				if let scannedCode = scannedCode {
					Text("Scanned Code: \(scannedCode)")
						.padding()
				}
			}
			.navigationBarTitle("QR Code Scanner")
		}
	}
}
#Preview {
    ContentView()
}
