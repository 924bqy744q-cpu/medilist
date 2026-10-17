import SwiftUI
import PhotosUI
import VisionKit
import MedListCore

/// Capture → on-device OCR → redact → extract → Confirm. Photos are held in memory only and never saved.
struct ScanView: View {
    let recipient: CareRecipient
    @Binding var path: [Route]
    @Environment(AppEnvironment.self) private var env

    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var phase: Phase = .idle

    enum Phase: Equatable {
        case idle
        case working
        case nothingFound(String)
        case failed
    }

    var body: some View {
        List {
            Section {
                Text("Photograph a pill bottle label, a pharmacy box, or the medication list from discharge papers. Make sure the text is sharp and well lit.")
            }

            Section {
                if VNDocumentCameraViewController.isSupported {
                    Button { showCamera = true } label: {
                        Label("Use camera", systemImage: "camera")
                    }
                    .accessibilityIdentifier("scan.camera")
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose a photo", systemImage: "photo.on.rectangle")
                }
                .accessibilityIdentifier("scan.photo")
                if env.launch.showSampleScanInput {
                    Button { Task { await process(text: SampleData.scanText) } } label: {
                        Label("Use sample label", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("scan.sample")
                }
            } footer: {
                Text("Text is read on this device. Photos are never stored or uploaded.")
            }
            .disabled(phase == .working)

            switch phase {
            case .idle:
                EmptyView()
            case .working:
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Reading the label…")
                    }
                    .accessibilityElement(children: .combine)
                }
            case .nothingFound(let text):
                Section {
                    Text("No medication details were found. Try a sharper photo, or add the medication by hand.")
                    Button("Add by hand") { path = [.add] }
                    if !text.isEmpty {
                        DisclosureGroup("Show recognized text") {
                            Text(text).font(.footnote.monospaced())
                        }
                    }
                }
            case .failed:
                Section {
                    Text("The photo could not be read. Please try again.")
                }
            }
        }
        .navigationTitle("Scan label")
        .fullScreenCover(isPresented: $showCamera) {
            DocumentCamera { images in
                showCamera = false
                Task { await process(images: images) }
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                photoItem = nil
                if let data, let image = UIImage(data: data) {
                    await process(images: [image])
                } else {
                    phase = .failed
                }
            }
        }
    }

    private func process(images: [UIImage]) async {
        phase = .working
        var pages: [String] = []
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            if let text = try? await TextRecognizer.recognizeText(in: cgImage, orientation: .init(image.imageOrientation)) {
                pages.append(text)
            }
        }
        await process(text: pages.joined(separator: "\n"))
    }

    private func process(text: String) async {
        phase = .working
        let redacted = OCRRedactor(recipientName: recipient.name, dateOfBirth: recipient.dateOfBirth).redact(text)
        var usedFallback = false
        var meds: [ExtractedMedication]
        do {
            meds = try await env.extractionService.extract(from: redacted, languageCode: env.languageCode)
        } catch {
            // Online extraction failed: read on-device instead and tell the user.
            usedFallback = env.useOnlineExtraction
            meds = (try? await MockExtractionService().extract(from: redacted, languageCode: env.languageCode)) ?? []
        }
        PrivacyLog.event("scan_extracted", count: meds.count)

        guard !meds.isEmpty else {
            phase = .nothingFound(redacted)
            return
        }
        phase = .idle
        let result = ScanResult(drafts: meds.map(MedicationDraft.init(extracted:)), recognizedText: redacted, usedFallback: usedFallback)
        path = [.confirm(result)]
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// VisionKit's document camera: edge detection, perspective correction, multi-page capture.
struct DocumentCamera: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCamera
        init(_ parent: DocumentCamera) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.onScan((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
