import WidgetKit
import SwiftUI

private let appGroupId = "group.com.arisair.planfit"
private let widgetSnapshotKey = "widget_snapshot"

private struct Todo: Identifiable {
  let id: String
  let title: String
  let done: Bool
}

private struct Entry: TimelineEntry {
  let date: Date
  let title: String
  let time: String
  let progress: String
  let todos: [Todo]
  let deepLink: URL?
}

private func snapshot() -> [String: Any] {
  guard let raw = UserDefaults(suiteName: appGroupId)?.string(forKey: widgetSnapshotKey),
        let data = raw.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  else { return [:] }
  return object
}

private struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry {
    Entry(date: Date(), title: "예정된 일정이 없어요", time: "", progress: "0/0", todos: [], deepLink: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(current())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(1800))))
  }

  private func current() -> Entry {
    let data = snapshot()
    func string(_ key: String, _ fallback: String = "") -> String { data[key] as? String ?? fallback }
    var todos: [Todo] = []
    for index in 0..<2 {
      let id = string("todo\(index)_id")
      let title = string("todo\(index)_title")
      guard !id.isEmpty, !title.isEmpty else { break }
      todos.append(Todo(id: id, title: title, done: data["todo\(index)_done"] as? Bool ?? false))
    }
    let eventUri = string("event0_uri")
    let todosUri = string("todos_uri")
    return Entry(
      date: Date(),
      title: string("event0_title", "예정된 일정이 없어요"),
      time: string("event0_time"),
      progress: string("todos_progress", "0/0"),
      todos: todos,
      deepLink: URL(string: eventUri.isEmpty ? todosUri : eventUri)
    )
  }
}

private struct WidgetView: View {
  let entry: Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("다가오는 일정").font(.caption2).foregroundStyle(.secondary)
      HStack {
        Text(entry.title).font(.headline).lineLimit(1)
        if !entry.time.isEmpty { Spacer(); Text(entry.time).font(.subheadline.bold()) }
      }
      Spacer()
      HStack {
        Text("오늘의 할 일").font(.caption2).foregroundStyle(.secondary)
        Spacer(); Text(entry.progress).font(.caption2).foregroundStyle(.secondary)
      }
      if entry.todos.isEmpty {
        Text("할 일이 없어요").font(.subheadline).foregroundStyle(.secondary)
      } else {
        ForEach(entry.todos) { todo in
          HStack(spacing: 6) {
            Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(todo.done ? .blue : .secondary)
            Text(todo.title).font(.footnote).lineLimit(1).strikethrough(todo.done)
          }
        }
      }
    }
    .padding()
    .containerBackground(for: .widget) { Color(.systemBackground) }
    .widgetURL(entry.deepLink)
  }
}

struct PlanFitWidget: Widget {
  let kind = "PlanFitWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      WidgetView(entry: entry)
    }
    .configurationDisplayName("PlanFit")
    .description("다가오는 일정과 오늘의 할 일을 홈 화면에서 확인하세요")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
