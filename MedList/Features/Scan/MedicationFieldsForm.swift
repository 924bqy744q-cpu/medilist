import SwiftUI
import MedListCore

/// The seven editable fields, shared by Confirm (scanned) and Add/Edit (manual).
struct MedicationFields: View {
    @Binding var draft: MedicationDraft
    var idPrefix = "field"

    var body: some View {
        ForEach(MedField.allCases) { field in
            FieldRow(
                field: field,
                text: Binding(get: { draft.values[field] ?? "" }, set: { draft.set(field, $0) }),
                needsAttention: draft.needsAttention(field),
                identifier: "\(idPrefix).\(field.rawValue)")
        }
    }
}

struct FieldRow: View {
    let field: MedField
    @Binding var text: String
    let needsAttention: Bool
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(field.label)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if needsAttention {
                    // Never colour alone: icon + word as well.
                    Label("Check", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color("AttentionForeground"))
                        .accessibilityHidden(true)
                }
            }
            TextField(field.placeholder, text: $text, axis: .vertical)
                .font(.body)
                .textInputAutocapitalization(field == .drugName || field == .prescriber ? .words : .never)
                .autocorrectionDisabled()
                .accessibilityLabel(Text(field.label))
                .accessibilityHint(needsAttention ? Text("Please check this value. It may not have been read correctly.") : Text(""))
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 4)
        .listRowBackground(needsAttention ? Color("AttentionBackground") : nil)
    }
}
