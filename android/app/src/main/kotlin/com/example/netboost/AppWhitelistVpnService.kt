package com.example.netboost

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

class AppWhitelistVpnService : VpnService() {
    private val tag = "AppWhitelistVpnService"
    private var vpnInterface: ParcelFileDescriptor? = null
    private var dropThread: Thread? = null
    private val running = AtomicBoolean(false)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopFirewall()
            stopSelf()
            return START_NOT_STICKY
        }

        val allowedPackages = intent
            ?.getStringArrayListExtra(EXTRA_ALLOWED_PACKAGES)
            .orEmpty()
            .filter { it.isNotBlank() }

        if (allowedPackages.isEmpty()) {
            Log.w(tag, "Start requested without allowed packages")
            stopFirewall()
            stopSelf()
            return START_NOT_STICKY
        }

        runCatching {
            startForeground(NOTIFICATION_ID, buildNotification(allowedPackages.size))
            startFirewall(allowedPackages)
        }.onFailure {
            Log.e(tag, "Failed to start whitelist VPN", it)
            isRunning = false
            Companion.allowedPackages = emptyList()
            stopFirewall()
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopFirewall()
        isRunning = false
        allowedPackages = emptyList()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopFirewall()
        isRunning = false
        allowedPackages = emptyList()
        super.onRevoke()
    }

    private fun startFirewall(allowedPackages: List<String>) {
        stopFirewall()

        val builder = Builder()
            .setSession("SignalFinder App Whitelist")
            .setMtu(1500)
            .addAddress("10.88.0.2", 32)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("223.5.5.5")

        allowedPackages.forEach { packageName ->
            runCatching { builder.addDisallowedApplication(packageName) }
                .onFailure { Log.w(tag, "Cannot exclude $packageName from VPN", it) }
        }

        vpnInterface = builder.establish()
        val descriptor = vpnInterface?.fileDescriptor
            ?: throw IllegalStateException("VPN interface establish returned null")
        Companion.allowedPackages = allowedPackages
        isRunning = true
        Log.i(tag, "Whitelist VPN established; allowed packages=${allowedPackages.size}")
        running.set(true)
        dropThread = Thread {
            val buffer = ByteArray(32767)
            FileInputStream(descriptor).use { input ->
                while (running.get()) {
                    try {
                        input.read(buffer)
                    } catch (_: IOException) {
                        running.set(false)
                    }
                }
            }
        }.apply {
            name = "NetBoostVpnDropThread"
            isDaemon = true
            start()
        }
    }

    private fun stopFirewall() {
        running.set(false)
        runCatching { vpnInterface?.close() }
        vpnInterface = null
        dropThread = null
        stopForeground(STOP_FOREGROUND_REMOVE_COMPAT)
    }

    private fun buildNotification(allowedCount: Int): Notification {
        ensureNotificationChannel()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle("App 联网白名单已开启")
                .setContentText("已放行 $allowedCount 个 App，其它 App 暂停联网")
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle("App 联网白名单已开启")
                .setContentText("已放行 $allowedCount 个 App，其它 App 暂停联网")
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "联网白名单",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.example.netboost.action.START_APP_WHITELIST_VPN"
        const val ACTION_STOP = "com.example.netboost.action.STOP_APP_WHITELIST_VPN"
        const val EXTRA_ALLOWED_PACKAGES = "allowedPackages"
        private const val CHANNEL_ID = "app_whitelist_vpn"
        private const val NOTIFICATION_ID = 1001
        private const val STOP_FOREGROUND_REMOVE_COMPAT = 1

        var isRunning: Boolean = false
            private set

        var allowedPackages: List<String> = emptyList()
            private set

        fun start(context: Context, packages: List<String>) {
            allowedPackages = packages
            val intent = Intent(context, AppWhitelistVpnService::class.java).apply {
                action = ACTION_START
                putStringArrayListExtra(EXTRA_ALLOWED_PACKAGES, ArrayList(packages))
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            isRunning = false
            allowedPackages = emptyList()
            val intent = Intent(context, AppWhitelistVpnService::class.java).apply {
                action = ACTION_STOP
            }
            runCatching { context.startService(intent) }
        }
    }
}
