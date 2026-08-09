import AppIntents
import WidgetKit
import SwiftUI

// Not wired into the Xcode project yet — this is the ready-made source for
// the WidgetKit Extension target described in docs/PROGRESS.md. Once that
// target exists (created via Xcode > File > New > Target > Widget
// Extension, named "PlanFitWidget"), replace its generated Swift file with
// this one's contents. The to-do checkboxes below also need
// BackgroundIntent.swift (same folder) added to the project — see its own
// doc comment for the extra dual-target-membership step that one needs.
//
// Reads the same keys `HomeWidgetSync` (lib/core/home_widget/home_widget_sync.dart)
// writes on the Flutter side, via the shared App Group's UserDefaults suite.

private let appGroupId = "group.com.arisair.planfit"

// One row of HomeWidgetSync's `todo{i}_id`/`todo{i}_title`/`todo{i}_done`.
struct PlanFitWidgetTodo: Identifiable {
    let id: String
    let title: String
    let done: Bool
}

struct PlanFitWidgetEntry: TimelineEntry {
    let date: Date
    let nextEventTitle: String
    let nextEventTime: String
    let todosProgress: String
    // Only 2 shown — .systemSmall/.systemMedium (this widget's only
    // supported families) don't have room for more, same reasoning as
    // Android's compact layout in PlanFitWidgetProvider.kt.
    let todos: [PlanFitWidgetTodo]
    // Whole-widget tap target — prefers the next event's day, falling back
    // to today (the to-do progress's day) when there's no event. A true
    // per-section tap target needs iOS 17 Link()/App Intents; not worth the
    // extra setup for the event/progress fields, unlike the to-dos below
    // where per-row interactivity is the whole point.
    let deepLinkUri: URL?
}

struct PlanFitWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlanFitWidgetEntry {
        PlanFitWidgetEntry(
            date: Date(),
            nextEventTitle: "다가오는 일정",
            nextEventTime: "09:00",
            todosProgress: "0/0",
            todos: [],
            deepLinkUri: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PlanFitWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlanFitWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // The Flutter side pushes a fresh value on every relevant data change
        // and on foreground resume — a short-lived timeline just keeps the
        // system from ever showing very stale data if a push was missed.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> PlanFitWidgetEntry {
        // Only the first of HomeWidgetSync.maxEvents pushed events is used —
        // the iOS widget stays single-event, unlike Android's expanded
        // large-size layout (see PlanFitWidgetProvider.kt).
        let defaults = UserDefaults(suiteName: appGroupId)
        let title = defaults?.string(forKey: "event0_title") ?? ""
        let eventUri = defaults?.string(forKey: "event0_uri") ?? ""
        let todosUri = defaults?.string(forKey: "todos_uri") ?? ""
        let linkString = eventUri.isEmpty ? todosUri : eventUri

        var todos: [PlanFitWidgetTodo] = []
        for i in 0..<2 {
            let id = defaults?.string(forKey: "todo\(i)_id") ?? ""
            let todoTitle = defaults?.string(forKey: "todo\(i)_title") ?? ""
            if id.isEmpty || todoTitle.isEmpty { break }
            todos.append(
                PlanFitWidgetTodo(
                    id: id,
                    title: todoTitle,
                    done: defaults?.bool(forKey: "todo\(i)_done") ?? false
                )
            )
        }

        return PlanFitWidgetEntry(
            date: Date(),
            nextEventTitle: title.isEmpty ? "예정된 일정이 없어요" : title,
            nextEventTime: defaults?.string(forKey: "event0_time") ?? "",
            todosProgress: defaults?.string(forKey: "todos_progress") ?? "0/0",
            todos: todos,
            deepLinkUri: linkString.isEmpty ? nil : URL(string: linkString)
        )
    }
}

struct PlanFitWidgetView: View {
    var entry: PlanFitWidgetProvider.Entry
    @Environment(\.colorScheme) private var colorScheme

    // Text already uses SwiftUI's adaptive .primary/.secondary, so the
    // background is the only hardcoded color that needs a dark variant —
    // mirrors AppPalette.light/dark's surface tokens.
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.086, green: 0.102, blue: 0.133) // ink800
            : Color(red: 0.96, green: 0.95, blue: 0.93) // softPaper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("다가오는 일정")
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack {
                Text(entry.nextEventTitle)
                    .font(.headline)
                    .lineLimit(1)
                if !entry.nextEventTime.isEmpty {
                    Spacer()
                    Text(entry.nextEventTime)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(red: 0.29, green: 0.37, blue: 0.84)) // dawnIndigo
                }
            }
            Spacer()
            HStack {
                Text("오늘의 할 일")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.todosProgress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if entry.todos.isEmpty {
                Text("할 일이 없어요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.todos) { todo in
                    todoRow(todo)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            backgroundColor
        }
        .widgetURL(entry.deepLinkUri)
    }

    // Checkable right from the widget on iOS 17+ (via PlanFitBackgroundIntent
    // — see BackgroundIntent.swift). Below that, to-dos still show but as
    // plain read-only rows: pre-17 widgets can't run App Intents, and a
    // dead checkbox would be worse than none — .widgetURL above already
    // covers "just open the app" as the fallback interaction.
    @ViewBuilder
    private func todoRow(_ todo: PlanFitWidgetTodo) -> some View {
        if #available(iOSApplicationExtension 17, *) {
            Button(
                intent: PlanFitBackgroundIntent(
                    url: URL(string: "planfit://toggle-todo?id=\(todo.id)"),
                    appGroup: appGroupId
                )
            ) {
                todoRowLabel(todo)
            }
            .buttonStyle(.plain)
        } else {
            todoRowLabel(todo)
        }
    }

    private func todoRowLabel(_ todo: PlanFitWidgetTodo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(todo.done ? Color(red: 0.29, green: 0.37, blue: 0.84) : .secondary) // dawnIndigo
            Text(todo.title)
                .font(.footnote)
                .lineLimit(1)
                .strikethrough(todo.done)
                .foregroundColor(todo.done ? .secondary : .primary)
        }
    }
}

struct PlanFitWidget: Widget {
    let kind: String = "PlanFitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlanFitWidgetProvider()) { entry in
            PlanFitWidgetView(entry: entry)
        }
        .configurationDisplayName("PlanFit")
        .description("다가오는 일정과 오늘의 할 일을 홈 화면에서 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PlanFitWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlanFitWidget()
    }
}
