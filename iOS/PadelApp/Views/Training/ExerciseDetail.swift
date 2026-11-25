import SwiftUI
import UIKit
import WorkingOutKit

struct ExerciseDetail: View {
    var item: ExerciseDefinition
    var display: TrainingPresentation
    let select: (WorkingOutKit.StrengthExercise) -> Void

    var body: some View {
        Form {
            Button(display.text("addExercise"), systemImage: "plus.circle") {
                select(.init(name: display.exerciseTitle(item), exerciseID: item.id))
            }
            if let image = ExerciseSnapshot.bundled.media?.illustration(for: item.id) {
                Section {
                    ExerciseIllustration(url: image, label: display.text("exerciseIllustration"))
                    Link(display.text("repdbCredit"), destination: URL(string: "https://repdb.co")!)
                }
            }
            Section {
                if !item.primaryGroups.isEmpty {
                    LabeledContent(display.text("primaryMuscle"), value: groups(item.primaryGroups))
                }
                if !item.secondaryGroups.isEmpty {
                    LabeledContent(display.text("secondaryMuscle"), value: groups(item.secondaryGroups))
                }
                LabeledContent(display.text("equipment"), value: display.text("equipment." + item.equipment))
            }
            if let imported = ExerciseCatalog.imported[item.id] {
                let danish = display.language.resolved == "da"
                let translated = danish ? imported.danish?.instructions : nil
                Section(display.text(danish && translated == nil ? "englishExerciseFallback" : "instructions")) {
                    let steps = translated ?? imported.instructions
                    if steps.isEmpty { Text(display.text("instructionsUnavailable")) }
                    ForEach(steps.indices, id: \.self) { index in Text(steps[index]) }
                }
            } else {
                Section(display.text("instructions")) { Text(display.text(item.instructionKey)) }
            }
        }
        .navigationTitle(display.exerciseTitle(item))
    }

    private func groups(_ values: [String]) -> String {
        values.map { display.text("muscle." + $0) }.formatted(.list(type: .and).locale(display.locale))
    }
}

private struct ExerciseIllustration: View {
    let url: URL
    let label: String
    @State private var picture: UIImage?

    var body: some View {
        Group {
            if let picture {
                Image(uiImage: picture).resizable().scaledToFit().frame(maxHeight: 250)
                    .accessibilityLabel(label)
            }
        }
        .task(id: url) {
            picture = nil
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let session = ExerciseImageCache.session
            if let data = session.configuration.urlCache?.cachedResponse(for: request)?.data,
               let cached = UIImage(data: data) {
                picture = cached
                return
            }
            if let (bytes, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200, bytes.count < 1_000_000,
               let decoded = UIImage(data: bytes), !Task.isCancelled {
                session.configuration.urlCache?.storeCachedResponse(
                    CachedURLResponse(response: response, data: bytes, storagePolicy: .allowed), for: request
                )
                picture = decoded
            }
        }
    }
}

private enum ExerciseImageCache {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 4_000_000, diskCapacity: 16_000_000, diskPath: "WorkingOutExerciseImages")
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()
}
