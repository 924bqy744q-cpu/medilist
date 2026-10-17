import SwiftUI
import MedListCore

/// Everything printed on the "Bring to appointment" page.
struct ReportData {
    var recipientName: String
    var dateOfBirth: Date
    var generatedAt: Date
    var medications: [MedicationSnapshot]
    var flags: [MedicationFlag]
    var interactionCheckFailed: Bool
    var interactionSource: String
    var copy: FlagCopy
    var locale: Locale
}

/// Fixed-size A4 page rendered to PDF with ImageRenderer. Always light, never affected by Dynamic Type,
/// and sized by `ReportLayout` so the content fits on exactly one page.
struct ReportPage: View {
    let data: ReportData
    private let layout: ReportLayout

    init(data: ReportData) {
        self.data = data
        layout = ReportLayout.plan(rowCount: data.medications.count, flagCount: data.flags.count)
    }

    private var fontSize: CGFloat { layout.fontSize }
    private let columns: [(LocalizedStringKey, CGFloat)] = [
        ("Medication", 0.30), ("Amount each time", 0.15), ("How often", 0.20), ("Prescriber", 0.17), ("Purpose", 0.18),
    ]
    private var contentWidth: CGFloat { ReportLayout.pageSize.width - 2 * ReportLayout.margin }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: ReportLayout.headerHeight, alignment: .topLeading)
            table
            if !data.flags.isEmpty || data.interactionCheckFailed {
                flags
            }
            Spacer(minLength: 0)
            footer
                .frame(height: ReportLayout.footerHeight, alignment: .bottomLeading)
        }
        .padding(ReportLayout.margin)
        .frame(width: ReportLayout.pageSize.width, height: ReportLayout.pageSize.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.locale, data.locale)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Medication list – bring to appointment")
                .font(.system(size: 18, weight: .bold))
            Text("\(data.recipientName), born \(data.dateOfBirth.formatted(.dateTime.day().month(.wide).year().locale(data.locale)))")
                .font(.system(size: 13, weight: .semibold))
            Text("Generated on \(data.generatedAt.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(data.locale)))")
                .font(.system(size: 10))
            Text("Entered and checked by the caregiver. Please compare with your own records.")
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.3))
        }
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(columns.map { Text($0.0) }, bold: true)
                .background(Color(white: 0.9))
            ForEach(Array(data.medications.prefix(layout.visibleRows).enumerated()), id: \.element.id) { index, med in
                row([
                    Text([med.name, med.strength, med.form].compactMap { $0 }.joined(separator: " ")).bold(),
                    Text(med.dose ?? "–"),
                    Text(med.frequency ?? "–"),
                    Text(med.prescriber ?? "–"),
                    Text(med.purpose ?? "–"),
                ], bold: false, lines: ReportLayout.maxLinesPerCell)
                .background(index.isMultiple(of: 2) ? Color.white : Color(white: 0.96))
            }
            if layout.hiddenRows > 0 {
                Text("List continues: \(layout.hiddenRows) more medications are not shown. See the app.")
                    .font(.system(size: fontSize, weight: .semibold))
                    .padding(.vertical, ReportLayout.rowPadding / 2)
            }
        }
        .overlay(Rectangle().strokeBorder(Color(white: 0.6), lineWidth: 0.5))
    }

    private func row(_ cells: [Text], bold: Bool, lines: Int = 1) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(cells.indices, id: \.self) { i in
                cells[i]
                    .font(.system(size: fontSize, weight: bold ? .semibold : .regular))
                    .lineLimit(lines)
                    .lineSpacing(fontSize * (ReportLayout.lineSpacing - 1))
                    .padding(.horizontal, 3)
                    .frame(width: contentWidth * columns[i].1, alignment: .topLeading)
            }
        }
        .padding(.vertical, ReportLayout.rowPadding / 2)
    }

    private var flags: some View {
        VStack(alignment: .leading, spacing: ReportLayout.rowPadding) {
            Text(data.copy.flagsSectionTitle)
                .font(.system(size: fontSize + 1, weight: .bold))
                .padding(.top, ReportLayout.rowPadding)
            if data.interactionCheckFailed {
                Text(data.copy.interactionCheckUnavailable)
                    .font(.system(size: fontSize))
            }
            ForEach(data.flags.prefix(layout.visibleFlags)) { flag in
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Text(data.copy.title(for: flag)).bold()): \(data.copy.body(for: flag))")
                        .lineLimit(1)
                    Text(data.copy.verifyWithPharmacist)
                        .fontWeight(.semibold)
                }
                .font(.system(size: fontSize))
            }
            if layout.hiddenFlags > 0 {
                Text("\(layout.hiddenFlags) more flags are shown in the app.")
                    .font(.system(size: fontSize, weight: .semibold))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            Divider()
            Text(data.copy.disclaimer)
            Text(data.copy.noFlagsIsNotAClearance)
            Text("Interaction data: \(data.interactionSource)")
        }
        .font(.system(size: 8))
        .foregroundStyle(Color(white: 0.25))
    }
}
