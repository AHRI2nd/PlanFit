/// How far ahead of "now" a notification actually gets scheduled — both when
/// an event is first saved ([EventRepositoryImpl]) and when
/// [CalendarReconciler] refills notifications for events that have since
/// rolled inside the window. Exists because iOS caps an app to roughly 64
/// pending local notifications: scheduling every occurrence of e.g. a
/// 200-row daily recurring series at creation time would blow straight
/// through that and silently drop far-future alerts. Staying inside a near
/// window keeps the pending count bounded regardless of how far out events
/// are created, at the cost of only scheduling the rest once they're closer.
const Duration notificationSchedulingWindow = Duration(days: 60);
