package com.example.greetingcard.utils

import android.content.Context

object Settings {
    private const val PREFS_NAME = "SettingsPrefs"
    private const val KEY_PREV_INTERVAL = "prev_interval"
    private const val KEY_NEXT_INTERVAL = "next_interval"
    private const val KEY_CRITICAL_TIME = "critical_time"
    private const val DEFAULT_PREV_INTERVAL = 30
    private const val DEFAULT_NEXT_INTERVAL = 300
    private const val DEFAULT_CRITICAL_TIME = 14

    var PREV_INTERVAL = DEFAULT_PREV_INTERVAL
        private set
    var NEXT_INTERVAL = DEFAULT_NEXT_INTERVAL
        private set
    var CRITICAL_TIME = DEFAULT_CRITICAL_TIME
        private set

    fun load(context: Context) {
        val sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        PREV_INTERVAL = sharedPreferences.getInt(KEY_PREV_INTERVAL, DEFAULT_PREV_INTERVAL)
        NEXT_INTERVAL = sharedPreferences.getInt(KEY_NEXT_INTERVAL, DEFAULT_NEXT_INTERVAL)
        CRITICAL_TIME = sharedPreferences.getInt(KEY_CRITICAL_TIME, DEFAULT_CRITICAL_TIME)
    }

    private fun save(context: Context) {
        val sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putInt(KEY_PREV_INTERVAL, PREV_INTERVAL)
            putInt(KEY_NEXT_INTERVAL, NEXT_INTERVAL)
            putInt(KEY_CRITICAL_TIME, CRITICAL_TIME)
            apply()
        }
    }

    fun updatePrevInterval(context: Context, value: Int) {
        PREV_INTERVAL = value
        save(context)
    }

    fun updateNextInterval(context: Context, value: Int) {
        NEXT_INTERVAL = value
        save(context)
    }

    fun updateCriticalTime(context: Context, value: Int) {
        if (value in 0..24) {
            CRITICAL_TIME = value
            save(context)
        }
    }

}