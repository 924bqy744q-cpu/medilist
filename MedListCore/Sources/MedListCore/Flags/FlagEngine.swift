import Foundation

public enum FlagKind: String, Codable, Sendable {
    case duplicateIngredient
    case interaction
}

/// Something on the list a pharmacist should look at. Flags describe; they never instruct.
public struct MedicationFlag: Identifiable, Equatable, Sendable {
    public let kind: FlagKind
    public let medicationIDs: [UUID]
    public let medicationNames: [String]
    public let ingredients: [String]
    public let interaction: InteractionRecord?

    public var id: String {
        ([kind.rawValue] + ingredients + medicationIDs.map(\.uuidString).sorted()).joined(separator: "|")
    }
}

/// Finds medications on the list that share an active ingredient (e.g. brand + generic of the same drug).
public enum DuplicateDetector {
    public static func duplicates(in meds: [MedicationSnapshot]) -> [MedicationFlag] {
        var byIngredient: [String: [MedicationSnapshot]] = [:]
        for med in meds {
            for ingredient in Set(med.ingredients) {
                byIngredient[ingredient, default: []].append(med)
            }
        }

        // Group ingredients shared by exactly the same set of medications into one flag.
        var groups: [[UUID]: (meds: [MedicationSnapshot], ingredients: [String])] = [:]
        for (ingredient, holders) in byIngredient where Set(holders.map(\.id)).count > 1 {
            let key = holders.map(\.id).sorted { $0.uuidString < $1.uuidString }
            groups[key, default: (holders, [])].ingredients.append(ingredient)
        }

        return groups.values
            .map { group in
                MedicationFlag(
                    kind: .duplicateIngredient,
                    medicationIDs: group.meds.map(\.id),
                    medicationNames: group.meds.map(\.name),
                    ingredients: group.ingredients.sorted(),
                    interaction: nil)
            }
            .sorted { $0.ingredients.joined() < $1.ingredients.joined() }
    }
}

public struct FlagResult: Equatable, Sendable {
    public var flags: [MedicationFlag]
    /// True when the interaction source could not be queried; the UI says so instead of implying "no interactions".
    public var interactionCheckFailed: Bool
    /// Medications whose name could not be matched to an ingredient, so checks for them are weaker.
    public var unresolvedMedicationIDs: [UUID]
}

public struct FlagEngine: Sendable {
    let interactions: InteractionProvider

    public init(interactions: InteractionProvider) {
        self.interactions = interactions
    }

    public func evaluate(_ meds: [MedicationSnapshot]) async -> FlagResult {
        var flags = DuplicateDetector.duplicates(in: meds)
        var failed = false

        let allIngredients = Set(meds.flatMap(\.ingredients))
        do {
            let records = try await interactions.interactions(among: allIngredients)
            for record in records {
                let withA = meds.filter { $0.ingredients.contains(record.ingredientA) }
                let withB = meds.filter { $0.ingredients.contains(record.ingredientB) }
                // Needs two different medications; a combination product is not flagged against itself.
                guard withA.contains(where: { a in withB.contains { $0.id != a.id } }) else { continue }
                let involved = meds.filter { med in withA.contains { $0.id == med.id } || withB.contains { $0.id == med.id } }
                flags.append(MedicationFlag(
                    kind: .interaction,
                    medicationIDs: involved.map(\.id),
                    medicationNames: involved.map(\.name),
                    ingredients: [record.ingredientA, record.ingredientB],
                    interaction: record))
            }
        } catch {
            failed = true
        }

        return FlagResult(
            flags: flags,
            interactionCheckFailed: failed,
            unresolvedMedicationIDs: meds.filter { $0.ingredientSource == .unresolved }.map(\.id))
    }
}
