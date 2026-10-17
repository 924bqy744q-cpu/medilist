import Foundation

/// Decides how a "Bring to appointment" report fits on exactly one A4 page.
///
/// The SwiftUI page caps every table cell at `maxLinesPerCell` lines, so a row's height is bounded and the
/// plan is deterministic: shrink the font down to `minimumFontSize`, then truncate with a "N more" line.
public struct ReportLayout: Equatable, Sendable {
    public static let pageSize = (width: 595.0, height: 842.0) // A4 in points
    public static let margin = 36.0
    public static let maxLinesPerCell = 2
    public static let baseFontSize = 11.0
    public static let minimumFontSize = 8.0

    /// Fixed blocks: header (title, recipient, date) and footer (disclaimer). Measured generously.
    public static let headerHeight = 96.0
    public static let footerHeight = 64.0
    public static let tableHeaderLines = 1.0
    public static let lineSpacing = 1.25
    public static let rowPadding = 6.0

    public let fontSize: Double
    public let visibleRows: Int
    public let hiddenRows: Int
    public let visibleFlags: Int
    public let hiddenFlags: Int

    public static func plan(rowCount: Int, flagCount: Int) -> ReportLayout {
        var size = baseFontSize
        while true {
            let fit = fitting(rows: rowCount, flags: flagCount, fontSize: size)
            if fit.hiddenRows == 0 && fit.hiddenFlags == 0 || size <= minimumFontSize { return fit }
            size = max(minimumFontSize, size - 0.5)
        }
    }

    static func fitting(rows: Int, flags: Int, fontSize: Double) -> ReportLayout {
        let line = fontSize * lineSpacing
        let rowHeight = Double(maxLinesPerCell) * line + rowPadding
        let flagHeight = 2 * line + rowPadding      // flags are capped at two lines too
        let moreLine = line + rowPadding
        var available = pageSize.height - 2 * margin - headerHeight - footerHeight - tableHeaderLines * line - rowPadding

        // Flags are safety information: reserve space for them first (up to half the page body).
        let flagSectionTitle = flags > 0 ? line + rowPadding : 0
        let flagBudget = min(Double(flags) * flagHeight + flagSectionTitle, available / 2)
        var visibleFlags = flags == 0 ? 0 : max(0, Int((flagBudget - flagSectionTitle) / flagHeight))
        if visibleFlags < flags { visibleFlags = max(0, Int((flagBudget - flagSectionTitle - moreLine) / flagHeight)) }
        available -= flags == 0 ? 0 : flagSectionTitle + Double(visibleFlags) * flagHeight + (visibleFlags < flags ? moreLine : 0)

        var visibleRows = Int(available / rowHeight)
        if visibleRows < rows { visibleRows = max(0, Int((available - moreLine) / rowHeight)) }
        visibleRows = min(visibleRows, rows)

        return ReportLayout(
            fontSize: fontSize,
            visibleRows: visibleRows,
            hiddenRows: rows - visibleRows,
            visibleFlags: min(visibleFlags, flags),
            hiddenFlags: max(0, flags - visibleFlags))
    }
}
