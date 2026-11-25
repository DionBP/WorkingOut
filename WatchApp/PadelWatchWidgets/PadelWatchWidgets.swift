import SwiftUI
import WidgetKit

@main
struct WorkingOutWatchWidgetsBundle: WidgetBundle {
    var body: some Widget { TrainingComplication() }
}

private struct TrainingComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PadelScoreLauncher", provider: LauncherProvider()) { _ in
            LauncherView()
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Open WorkingOut")
        .description("Open your WorkingOut training programs.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

private struct LauncherProvider: TimelineProvider {
    struct Entry: TimelineEntry { let date: Date }

    func placeholder(in context: Context) -> Entry { Entry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

private struct LauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline, .accessoryRectangular:
            Label("Training", systemImage: "dumbbell.fill")
        case .accessoryCorner:
            Image(systemName: "dumbbell.fill").widgetLabel("Training")
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "dumbbell.fill").font(.system(size: 22, weight: .semibold))
            }
        }
    }
}
