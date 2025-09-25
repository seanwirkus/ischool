import SwiftUI

struct ScannedDocument: Identifiable, Hashable {
    let id: UUID
    let filename: String
    let data: Data
    let pageCount: Int
    let scannedAt: Date

    init(id: UUID = UUID(), filename: String, data: Data, pageCount: Int, scannedAt: Date = Date()) {
        self.id = id
        self.filename = filename
        self.data = data
        self.pageCount = pageCount
        self.scannedAt = scannedAt
    }
}

#if os(iOS)
import UIKit
import VisionKit

@available(iOS 17.0, *)
struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: ([ScannedDocument]) -> Void
    var onCancel: () -> Void
    var onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    fileprivate func generateDocuments(from scan: VNDocumentCameraScan) throws -> [ScannedDocument] {
        guard scan.pageCount > 0, let pdfData = makePDFData(from: scan) else {
            throw ScannerError.failedToCreateDocument
        }
        let filename = Self.fileNameFormatter.string(from: Date()) + ".pdf"
        let document = ScannedDocument(filename: filename, data: pdfData, pageCount: scan.pageCount)
        return [document]
    }

    private func makePDFData(from scan: VNDocumentCameraScan) -> Data? {
        let mutableData = NSMutableData()
        UIGraphicsBeginPDFContextToData(mutableData, .zero, nil)
        defer { UIGraphicsEndPDFContext() }

        for pageIndex in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageIndex)
            let bounds = CGRect(origin: .zero, size: image.size)
            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            image.draw(in: bounds)
        }

        return mutableData as Data
    }

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'Scan' HH.mm"
        return formatter
    }()

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            do {
                let documents = try parent.generateDocuments(from: scan)
                parent.onComplete(documents)
            } catch {
                parent.onError(error)
            }
        }
    }
}

@available(iOS 17.0, *)
extension DocumentScannerView {
    enum ScannerError: LocalizedError {
        case failedToCreateDocument

        var errorDescription: String? {
            switch self {
            case .failedToCreateDocument:
                return "We couldn't create a PDF from the scanned pages. Please try scanning again."
            }
        }
    }
}

struct DocumentScannerSheet: View {
    var onComplete: ([ScannedDocument]) -> Void
    var onError: (Error) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                DocumentScannerView { documents in
                    dismiss()
                    onComplete(documents)
                } onCancel: {
                    dismiss()
                } onError: { error in
                    dismiss()
                    onError(error)
                }
                .ignoresSafeArea()
            } else {
                legacyScannerUnavailableView()
            }
        }
    }

    @ViewBuilder
    private func legacyScannerUnavailableView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Document scanning requires iOS 17 or later.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Update your device to access the built-in scanner or import files instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Dismiss") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .presentationDetents([.medium])
    }
}
#endif
