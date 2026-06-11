package com.example.realtime_todo_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

class TodoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {

        val widgetData = HomeWidgetPlugin.getData(context)
        val pendingCount =
        widgetData.getInt("pendingCount", 0)

        val tasksString =
            widgetData.getString("tasks", "") ?: ""

        val tasks =
        if (tasksString.isBlank()) {
            emptyList()
        } else {
            tasksString.split("\n")
        }
        for (appWidgetId in appWidgetIds) {

            val views = RemoteViews(
                context.packageName,
                R.layout.widget_todo
            )
            if (tasksString.isBlank()) {
                views.setTextViewText(
                    R.id.task1,
                    "🎉 No pending tasks"
                )
            }
            val intent = Intent(
                context,
                MainActivity::class.java
            )
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                pendingIntent
            )
            views.setTextViewText(
                R.id.widget_title,
                "TODO TASKS ($pendingCount)"
            )

            if (tasks.isEmpty()) {
                views.setTextViewText(
                    R.id.task1,
                    "🎉 No pending tasks"
                )
                views.setTextViewText(R.id.task2, "")
                views.setTextViewText(R.id.task3, "")
                views.setTextViewText(R.id.task4, "")
                views.setTextViewText(R.id.task5, "")
                } else {
                    views.setTextViewText(
                        R.id.task1,
                        tasks.getOrNull(0) ?: ""
                    )
                    views.setTextViewText(
                        R.id.task2,
                        tasks.getOrNull(1) ?: ""
                    )

                    views.setTextViewText(
                        R.id.task3,
                        tasks.getOrNull(2) ?: ""
                    )

                    views.setTextViewText(
                        R.id.task4,
                        tasks.getOrNull(3) ?: ""
                    )

                    views.setTextViewText(
                        R.id.task5,
                        tasks.getOrNull(4) ?: ""
                    )
                }
            appWidgetManager.updateAppWidget(
            appWidgetId,
            views
            )
        }
    }
}