package com.hamzah.bayan

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager

object IconSwitcher {
    private const val DEFAULT_VARIANT = "Classic"
    private const val PREFS_NAME = "bayan_prefs"
    private const val KEY_VARIANT = "app_icon_variant"
    private val aliases = listOf(
        "Classic" to "IconAliasClassic",
        "Emerald" to "IconAliasEmerald",
        "Midnight" to "IconAliasMidnight",
        "Gold" to "IconAliasGold",
        "Royal" to "IconAliasRoyal",
    )

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun applyEnabledState(context: Context, target: String) {
        val pm = context.packageManager
        val targetAlias = aliases.find { it.first == target }?.second ?: return

        // Disable ALL aliases first
        for ((_, aliasName) in aliases) {
            pm.setComponentEnabledSetting(
                ComponentName(context, "com.hamzah.bayan.$aliasName"),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // Enable only the target
        pm.setComponentEnabledSetting(
            ComponentName(context, "com.hamzah.bayan.$targetAlias"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        prefs(context).edit().putString(KEY_VARIANT, target).apply()
    }

    fun switchTo(context: Context, variant: String) {
        applyEnabledState(context, variant)
    }

    fun ensureEnabled(context: Context, variant: String) {
        applyEnabledState(context, variant)
    }

    fun reEnableDefault(context: Context) {
        val saved = prefs(context).getString(KEY_VARIANT, null)
        if (saved != null && aliases.any { it.first == saved }) {
            applyEnabledState(context, saved)
        } else {
            applyEnabledState(context, DEFAULT_VARIANT)
        }
    }
}
