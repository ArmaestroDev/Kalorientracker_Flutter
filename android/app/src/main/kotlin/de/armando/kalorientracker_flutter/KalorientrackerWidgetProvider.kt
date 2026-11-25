package de.armando.kalorientracker_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import java.text.NumberFormat
import java.util.Locale

class KalorientrackerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "kalorientracker_widget_prefs"
        const val EXTRA_WIDGET_ACTION = "de.armando.kalorientracker_flutter.WIDGET_ACTION"
        const val ACTION_ADD_TEXT = "add_text"
        const val ACTION_ADD_VOICE = "add_voice"
        const val ACTION_ADD_PHOTO = "add_photo"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KalorientrackerWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val eaten = prefs.getInt("eatenKcal", 0)
            val budget = prefs.getInt("budgetKcal", 0)
            val protein = prefs.getInt("protein", 0)
            val proteinGoal = prefs.getInt("proteinGoal", 0)
            val carbs = prefs.getInt("carbs", 0)
            val fat = prefs.getInt("fat", 0)
            val hasGoals = prefs.getBoolean("hasGoals", false)
            val dateLabel = prefs.getString("dateLabel", "Heute") ?: "Heute"

            val nf = NumberFormat.getIntegerInstance(Locale.GERMANY)
            val views = RemoteViews(context.packageName, R.layout.kalorientracker_widget)

            views.setTextViewText(R.id.widget_date, dateLabel)

            if (!hasGoals) {
                views.setTextViewText(R.id.widget_remaining, "Profil einrichten")
                views.setTextColor(
                    R.id.widget_remaining,
                    ContextCompat.getColor(context, R.color.widget_text_primary)
                )
                views.setTextViewText(R.id.widget_eaten_budget, "${nf.format(eaten)} kcal")
                views.setProgressBar(R.id.widget_progress, 100, 0, false)
            } else {
                val remaining = budget - eaten
                if (remaining >= 0) {
                    views.setTextViewText(
                        R.id.widget_remaining,
                        "Noch ${nf.format(remaining)} kcal"
                    )
                    views.setTextColor(
                        R.id.widget_remaining,
                        ContextCompat.getColor(context, R.color.widget_text_primary)
                    )
                } else {
                    views.setTextViewText(
                        R.id.widget_remaining,
                        "Über Ziel: +${nf.format(-remaining)} kcal"
                    )
                    views.setTextColor(
                        R.id.widget_remaining,
                        ContextCompat.getColor(context, R.color.widget_danger)
                    )
                }
                views.setTextViewText(
                    R.id.widget_eaten_budget,
                    "${nf.format(eaten)} / ${nf.format(budget)} kcal"
                )
                val progress = if (budget > 0) ((eaten * 100) / budget).coerceIn(0, 100) else 0
                views.setProgressBar(R.id.widget_progress, 100, progress, false)
            }

            val proteinPart = if (proteinGoal > 0) "P $protein/${proteinGoal}g" else "P ${protein}g"
            views.setTextViewText(
                R.id.widget_macros,
                "$proteinPart · K ${carbs}g · F ${fat}g"
            )

            views.setOnClickPendingIntent(
                R.id.widget_summary_area,
                launchPendingIntent(context, null, 100)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_text,
                launchPendingIntent(context, ACTION_ADD_TEXT, 101)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_voice,
                launchPendingIntent(context, ACTION_ADD_VOICE, 102)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_photo,
                launchPendingIntent(context, ACTION_ADD_PHOTO, 103)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun launchPendingIntent(
            context: Context,
            action: String?,
            requestCode: Int
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                if (action != null) {
                    putExtra(EXTRA_WIDGET_ACTION, action)
                }
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
