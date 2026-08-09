package com.arisair.planfit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetBackgroundWorker
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

// Renders the values PlanFit pushes via `HomeWidgetSync` (see
// lib/core/home_widget/home_widget_sync.dart) into the HomeScreen widget
// registered in res/xml/home_widget_info.xml.
//
// Android has no iOS-style widget size "family" — instead a single widget
// provider is resized freely by the user and reports its current size via
// getAppWidgetOptions. Below EXPANDED_MIN_HEIGHT_DP we render the compact
// one-event layout; at or above it, the expanded layout with up to
// HomeWidgetSync.maxEvents events. See Android's own "responsive widget"
// guidance — this is the standard pattern for it.
class PlanFitWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val EXPANDED_MIN_HEIGHT_DP = 180
        private const val MAX_EVENTS = 3

        // Matches HomeWidgetSync.maxWidgetTodos on the Dart side — the
        // compact layout only has room to actually show the first 2 of them.
        private const val MAX_TODOS = 3

        private const val LAST_BG_REFRESH_KEY = "widget_last_bg_refresh"

        // Just under home_widget_info.xml's own updatePeriodMillis (30 min) —
        // see maybeRefreshWidgetData's doc for why this exists at all.
        private const val MIN_BG_REFRESH_INTERVAL_MS = 25L * 60 * 1000
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            render(context, appWidgetManager, widgetId, widgetData)
        }
        maybeRefreshWidgetData(context, widgetData)
    }

    // onUpdate() only ever repaints whatever is already sitting in
    // widgetData (a plain SharedPreferences read — this class has no DB
    // access of its own), and that snapshot is only ever written by the app
    // foregrounding or a to-do checkbox tap (see HomeWidgetSync.push's call
    // sites). Without this, a widget nobody has touched in a while would
    // silently go stale — still showing yesterday's to-dos, or an event
    // that already started — for as long as the app stays unopened.
    //
    // Piggybacks on the system's own periodic onUpdate cadence
    // (updatePeriodMillis in home_widget_info.xml) rather than scheduling a
    // separate WorkManager job, reusing the exact headless-Dart-callback
    // mechanism the to-do tap already uses (see homeWidgetBackgroundCallback
    // in home_widget_background.dart) — just enqueued directly here since
    // there's no user tap to route through HomeWidgetBackgroundReceiver.
    //
    // The rate-limit guards against a real re-entrancy loop: the callback's
    // own HomeWidgetSync.push() ends by broadcasting
    // ACTION_APPWIDGET_UPDATE, which is exactly what invokes onUpdate() —
    // so an unguarded refresh here would re-trigger itself indefinitely.
    // Like updatePeriodMillis itself, this is still only best-effort —
    // Doze/App Standby can defer it — which is fine for a background
    // refresh (unlike the exact-alarm path notifications use).
    private fun maybeRefreshWidgetData(context: Context, widgetData: SharedPreferences) {
        val now = System.currentTimeMillis()
        val last = widgetData.getLong(LAST_BG_REFRESH_KEY, 0L)
        if (now - last < MIN_BG_REFRESH_INTERVAL_MS) return
        widgetData.edit().putLong(LAST_BG_REFRESH_KEY, now).apply()
        HomeWidgetBackgroundWorker.enqueueWork(
            context,
            Intent().apply { data = Uri.parse("planfit://refresh-widget") },
        )
    }

    // Fires whenever the user resizes the widget on the home screen — the
    // plain onUpdate cycle alone wouldn't otherwise pick up a compact <->
    // expanded layout switch until the system's next periodic update.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val expanded = minHeight >= EXPANDED_MIN_HEIGHT_DP

        val views = RemoteViews(
            context.packageName,
            if (expanded) R.layout.home_widget_layout_large else R.layout.home_widget_layout,
        )

        if (expanded) {
            bindExpanded(context, views, widgetData)
        } else {
            bindCompact(context, views, widgetData)
        }
        bindTodos(context, views, widgetData, rowCount = if (expanded) MAX_TODOS else 2)

        val progress = widgetData.getString("todos_progress", "") ?: ""
        val todosUri = widgetData.getString("todos_uri", "") ?: ""
        views.setTextViewText(R.id.widget_todos_progress, progress)
        views.setOnClickPendingIntent(
            R.id.widget_todos_tap_target,
            launchIntent(context, todosUri),
        )
        // A plain tap on the background (outside every section) still opens
        // the app with no deep link.
        views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context, null))

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun bindCompact(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val title = widgetData.getString("event0_title", "") ?: ""
        val time = widgetData.getString("event0_time", "") ?: ""
        val uri = widgetData.getString("event0_uri", "") ?: ""

        if (title.isEmpty()) {
            views.setTextViewText(
                R.id.widget_next_event_title,
                context.getString(R.string.home_widget_empty_event),
            )
            views.setTextViewText(R.id.widget_next_event_time, "")
        } else {
            views.setTextViewText(R.id.widget_next_event_title, title)
            views.setTextViewText(R.id.widget_next_event_time, time)
        }
        views.setOnClickPendingIntent(
            R.id.widget_event_tap_target,
            launchIntent(context, uri),
        )
    }

    private fun bindExpanded(context: Context, views: RemoteViews, widgetData: SharedPreferences) {
        val rowIds = arrayOf(R.id.widget_event0_row, R.id.widget_event1_row, R.id.widget_event2_row)
        val titleIds = arrayOf(R.id.widget_event0_title, R.id.widget_event1_title, R.id.widget_event2_title)
        val timeIds = arrayOf(R.id.widget_event0_time, R.id.widget_event1_time, R.id.widget_event2_time)

        var anyEvent = false
        for (i in 0 until MAX_EVENTS) {
            val title = widgetData.getString("event${i}_title", "") ?: ""
            if (title.isEmpty()) {
                views.setViewVisibility(rowIds[i], View.GONE)
                continue
            }
            anyEvent = true
            val time = widgetData.getString("event${i}_time", "") ?: ""
            val uri = widgetData.getString("event${i}_uri", "") ?: ""
            views.setViewVisibility(rowIds[i], View.VISIBLE)
            views.setTextViewText(titleIds[i], title)
            views.setTextViewText(timeIds[i], time)
            views.setOnClickPendingIntent(rowIds[i], launchIntent(context, uri))
        }
        views.setViewVisibility(R.id.widget_events_empty, if (anyEvent) View.GONE else View.VISIBLE)
    }

    // Renders up to [rowCount] of today's to-dos as checkable rows — shared
    // by both layouts, which each define their own widget_todo{i}_row/check/title
    // ids (the compact layout only has 2 of them, hence the cap).
    private fun bindTodos(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences,
        rowCount: Int,
    ) {
        val rowIds = arrayOf(R.id.widget_todo0_row, R.id.widget_todo1_row, R.id.widget_todo2_row)
        val checkIds = arrayOf(R.id.widget_todo0_check, R.id.widget_todo1_check, R.id.widget_todo2_check)
        val priorityIds = arrayOf(R.id.widget_todo0_priority, R.id.widget_todo1_priority, R.id.widget_todo2_priority)
        val titleIds = arrayOf(R.id.widget_todo0_title, R.id.widget_todo1_title, R.id.widget_todo2_title)

        var anyTodo = false
        for (i in 0 until rowCount) {
            val id = widgetData.getString("todo${i}_id", "") ?: ""
            val title = widgetData.getString("todo${i}_title", "") ?: ""
            if (id.isEmpty() || title.isEmpty()) {
                views.setViewVisibility(rowIds[i], View.GONE)
                continue
            }
            anyTodo = true
            val done = widgetData.getBoolean("todo${i}_done", false)
            views.setViewVisibility(rowIds[i], View.VISIBLE)
            views.setTextViewText(titleIds[i], title)
            views.setImageViewResource(
                checkIds[i],
                if (done) R.drawable.ic_widget_todo_checked else R.drawable.ic_widget_todo_unchecked,
            )

            val priority = widgetData.getInt("todo${i}_priority", 0)
            val priorityDrawable = when (priority) {
                1 -> R.drawable.ic_widget_priority_low
                2 -> R.drawable.ic_widget_priority_medium
                3 -> R.drawable.ic_widget_priority_high
                else -> null
            }
            if (priorityDrawable == null) {
                views.setViewVisibility(priorityIds[i], View.GONE)
            } else {
                views.setViewVisibility(priorityIds[i], View.VISIBLE)
                views.setImageViewResource(priorityIds[i], priorityDrawable)
            }

            views.setOnClickPendingIntent(rowIds[i], toggleTodoIntent(context, id))
        }
        views.setViewVisibility(R.id.widget_todos_empty, if (anyTodo) View.GONE else View.VISIBLE)
    }

    // A background broadcast (not an activity launch, unlike launchIntent) —
    // toggling a checkbox must not open the app. Handled Dart-side by the
    // interactivity callback registered in lib/core/home_widget/home_widget_background.dart,
    // which flips the to-do's done state in the DB and re-pushes fresh widget
    // data, closing the loop back to a redrawn checkbox.
    private fun toggleTodoIntent(context: Context, todoId: String) =
        HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("planfit://toggle-todo?id=$todoId"),
        )

    private fun launchIntent(context: Context, uri: String?) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            if (uri.isNullOrEmpty()) null else Uri.parse(uri),
        )
}
