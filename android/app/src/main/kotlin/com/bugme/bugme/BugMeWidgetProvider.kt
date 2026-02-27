package com.bugme.bugme

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * BugMe home-screen widget.
 * Reads monthly-spend + account-name from SharedPreferences saved by
 * the Flutter home_widget package (prefix: "flutter.").
 */
class BugMeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )

            val spend = prefs.getString("flutter.widget_monthly_spend", "₹0") ?: "₹0"
            val accountName = prefs.getString("flutter.widget_account_name", "Personal") ?: "Personal"

            val views = RemoteViews(context.packageName, R.layout.bugme_widget)
            views.setTextViewText(R.id.widget_spend, spend)
            views.setTextViewText(R.id.widget_account_name, accountName.uppercase())

            // Tap anywhere → open the app on the voice/add entry tab (index 2)
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_tab", 2) // Voice entry tab
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_mic_button, pendingIntent)

            // Tap on spend → open the main app
            val mainIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val mainPendingIntent = PendingIntent.getActivity(
                context, 1, mainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_spend, mainPendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
