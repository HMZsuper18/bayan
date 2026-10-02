package com.hamzah.bayan

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings

object IconSwitcher {
    private const val DEFAULT_VARIANT = "Classic"
    private const val PREFS_NAME = "bayan_prefs"
    private const val KEY_VARIANT = "app_icon_variant"
    private const val MIUI_LAUNCHER = "com.miui.home"
    private val aliases = listOf(
        "Classic" to "IconAliasClassic",
        "Emerald" to "IconAliasEmerald",
        "Midnight" to "IconAliasMidnight",
        "Gold" to "IconAliasGold",
        "Royal" to "IconAliasRoyal",
    )

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun aliasComponent(context: Context, aliasName: String): ComponentName =
        ComponentName(context, "com.hamzah.bayan.$aliasName")

    /**
     * Enables [target] and disables every other alias except [preserveClassName]
     * (the activity-alias currently hosting the running activity). Disabling the
     * running component mid-switch makes Android tear the activity down, which
     * looks like a crash. The preserved component is disabled in [finalize].
     */
    private fun applyEnabledState(
        context: Context,
        target: String,
        preserveClassName: String?,
    ): Boolean {
        val pm = context.packageManager
        val targetAlias = aliases.find { it.first == target }?.second ?: return false
        val targetComponent = aliasComponent(context, targetAlias)

        val currentState = pm.getComponentEnabledSetting(targetComponent)
        if (currentState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
            prefs(context).edit().putString(KEY_VARIANT, target).apply()
            return false
        }

        // Enable the new alias FIRST so there is never a moment with no
        // launcher component — MIUI/HyperOS dock falls back to the
        // <application> icon and caches it if that happens.
        pm.setComponentEnabledSetting(
            targetComponent,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        for ((_, aliasName) in aliases) {
            val comp = aliasComponent(context, aliasName)
            if (comp == targetComponent) continue
            if (preserveClassName != null && comp.className == preserveClassName) continue
            if (pm.getComponentEnabledSetting(comp) != PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                pm.setComponentEnabledSetting(
                    comp,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }

        prefs(context).edit().putString(KEY_VARIANT, target).apply()
        return true
    }

    /**
     * Starts a switch without disabling the currently running alias.
     * Returns true when a component actually changed.
     */
    fun switchTo(context: Context, variant: String, preserveClassName: String? = null): Boolean {
        val changed = applyEnabledState(context, variant, preserveClassName)
        if (changed) {
            nudgeLauncher(context)
        }
        return changed
    }

    /**
     * Disables any leftover alias (including a preserved running one) after
     * the UI is ready. Returns the previous component name if it is now
     * disabled and must be relaunched away from.
     */
    fun finalize(context: Context, previousClassName: String?): String? {
        val pm = context.packageManager
        val target = prefs(context).getString(KEY_VARIANT, DEFAULT_VARIANT) ?: DEFAULT_VARIANT
        val targetAlias = aliases.find { it.first == target }?.second
        val targetComponent = targetAlias?.let { aliasComponent(context, it) }

        for ((_, aliasName) in aliases) {
            val comp = aliasComponent(context, aliasName)
            if (targetComponent != null && comp == targetComponent) continue
            if (pm.getComponentEnabledSetting(comp) != PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                pm.setComponentEnabledSetting(
                    comp,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }

        if (previousClassName == null) return null
        val previous = aliasComponent(context, previousClassName.substringAfterLast('.'))
        val state = pm.getComponentEnabledSetting(previous)
        return if (state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED ||
            state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER
        ) {
            previousClassName
        } else {
            null
        }
    }

    fun componentClassName(variant: String): String? {
        val alias = aliases.find { it.first == variant }?.second ?: return null
        return "com.hamzah.bayan.$alias"
    }

    fun ensureEnabled(context: Context, variant: String) {
        if (applyEnabledState(context, variant, null)) {
            nudgeLauncher(context)
        }
    }

    fun reEnableDefault(context: Context) {
        val saved = prefs(context).getString(KEY_VARIANT, null)
        if (saved != null && aliases.any { it.first == saved }) {
            switchTo(context, saved)
        } else {
            switchTo(context, DEFAULT_VARIANT)
        }
    }

    fun hasMiuiHome(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(MIUI_LAUNCHER, 0)
        true
    } catch (_: Exception) {
        false
    }

    fun openLauncherSettings(context: Context): Boolean = try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$MIUI_LAUNCHER")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }

    // MIUI/HyperOS keeps a separate dock icon cache that does not react to
    // PackageManager broadcasts. Restarting the launcher process is the only
    // silent refresh we can attempt without privileged permissions.
    private fun nudgeLauncher(context: Context) {
        if (!hasMiuiHome(context)) return
        try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.killBackgroundProcesses(MIUI_LAUNCHER)
        } catch (_: Exception) {
        }
    }
}
