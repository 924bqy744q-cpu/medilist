import SwiftUI
import UIKit
import MedListCore

struct ExportView: View {
    let recipient: CareRecipient
    let medications: [Medication]
    @Environment(AppEnvironment.self) private var env
    @State private var shareURL: URL?
    @State private var failed = false

    private var data: ReportData {
        ReportData(
            recipientName: recipient.name,
            dateOfBirth: recipient.dateOfBirth,
            generatedAt: .now,
            medications: medications.map(\.snapshot),
            flags: env.flags.result.flags,
            interactionCheckFailed: env.flags.result.interactionCheckFailed,
            interactionSource: env.interactionSourceName,
            copy: .current,
            locale: .current)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("A one-page summary to bring to appointments. Check it before sharing.")
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Scaled preview of the exact page that will be shared.
                GeometryReader { proxy in
                    let scale = proxy.size.width / ReportLayout.pageSize.width
                    ReportPage(data: data)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: proxy.size.width, height: ReportLayout.pageSize.height * scale, alignment: .topLeading)
                }
                .aspectRatio(ReportLayout.pageSize.width / ReportLayout.pageSize.height, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(.separator)))
                .shadow(radius: 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Preview of the PDF with \(medications.count) medications"))
            }
            .padding()
        }
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                do { shareURL = try PDFExporter.render(data) } catch { failed = true }
            } label: {
                Label("Share PDF", systemImage: "square.and.arrow.up")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("export.share")
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url]) {
                // Minimise retention: the PDF exists only while the share sheet is open.
                try? FileManager.default.removeItem(at: url)
                shareURL = nil
            }
            .presentationDetents([.medium, .large])
        }
        .alert("The PDF could not be created.", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
