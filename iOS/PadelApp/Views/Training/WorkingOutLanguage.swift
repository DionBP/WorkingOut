import SwiftUI
import WorkingOutKit

enum WorkingOutLanguage: String, CaseIterable, Identifiable {
    case system, da, en

    var id: Self { self }

    var resolved: String {
        if self != .system { return rawValue }
        return Bundle.main.preferredLocalizations.first == "da" ? "da" : "en"
    }

    func text(_ key: String) -> String {
        let bundle = Bundle.main.path(forResource: resolved, ofType: "lproj").flatMap { Bundle(path: $0) }
        let fallback = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap { Bundle(path: $0) }
        let english = fallback?.localizedString(forKey: key, value: key, table: "WorkingOut") ?? key
        return bundle?.localizedString(forKey: key, value: english, table: "WorkingOut") ?? english
    }
}

struct TrainingPresentation {
    let language: WorkingOutLanguage
    let weight: WeightUnit
    let distance: DistanceUnit
    let locale: Locale

    func text(_ key: String) -> String { language.text(key) }

    func name(_ exercise: StrengthExercise, custom: [CustomExercise]) -> String {
        if let customName = exercise.customName?.trimmingCharacters(in: .whitespacesAndNewlines), !customName.isEmpty {
            return customName
        }
        if let id = exercise.exerciseID {
            if let definition = ExerciseCatalog.byID[id] { return exerciseTitle(definition) }
            if let definition = custom.first(where: { $0.id == id }) { return definition.name }
        }
        return exercise.name
    }

    func exerciseTitle(_ definition: ExerciseDefinition) -> String {
        if ExerciseCatalog.builtinIDs.contains(definition.id) { return text(definition.titleKey) }
        guard let imported = ExerciseCatalog.imported[definition.id] else { return definition.id }
        return language.resolved == "da" ? (imported.danish?.name ?? imported.name) : imported.name
    }

    func exerciseMatches(_ definition: ExerciseDefinition, search: String) -> Bool {
        guard !search.isEmpty else { return true }
        let imported = ExerciseCatalog.imported[definition.id]
        let names: [String?] = [
            exerciseTitle(definition), imported?.name, imported?.danish?.name,
            ExerciseCatalog.builtinIDs.contains(definition.id) ? WorkingOutLanguage.da.text(definition.titleKey) : nil,
            ExerciseCatalog.builtinIDs.contains(definition.id) ? WorkingOutLanguage.en.text(definition.titleKey) : nil
        ]
        return names.compactMap { $0 }.contains { $0.localizedStandardContains(search) }
    }

    func number(_ value: Double, precision: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...precision)).locale(locale))
    }

    func weightText(_ kg: Double) -> String { "\(number(weight.display(kg))) \(weight.rawValue)" }
    func distanceText(_ meters: Double) -> String { "\(number(distance.display(meters), precision: 2)) \(distance.rawValue)" }

    func compactDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "—" }
        let units: Set<Duration.UnitsFormatStyle.Unit> = seconds < 60 ? [.seconds] : [.hours, .minutes]
        return Duration.seconds(Int(seconds)).formatted(
            .units(allowed: units, width: .narrow, maximumUnitCount: 2).locale(locale)
        )
    }

    func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "—" }
        let total = Int(seconds)
        return Duration.seconds(total).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated).locale(locale))
    }
}
