import Foundation

struct ImportedExercise: Decodable {
    struct Translation: Decodable {
        let name: String
        let instructions: [String]
    }

    let id: String
    let name: String
    let instructions: [String]
    let primary: [String]
    let secondary: [String]
    let equipment: String
    let danish: Translation?
}

struct ExerciseSnapshot: Decodable {
    struct Media: Decodable {
        let revision: String
        let exercises: [String: String]

        func illustration(for id: String) -> URL? {
            guard let slug = exercises[id] else { return nil }
            let pose = slug == "plank" ? "main" : "start"
            return URL(string: "https://raw.githubusercontent.com/RepDB/exercise-dataset/\(revision)/images/flat/\(slug)-\(pose).webp")
        }
    }

    let schema: Int
    let exercises: [ImportedExercise]
    let media: Media?

    static let bundled: ExerciseSnapshot = {
        let empty = ExerciseSnapshot(schema: 1, exercises: [], media: nil)
        guard let url = Bundle.main.url(forResource: "ExerciseSnapshot", withExtension: "json"),
              let bytes = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(ExerciseSnapshot.self, from: bytes),
              snapshot.schema == 1,
              Set(snapshot.exercises.map(\.id)).count == snapshot.exercises.count else { return empty }
        return snapshot
    }()
}
