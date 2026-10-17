import SwiftUI
import Observation
import MedListCore

/// Holds the latest flag evaluation for the list. Recomputed whenever the medications change.
@MainActor
@Observable
final class FlagsModel {
    private(set) var result = FlagResult(flags: [], interactionCheckFailed: false, unresolvedMedicationIDs: [])
    private var lastInput: [MedicationSnapshot]?

    var flaggedIDs: Set<UUID> { Set(result.flags.flatMap(\.medicationIDs)) }

    func refresh(_ meds: [MedicationSnapshot], engine: FlagEngine) async {
        guard meds != lastInput else { return }
        lastInput = meds
        result = await engine.evaluate(meds)
    }
}

extension FlagCopy {
    static var current: FlagCopy {
        FlagCopy(language: Locale.current.language.languageCode?.identifier ?? "en")
    }
}

struct FlagBanner: View {
    let result: FlagResult
    let open: () -> Void

    var body: some View {
        if !result.flags.isEmpty || result.interactionCheckFailed {
            Section {
                Button(action: open) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(Color("AttentionForeground"))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            if result.flags.isEmpty {
                                Text("Interaction check unavailable")
                                    .font(.headline)
                            } else {
                                Text("\(result.flags.count) flags to review")
                                    .font(.headline)
                            }
                            Text(FlagCopy.current.verifyWithPharmacist)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color("AttentionBackground"))
                .accessibilityIdentifier("list.flagBanner")
                .accessibilityHint(Text("Shows the flags"))
            }
        }
    }
}

struct FlagsView: View {
    let medications: [Medication]
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let copy = FlagCopy.current
        let result = env.flags.result
        List {
            if result.interactionCheckFailed {
                Section {
                    Label(copy.interactionCheckUnavailable, systemImage: "wifi.exclamationmark")
                }
            }

            if result.flags.isEmpty {
                Section {
                    Label("No flags found", systemImage: "checkmark.circle")
                        .font(.headline)
                }
            }

            ForEach(result.flags) { flag in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(copy.title(for: flag)).font(.headline)
                        } icon: {
                            Image(systemName: flag.kind == .interaction ? "arrow.triangle.swap" : "square.on.square")
                                .foregroundStyle(Color("AttentionForeground"))
                        }
                        Text(copy.body(for: flag))
                        Text(copy.verifyWithPharmacist)
                            .font(.body.weight(.semibold))
                        if let source = copy.source(for: flag) {
                            Text(source)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("flag.\(flag.kind.rawValue)")
                }
            }

            let unresolved = medications.filter { result.unresolvedMedicationIDs.contains($0.id) }
            if !unresolved.isEmpty {
                Section {
                    Text(copy.unresolvedName)
                    ForEach(unresolved) { Text($0.name).font(.body.weight(.semibold)) }
                } header: {
                    Text("Names not recognized")
                }
            }

            Section {
                Text(copy.noFlagsIsNotAClearance)
                Text("Interaction data: \(env.interactionSourceName)")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
        .navigationTitle(copy.flagsSectionTitle)
    }
}
