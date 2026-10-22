package com.davart.davart_mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> {
                        ensureChannel()
                        requestNotifyPermission()
                        result.success(true)
                    }
                    "show" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        showChat(
                            title = args["title"]?.toString()?.ifBlank { "DAVart" } ?: "DAVart",
                            body = args["body"]?.toString()?.ifBlank { "Новое сообщение" }
                                ?: "Новое сообщение",
                            chatId = args["chatId"]?.toString().orEmpty(),
                            messageId = args["messageId"]?.toString().orEmpty(),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotifyPermission() {
        if (Build.VERSION.SDK_INT < 33) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4101)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Сообщения",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = "Новые сообщения, даже когда приложение закрыто"
        channel.enableVibration(true)
        manager.createNotificationChannel(channel)
    }

    private fun showChat(title: String, body: String, chatId: String, messageId: String) {
        ensureChannel()
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (chatId.isNotEmpty()) {
                data = Uri.parse("davart://go/chat/$chatId")
            }
        }
        val requestCode = messageId.hashCode()
        val pending = PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .build()
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(requestCode, notification)
    }

    companion object {
        private const val CHANNEL = "davart/notify"
        private const val CHANNEL_ID = "davart_chat"
    }
}
