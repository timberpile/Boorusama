package com.timberpile.boorusama

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.io.IOException

/** A keep-alive for the existing FFmpegKit worker; the editor owns its output. */
class GifConversionForegroundService : Service() {
    private var job: Long? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getLongExtra("job", -1L) ?: -1L
        if (intent?.action == ACTION_CANCEL) {
            if (id == job && id == activeJob) onCancel?.invoke(id)
            else if (job == null) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (id != activeJob) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        job = id
        try {
            val title = intent!!.getStringExtra("title") ?: throw IOException("Missing title")
            val cancel = intent.getStringExtra("cancelLabel") ?: throw IOException("Missing cancel label")
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL, title, NotificationManager.IMPORTANCE_LOW))
            }
            // A stale notification must retain its old job ID rather than
            // receiving the extras of a later conversion's pending intent.
            val cancelIntent = PendingIntent.getService(this, id.toInt(),
                Intent(this, GifConversionForegroundService::class.java).setAction(ACTION_CANCEL).putExtra("job", id),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val returnIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val notification = NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_gif_conversion)
                .setContentTitle(title)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setProgress(0, 0, true)
                .addAction(0, cancel, cancelIntent)
                .apply {
                    if (returnIntent != null) setContentIntent(PendingIntent.getActivity(this@GifConversionForegroundService,
                        id.toInt(), returnIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                }.build()
            if (Build.VERSION.SDK_INT >= 29) {
                val type = if (Build.VERSION.SDK_INT >= 35) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
                    else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                startForeground(NOTIFICATION, notification, type)
            } else startForeground(NOTIFICATION, notification)
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:gif-conversion").apply {
                setReferenceCounted(false)
                acquire(6 * 60 * 60 * 1000L)
            }
            onStarted?.invoke(id, null)
        } catch (error: Exception) {
            onStarted?.invoke(id, error)
            if (activeJob == id) activeJob = null
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        job?.let { onCancel?.invoke(it) }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        val lock = wakeLock
        if (lock?.isHeld == true) lock.release()
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (job == activeJob) {
            job?.let {
                onStarted?.invoke(it, IOException("GIF service stopped"))
                onCancel?.invoke(it)
            }
            activeJob = null
        }
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "gif_conversion"
        private const val NOTIFICATION = 280028
        private const val ACTION_CANCEL = "com.timberpile.boorusama.CANCEL_GIF"
        var activeJob: Long? = null
        var onStarted: ((Long, Exception?) -> Unit)? = null
        var onCancel: ((Long) -> Unit)? = null
    }
}
