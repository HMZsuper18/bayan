package com.hamzah.bayan

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class DownloadManagerBridge(
    private val context: Context,
    private val channel: MethodChannel,
) {
    private val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val requestIds = mutableMapOf<String, MutableList<Long>>()
    private val idToReciter = mutableMapOf<Long, String>()
    private val idToPath = mutableMapOf<Long, String>()

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
            if (id == -1L) return
            val reciterId = idToReciter[id] ?: return
            channel.invokeMethod("onDownloadComplete", mapOf(
                "reciterId" to reciterId,
                "downloadId" to id,
            ))
        }
    }

    fun register() {
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    fun unregister() {
        try { context.unregisterReceiver(receiver) } catch (_: Exception) {}
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDownloads" -> startDownloads(call, result)
            "pauseDownloads" -> pauseDownloads(call, result)
            "resumeDownloads" -> resumeDownloads(call, result)
            "cancelDownloads" -> cancelDownloads(call, result)
            "cancelAll" -> cancelAll(result)
            "queryProgress" -> queryProgress(result)
            else -> result.notImplemented()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun startDownloads(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<String, Any>
            ?: return result.error("INVALID_ARGS", "Arguments required", null)
        val reciterId = args["reciterId"] as? String
            ?: return result.error("INVALID_ARGS", "reciterId required", null)
        val ids = args["ids"] as? List<Int>
            ?: return result.error("INVALID_ARGS", "ids required", null)
        val urls = args["urls"] as? List<String>
            ?: return result.error("INVALID_ARGS", "urls required", null)
        val paths = args["paths"] as? List<String>
            ?: return result.error("INVALID_ARGS", "paths required", null)

        cancelDownloadsFor(reciterId)

        val requestIdsList = mutableListOf<Long>()

        val extBase = context.getExternalFilesDir(null)
            ?: return result.error("NO_EXTERNAL", "External files dir unavailable", null)

        for (i in ids.indices) {
            val url = urls[i]
            val filePath = paths[i]
            if (url.isEmpty() || filePath.isEmpty()) continue

            val internalFile = File(filePath)
            if (internalFile.exists() && internalFile.length() > 1024) continue

            val relativePath = filePath.substringAfter("/reciters/")
            val extFile = File(extBase, "reciters/$relativePath")
            extFile.parentFile?.mkdirs()

            val req = DownloadManager.Request(Uri.parse(url))
                .setDestinationInExternalFilesDir(context, "reciters", relativePath)
                .setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                )
                .setTitle("بيان")
                .setDescription("Downloading ${reciterId}...")
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)
                .setRequiresCharging(false)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                req.setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE
                )
            }

            val id = dm.enqueue(req)
            requestIdsList.add(id)
            idToReciter[id] = reciterId
            idToPath[id] = filePath
        }

        requestIds.getOrPut(reciterId) { mutableListOf() }.addAll(requestIdsList)
        result.success(mapOf("started" to requestIdsList.size))
    }

    private fun pauseDownloads(call: MethodCall, result: MethodChannel.Result) {
        val reciterId = call.arguments as? String
            ?: return result.error("INVALID_ARGS", "reciterId required", null)
        cancelDownloadsFor(reciterId)
        result.success(true)
    }

    @Suppress("UNCHECKED_CAST")
    private fun resumeDownloads(call: MethodCall, result: MethodChannel.Result) {
        startDownloads(call, result)
    }

    private fun cancelDownloads(call: MethodCall, result: MethodChannel.Result) {
        val reciterId = call.arguments as? String
            ?: return result.error("INVALID_ARGS", "reciterId required", null)
        cancelDownloadsFor(reciterId)
        result.success(true)
    }

    private fun cancelDownloadsFor(reciterId: String) {
        val ids = requestIds.remove(reciterId) ?: return
        for (id in ids) {
            dm.remove(id)
            idToReciter.remove(id)
            idToPath.remove(id)
        }
    }

    private fun cancelAll(result: MethodChannel.Result) {
        for ((id, _) in idToReciter) { dm.remove(id) }
        requestIds.clear()
        idToReciter.clear()
        idToPath.clear()
        result.success(true)
    }

    private fun queryProgress(result: MethodChannel.Result) {
        val reciterProgress = mutableMapOf<String, Map<String, Any>>()

        for ((reciterId, ids) in requestIds.toMap()) {
            var received = 0L
            var total = 0L
            var activeCount = 0
            var hadItems = ids.isNotEmpty()

            val iter = ids.iterator()
            while (iter.hasNext()) {
                val id = iter.next()
                val cursor = dm.query(DownloadManager.Query().setFilterById(id))
                if (cursor == null) {
                    iter.remove(); idToReciter.remove(id); idToPath.remove(id); continue
                }

                if (cursor.moveToFirst()) {
                    val status = cursor.getInt(
                        cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
                    )
                    val bytesGot = cursor.getLong(
                        cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                    )
                    val bytesTotal = cursor.getLong(
                        cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                    )
                    received += bytesGot
                    total += bytesTotal

                    when (status) {
                        DownloadManager.STATUS_SUCCESSFUL -> {
                            copyToInternal(id)
                            iter.remove()
                            idToReciter.remove(id)
                            idToPath.remove(id)
                        }
                        DownloadManager.STATUS_FAILED -> {
                            iter.remove()
                            idToReciter.remove(id)
                            idToPath.remove(id)
                        }
                        else -> activeCount++
                    }
                } else {
                    iter.remove()
                    idToReciter.remove(id)
                    idToPath.remove(id)
                }
                cursor.close()
            }

            if (ids.isEmpty()) requestIds.remove(reciterId)

            reciterProgress[reciterId] = mapOf(
                "received" to received,
                "total" to total,
                "active" to activeCount,
                "complete" to (activeCount == 0 && hadItems),
            )
        }

        result.success(reciterProgress)
    }

    private fun copyToInternal(downloadId: Long) {
        val internalPath = idToPath[downloadId] ?: return
        val extBase = context.getExternalFilesDir(null) ?: return
        val relativePath = internalPath.substringAfter("/reciters/")
        val extFile = File(extBase, "reciters/$relativePath")
        val internalFile = File(internalPath)

        if (!extFile.exists()) return
        internalFile.parentFile?.mkdirs()
        try {
            extFile.copyTo(internalFile, overwrite = true)
            extFile.delete()
        } catch (_: Exception) {}
    }
}
