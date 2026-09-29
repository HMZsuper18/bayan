package com.hamzah.bayan

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge for the reciter download progress notification.
 *
 * Dart owns all copy and resolves it against the device locale before calling
 * in, so `update` carries the notification channel name and description too.
 */
class DownloadNotificationBridge(
    context: Context,
) {
    // Application context: this object is captured by a MethodChannel handler
    // that outlives the Activity that created it.
    private val context: Context = context.applicationContext

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "update" -> {
                val payload = DownloadForegroundService.Payload(
                    channelName = call.argument<String>("channelName").orEmpty(),
                    channelDescription = call.argument<String>("channelDescription").orEmpty(),
                    title = call.argument<String>("title").orEmpty(),
                    text = call.argument<String>("text").orEmpty(),
                    progress = call.argument<Int>("progress") ?: 0,
                    indeterminate = call.argument<Boolean>("indeterminate") ?: true,
                )
                DownloadForegroundService.submit(context, payload)
                result.success(true)
            }
            "stop" -> {
                DownloadForegroundService.stop(context)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
