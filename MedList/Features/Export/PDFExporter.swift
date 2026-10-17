import SwiftUI
import MedListCore

enum PDFExporter {
    enum ExportError: Error { case contextCreationFailed }

    private static var exportDirectory: URL {
        FileManager.default.temporaryDirectory.appending(path: "exports", directoryHint: .isDirectory)
    }

    /// Renders the one-page report to a protected temporary file. Delete it after sharing.
    @MainActor
    static func render(_ data: ReportData) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: exportDirectory, withIntermediateDirectories: true,
                               attributes: [.protectionKey: FileProtectionType.complete])
        let fileName = String(localized: "Medication list") + " " + data.generatedAt.formatted(.iso8601.year().month().day()) + ".pdf"
        let url = exportDirectory.appending(path: fileName)
        try? fm.removeItem(at: url)

        let renderer = ImageRenderer(content: ReportPage(data: data))
        renderer.proposedSize = ProposedViewSize(width: ReportLayout.pageSize.width, height: ReportLayout.pageSize.height)

        var mediaBox = CGRect(x: 0, y: 0, width: ReportLayout.pageSize.width, height: ReportLayout.pageSize.height)
        // Deliberately no author/creator metadata.
        let info = [kCGPDFContextTitle as String: String(localized: "Medication list")] as CFDictionary
        guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, info) else { throw ExportError.contextCreationFailed }
        renderer.render { _, draw in
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
        }
        pdf.closePDF()
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        PrivacyLog.event("pdf_exported", count: data.medications.count)
        return url
    }

    static func removeTemporaryExports() {
        try? FileManager.default.removeItem(at: exportDirectory)
    }
}
