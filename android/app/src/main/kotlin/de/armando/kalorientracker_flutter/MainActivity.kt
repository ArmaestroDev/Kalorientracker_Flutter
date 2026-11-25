package de.armando.kalorientracker_flutter

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "de.armando.kalorientracker_flutter/widget"
    private var widgetChannel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractWidgetAction(intent)?.let { pendingAction = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractWidgetAction(intent)?.let { action ->
            val channel = widgetChannel
            if (channel != null) {
                channel.invokeMethod("onWidgetAction", action)
            } else {
                pendingAction = action
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialAction" -> {
                        val action = pendingAction
                        pendingAction = null
                        result.success(action)
                    }
                    "updateWidgetData" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args != null) {
                            saveWidgetSnapshot(args)
                            KalorientrackerWidgetProvider.updateAllWidgets(this@MainActivity)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun extractWidgetAction(intent: Intent?): String? {
        return intent?.getStringExtra(KalorientrackerWidgetProvider.EXTRA_WIDGET_ACTION)
    }

    private fun saveWidgetSnapshot(args: Map<*, *>) {
        val prefs = getSharedPreferences(
            KalorientrackerWidgetProvider.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        prefs.edit()
            .putInt("eatenKcal", (args["eatenKcal"] as? Number)?.toInt() ?: 0)
            .putInt("budgetKcal", (args["budgetKcal"] as? Number)?.toInt() ?: 0)
            .putInt("protein", (args["protein"] as? Number)?.toInt() ?: 0)
            .putInt("proteinGoal", (args["proteinGoal"] as? Number)?.toInt() ?: 0)
            .putInt("carbs", (args["carbs"] as? Number)?.toInt() ?: 0)
            .putInt("fat", (args["fat"] as? Number)?.toInt() ?: 0)
            .putBoolean("hasGoals", args["hasGoals"] as? Boolean ?: false)
            .putString("dateLabel", args["dateLabel"] as? String ?: "Heute")
            .apply()
    }
}
