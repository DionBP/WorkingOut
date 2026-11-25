import Foundation

struct ExerciseDefinition: Identifiable {
    let id: String
    let primary: String
    let secondary: String
    let equipment: String
    let movement: String
    let legacyName: String?

    var titleKey: String { "exercise." + id }
    var instructionKey: String { "movement." + movement }

    var primaryGroups: [String] { ExerciseCatalog.imported[id]?.primary ?? [primary] }
    var secondaryGroups: [String] { ExerciseCatalog.imported[id]?.secondary ?? (secondary == "none" ? [] : [secondary]) }
}

enum ExerciseCatalog {
    private static let builtin: [ExerciseDefinition] = [
        .init(id: "bench-press", primary: "chest", secondary: "triceps", equipment: "barbell", movement: "press", legacyName: "Bench Press"),
        .init(id: "incline-barbell-press", primary: "chest", secondary: "shoulders", equipment: "barbell", movement: "press", legacyName: nil),
        .init(id: "decline-bench-press", primary: "chest", secondary: "triceps", equipment: "barbell", movement: "press", legacyName: nil),
        .init(id: "incline-dumbbell-press", primary: "chest", secondary: "shoulders", equipment: "dumbbells", movement: "press", legacyName: "Incline Dumbbell Press"),
        .init(id: "dumbbell-bench-press", primary: "chest", secondary: "triceps", equipment: "dumbbells", movement: "press", legacyName: nil),
        .init(id: "dumbbell-floor-press", primary: "chest", secondary: "triceps", equipment: "dumbbells", movement: "press", legacyName: nil),
        .init(id: "push-up", primary: "chest", secondary: "triceps", equipment: "bodyweight", movement: "press", legacyName: "Push-up"),
        .init(id: "decline-push-up", primary: "chest", secondary: "triceps", equipment: "bodyweight", movement: "press", legacyName: nil),
        .init(id: "incline-push-up", primary: "chest", secondary: "triceps", equipment: "bodyweight", movement: "press", legacyName: nil),
        .init(id: "chest-dip", primary: "chest", secondary: "triceps", equipment: "bodyweight", movement: "press", legacyName: nil),
        .init(id: "dumbbell-fly", primary: "chest", secondary: "shoulders", equipment: "dumbbells", movement: "fly", legacyName: "Dumbbell Fly"),
        .init(id: "cable-crossover", primary: "chest", secondary: "shoulders", equipment: "cable", movement: "fly", legacyName: nil),
        .init(id: "pec-deck", primary: "chest", secondary: "shoulders", equipment: "machine", movement: "fly", legacyName: nil),
        .init(id: "chest-press", primary: "chest", secondary: "triceps", equipment: "machine", movement: "press", legacyName: "Chest Press"),
        .init(id: "overhead-press", primary: "shoulders", secondary: "triceps", equipment: "barbell", movement: "press", legacyName: "Overhead Press"),
        .init(id: "dumbbell-shoulder-press", primary: "shoulders", secondary: "triceps", equipment: "dumbbells", movement: "press", legacyName: nil),
        .init(id: "arnold-press", primary: "shoulders", secondary: "triceps", equipment: "dumbbells", movement: "press", legacyName: nil),
        .init(id: "machine-shoulder-press", primary: "shoulders", secondary: "triceps", equipment: "machine", movement: "press", legacyName: nil),
        .init(id: "landmine-press", primary: "shoulders", secondary: "core", equipment: "barbell", movement: "press", legacyName: nil),
        .init(id: "lateral-raise", primary: "shoulders", secondary: "traps", equipment: "dumbbells", movement: "raise", legacyName: "Lateral Raise"),
        .init(id: "cable-lateral-raise", primary: "shoulders", secondary: "traps", equipment: "cable", movement: "raise", legacyName: nil),
        .init(id: "front-raise", primary: "shoulders", secondary: "traps", equipment: "dumbbells", movement: "raise", legacyName: nil),
        .init(id: "rear-delt-fly", primary: "shoulders", secondary: "back", equipment: "dumbbells", movement: "fly", legacyName: nil),
        .init(id: "reverse-pec-deck", primary: "shoulders", secondary: "back", equipment: "machine", movement: "fly", legacyName: nil),
        .init(id: "face-pull", primary: "shoulders", secondary: "back", equipment: "cable", movement: "row", legacyName: "Face Pull"),
        .init(id: "barbell-shrug", primary: "traps", secondary: "forearms", equipment: "barbell", movement: "raise", legacyName: nil),
        .init(id: "dumbbell-shrug", primary: "traps", secondary: "forearms", equipment: "dumbbells", movement: "raise", legacyName: nil),
        .init(id: "pull-up", primary: "back", secondary: "biceps", equipment: "bodyweight", movement: "pull", legacyName: "Pull-up"),
        .init(id: "chin-up", primary: "back", secondary: "biceps", equipment: "bodyweight", movement: "pull", legacyName: nil),
        .init(id: "assisted-pull-up", primary: "back", secondary: "biceps", equipment: "machine", movement: "pull", legacyName: nil),
        .init(id: "lat-pulldown", primary: "back", secondary: "biceps", equipment: "cable", movement: "pull", legacyName: "Lat Pulldown"),
        .init(id: "close-grip-pulldown", primary: "back", secondary: "biceps", equipment: "cable", movement: "pull", legacyName: nil),
        .init(id: "straight-arm-pulldown", primary: "back", secondary: "shoulders", equipment: "cable", movement: "pull", legacyName: nil),
        .init(id: "barbell-row", primary: "back", secondary: "biceps", equipment: "barbell", movement: "row", legacyName: "Barbell Row"),
        .init(id: "pendlay-row", primary: "back", secondary: "biceps", equipment: "barbell", movement: "row", legacyName: nil),
        .init(id: "single-arm-dumbbell-row", primary: "back", secondary: "biceps", equipment: "dumbbells", movement: "row", legacyName: nil),
        .init(id: "chest-supported-dumbbell-row", primary: "back", secondary: "biceps", equipment: "dumbbells", movement: "row", legacyName: nil),
        .init(id: "seated-cable-row", primary: "back", secondary: "biceps", equipment: "cable", movement: "row", legacyName: "Seated Cable Row"),
        .init(id: "machine-row", primary: "back", secondary: "biceps", equipment: "machine", movement: "row", legacyName: nil),
        .init(id: "inverted-row", primary: "back", secondary: "biceps", equipment: "bodyweight", movement: "row", legacyName: nil),
        .init(id: "t-bar-row", primary: "back", secondary: "core", equipment: "barbell", movement: "row", legacyName: nil),
        .init(id: "biceps-curl", primary: "biceps", secondary: "forearms", equipment: "dumbbells", movement: "curl", legacyName: "Biceps Curl"),
        .init(id: "hammer-curl", primary: "biceps", secondary: "forearms", equipment: "dumbbells", movement: "curl", legacyName: "Hammer Curl"),
        .init(id: "barbell-curl", primary: "biceps", secondary: "forearms", equipment: "barbell", movement: "curl", legacyName: nil),
        .init(id: "preacher-curl", primary: "biceps", secondary: "forearms", equipment: "barbell", movement: "curl", legacyName: "Preacher Curl"),
        .init(id: "incline-dumbbell-curl", primary: "biceps", secondary: "forearms", equipment: "dumbbells", movement: "curl", legacyName: nil),
        .init(id: "concentration-curl", primary: "biceps", secondary: "forearms", equipment: "dumbbells", movement: "curl", legacyName: nil),
        .init(id: "cable-curl", primary: "biceps", secondary: "forearms", equipment: "cable", movement: "curl", legacyName: nil),
        .init(id: "reverse-curl", primary: "forearms", secondary: "biceps", equipment: "barbell", movement: "curl", legacyName: nil),
        .init(id: "wrist-curl", primary: "forearms", secondary: "none", equipment: "dumbbells", movement: "curl", legacyName: nil),
        .init(id: "triceps-pushdown", primary: "triceps", secondary: "none", equipment: "cable", movement: "extend", legacyName: "Triceps Pushdown"),
        .init(id: "overhead-cable-extension", primary: "triceps", secondary: "none", equipment: "cable", movement: "extend", legacyName: nil),
        .init(id: "dumbbell-triceps-extension", primary: "triceps", secondary: "none", equipment: "dumbbells", movement: "extend", legacyName: nil),
        .init(id: "skull-crusher", primary: "triceps", secondary: "none", equipment: "barbell", movement: "extend", legacyName: nil),
        .init(id: "close-grip-bench-press", primary: "triceps", secondary: "chest", equipment: "barbell", movement: "press", legacyName: nil),
        .init(id: "bench-dip", primary: "triceps", secondary: "chest", equipment: "bodyweight", movement: "press", legacyName: nil),
        .init(id: "triceps-kickback", primary: "triceps", secondary: "none", equipment: "dumbbells", movement: "extend", legacyName: nil),
        .init(id: "squat", primary: "quads", secondary: "glutes", equipment: "barbell", movement: "squat", legacyName: "Squat"),
        .init(id: "front-squat", primary: "quads", secondary: "core", equipment: "barbell", movement: "squat", legacyName: nil),
        .init(id: "goblet-squat", primary: "quads", secondary: "glutes", equipment: "dumbbells", movement: "squat", legacyName: "Goblet Squat"),
        .init(id: "bodyweight-squat", primary: "quads", secondary: "glutes", equipment: "bodyweight", movement: "squat", legacyName: nil),
        .init(id: "hack-squat", primary: "quads", secondary: "glutes", equipment: "machine", movement: "squat", legacyName: nil),
        .init(id: "leg-press", primary: "quads", secondary: "glutes", equipment: "machine", movement: "squat", legacyName: "Leg Press"),
        .init(id: "leg-extension", primary: "quads", secondary: "none", equipment: "machine", movement: "extend", legacyName: "Leg Extension"),
        .init(id: "bulgarian-split-squat", primary: "quads", secondary: "glutes", equipment: "dumbbells", movement: "lunge", legacyName: "Bulgarian Split Squat"),
        .init(id: "lunge", primary: "quads", secondary: "glutes", equipment: "bodyweight", movement: "lunge", legacyName: "Lunge"),
        .init(id: "reverse-lunge", primary: "quads", secondary: "glutes", equipment: "dumbbells", movement: "lunge", legacyName: nil),
        .init(id: "walking-lunge", primary: "quads", secondary: "glutes", equipment: "dumbbells", movement: "lunge", legacyName: nil),
        .init(id: "step-up", primary: "quads", secondary: "glutes", equipment: "dumbbells", movement: "step", legacyName: nil),
        .init(id: "romanian-deadlift", primary: "hamstrings", secondary: "glutes", equipment: "barbell", movement: "hinge", legacyName: "Romanian Deadlift"),
        .init(id: "deadlift", primary: "glutes", secondary: "back", equipment: "barbell", movement: "hinge", legacyName: "Deadlift"),
        .init(id: "sumo-deadlift", primary: "glutes", secondary: "quads", equipment: "barbell", movement: "hinge", legacyName: nil),
        .init(id: "good-morning", primary: "glutes", secondary: "hamstrings", equipment: "barbell", movement: "hinge", legacyName: nil),
        .init(id: "single-leg-deadlift", primary: "hamstrings", secondary: "glutes", equipment: "dumbbells", movement: "hinge", legacyName: nil),
        .init(id: "leg-curl", primary: "hamstrings", secondary: "none", equipment: "machine", movement: "curl", legacyName: "Leg Curl"),
        .init(id: "seated-leg-curl", primary: "hamstrings", secondary: "none", equipment: "machine", movement: "curl", legacyName: nil),
        .init(id: "nordic-curl", primary: "hamstrings", secondary: "core", equipment: "bodyweight", movement: "curl", legacyName: nil),
        .init(id: "hip-thrust", primary: "glutes", secondary: "hamstrings", equipment: "barbell", movement: "bridge", legacyName: "Hip Thrust"),
        .init(id: "glute-bridge", primary: "glutes", secondary: "hamstrings", equipment: "bodyweight", movement: "bridge", legacyName: nil),
        .init(id: "single-leg-glute-bridge", primary: "glutes", secondary: "hamstrings", equipment: "bodyweight", movement: "bridge", legacyName: nil),
        .init(id: "hip-abduction", primary: "glutes", secondary: "none", equipment: "machine", movement: "extend", legacyName: nil),
        .init(id: "hip-adduction", primary: "adductors", secondary: "none", equipment: "machine", movement: "extend", legacyName: nil),
        .init(id: "cable-glute-kickback", primary: "glutes", secondary: "hamstrings", equipment: "cable", movement: "extend", legacyName: nil),
        .init(id: "calf-raise", primary: "calves", secondary: "none", equipment: "bodyweight", movement: "raise", legacyName: "Calf Raise"),
        .init(id: "seated-calf-raise", primary: "calves", secondary: "none", equipment: "machine", movement: "raise", legacyName: nil),
        .init(id: "leg-press-calf-raise", primary: "calves", secondary: "none", equipment: "machine", movement: "raise", legacyName: nil),
        .init(id: "single-leg-calf-raise", primary: "calves", secondary: "none", equipment: "dumbbells", movement: "raise", legacyName: nil),
        .init(id: "plank", primary: "core", secondary: "shoulders", equipment: "bodyweight", movement: "hold", legacyName: "Plank"),
        .init(id: "side-plank", primary: "core", secondary: "glutes", equipment: "bodyweight", movement: "hold", legacyName: nil),
        .init(id: "hollow-hold", primary: "core", secondary: "none", equipment: "bodyweight", movement: "hold", legacyName: nil),
        .init(id: "crunch", primary: "core", secondary: "none", equipment: "bodyweight", movement: "crunch", legacyName: nil),
        .init(id: "cable-crunch", primary: "core", secondary: "none", equipment: "cable", movement: "crunch", legacyName: "Cable Crunch"),
        .init(id: "reverse-crunch", primary: "core", secondary: "none", equipment: "bodyweight", movement: "crunch", legacyName: nil),
        .init(id: "hanging-knee-raise", primary: "core", secondary: "forearms", equipment: "bodyweight", movement: "raise", legacyName: nil),
        .init(id: "hanging-leg-raise", primary: "core", secondary: "forearms", equipment: "bodyweight", movement: "raise", legacyName: nil),
        .init(id: "dead-bug", primary: "core", secondary: "none", equipment: "bodyweight", movement: "stability", legacyName: nil),
        .init(id: "bird-dog", primary: "core", secondary: "glutes", equipment: "bodyweight", movement: "stability", legacyName: nil),
        .init(id: "pallof-press", primary: "core", secondary: "shoulders", equipment: "cable", movement: "stability", legacyName: nil),
        .init(id: "cable-wood-chop", primary: "core", secondary: "shoulders", equipment: "cable", movement: "stability", legacyName: nil),
        .init(id: "back-extension", primary: "back", secondary: "glutes", equipment: "bodyweight", movement: "hinge", legacyName: "Back Extension"),
        .init(id: "farmer-carry", primary: "forearms", secondary: "core", equipment: "dumbbells", movement: "carry", legacyName: nil),
        .init(id: "suitcase-carry", primary: "core", secondary: "forearms", equipment: "dumbbells", movement: "carry", legacyName: nil),
        .init(id: "kettlebell-swing", primary: "glutes", secondary: "hamstrings", equipment: "kettlebell", movement: "hinge", legacyName: nil),
        .init(id: "dumbbell-thruster", primary: "quads", secondary: "shoulders", equipment: "dumbbells", movement: "press", legacyName: nil),
        .init(id: "lateral-lunge", primary: "glutes", secondary: "adductors", equipment: "bodyweight", movement: "lunge", legacyName: nil),
    ]
    static let imported = Dictionary(uniqueKeysWithValues: ExerciseSnapshot.bundled.exercises.map { ($0.id, $0) })
    static let builtinIDs = Set(builtin.map(\.id))
    static let entries = builtin + ExerciseSnapshot.bundled.exercises.filter { !builtinIDs.contains($0.id) }.map {
        ExerciseDefinition(id: $0.id, primary: $0.primary.first ?? "core", secondary: $0.secondary.first ?? "none",
                           equipment: $0.equipment, movement: "", legacyName: nil)
    }
    static let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    static let legacyIDs = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
        entry.legacyName.map { ($0, entry.id) }
    })
}
