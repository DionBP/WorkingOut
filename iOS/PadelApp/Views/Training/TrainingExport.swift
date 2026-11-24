import SwiftUI
import UniformTypeIdentifiers
import WorkingOutKit

struct TrainingExport: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    private let data: Data

    init(log: StrengthLog) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(Archive(
            strength: log.history, runs: log.runs ?? [],
            programs: log.programs ?? [], customExercises: log.customExercises ?? []
        ))
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    private struct Archive: Encodable {
        let schemaVersion = 1
        let strength: [StrengthSession]
        let runs: [RunRecord]
        let programs: [StrengthProgram]
        let customExercises: [CustomExercise]
    }
}
