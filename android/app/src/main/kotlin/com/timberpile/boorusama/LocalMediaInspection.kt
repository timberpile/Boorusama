package com.timberpile.boorusama

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build
import java.io.File
import java.io.RandomAccessFile

internal class LocalMediaFormatException : Exception()
internal class LocalMediaBoundsException : Exception()

private const val MAX_IMAGE_PIXELS = 32_000_000L
private const val MAX_VIDEO_PIXELS = 3840L * 2160L
private const val MAX_GIF_PIXELS = 256_000_000L
private const val MAX_GIF_FRAMES = 500

internal fun inspectLocalMedia(file: File, format: String): Map<String, Int?> {
    return when (format) {
        "mp4", "webm" -> inspectVideo(file, format)
        "jpeg", "png", "webp", "gif" -> inspectImage(file, format)
        else -> throw LocalMediaFormatException()
    }
}

private fun checkDimensions(width: Int, height: Int, maxPixels: Long) {
    if (width <= 0 || height <= 0) throw LocalMediaFormatException()
    if (width.toLong() * height > maxPixels || maxOf(width, height) > 32768) {
        throw LocalMediaBoundsException()
    }
}

private fun inspectImage(file: File, format: String): Map<String, Int?> {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, bounds)
    if (bounds.outMimeType != "image/$format") throw LocalMediaFormatException()
    val width = bounds.outWidth
    val height = bounds.outHeight
    checkDimensions(width, height, MAX_IMAGE_PIXELS)
    if (format == "gif") inspectGif(file, width, height)
    if (format == "webp") inspectStillWebp(file)
    var sample = 1
    while (maxOf(width, height) / sample > 1024) sample *= 2
    val options = BitmapFactory.Options().apply { inSampleSize = sample }
    val bitmap = BitmapFactory.decodeFile(file.path, options) ?: throw LocalMediaFormatException()
    bitmap.recycle()
    return mapOf("width" to width, "height" to height, "durationMs" to null)
}

private fun RandomAccessFile.little16(): Int = readUnsignedByte() or (readUnsignedByte() shl 8)

private fun RandomAccessFile.skipExact(count: Long) {
    if (count < 0 || count > length() - filePointer) throw LocalMediaFormatException()
    seek(filePointer + count)
}

private fun RandomAccessFile.skipSubBlocks() {
    while (true) {
        val count = readUnsignedByte()
        if (count == 0) return
        skipExact(count.toLong())
    }
}

private fun inspectGif(file: File, width: Int, height: Int) {
    try {
        RandomAccessFile(file, "r").use { input ->
            input.seek(10)
            val global = input.readUnsignedByte()
            input.skipExact(2)
            if (global and 0x80 != 0) input.skipExact(3L shl ((global and 7) + 1))
            var frames = 0
            while (true) {
                when (input.readUnsignedByte()) {
                    0x3b -> {
                        if (frames == 0) throw LocalMediaFormatException()
                        return
                    }
                    0x21 -> {
                        input.readUnsignedByte()
                        input.skipSubBlocks()
                    }
                    0x2c -> {
                        val x = input.little16()
                        val y = input.little16()
                        val frameWidth = input.little16()
                        val frameHeight = input.little16()
                        checkDimensions(frameWidth, frameHeight, MAX_IMAGE_PIXELS)
                        if (x + frameWidth > width || y + frameHeight > height) {
                            throw LocalMediaFormatException()
                        }
                        frames++
                        // Animations may allocate the full canvas for each frame.
                        if (frames > MAX_GIF_FRAMES || width.toLong() * height * frames > MAX_GIF_PIXELS) {
                            throw LocalMediaBoundsException()
                        }
                        val local = input.readUnsignedByte()
                        if (local and 0x80 != 0) input.skipExact(3L shl ((local and 7) + 1))
                        if (input.readUnsignedByte() !in 2..8) throw LocalMediaFormatException()
                        input.skipSubBlocks()
                    }
                    else -> throw LocalMediaFormatException()
                }
            }
        }
    } catch (_: java.io.EOFException) {
        throw LocalMediaFormatException()
    }
}

private fun inspectStillWebp(file: File) {
    RandomAccessFile(file, "r").use { input ->
        input.seek(12)
        while (input.filePointer + 8 <= input.length()) {
            val chunk = input.readInt()
            val size = Integer.reverseBytes(input.readInt()).toLong() and 0xffffffffL
            if (chunk == 0x414e494d || chunk == 0x414e4d46) throw LocalMediaFormatException()
            if (chunk == 0x56503858 && size >= 1) {
                if (input.readUnsignedByte() and 2 != 0) throw LocalMediaFormatException()
                input.skipExact(size + (size and 1) - 1)
            } else {
                input.skipExact(size + (size and 1))
            }
        }
    }
}

private fun inspectVideo(file: File, format: String): Map<String, Int?> {
    val extractor = MediaExtractor()
    try {
        extractor.setDataSource(file.path)
        val tracks = (0 until extractor.trackCount).map(extractor::getTrackFormat)
        val video = tracks.firstOrNull {
            it.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true
        } ?: throw LocalMediaFormatException()
        val mime = video.getString(MediaFormat.KEY_MIME)
        if (format == "webm" && mime !in setOf("video/x-vnd.on2.vp8", "video/x-vnd.on2.vp9", "video/av01")) {
            throw LocalMediaFormatException()
        }
        val width = video.getInteger(MediaFormat.KEY_WIDTH)
        val height = video.getInteger(MediaFormat.KEY_HEIGHT)
        checkDimensions(width, height, MAX_VIDEO_PIXELS)
        if (maxOf(width, height) > 4096) throw LocalMediaBoundsException()
        if (MediaCodecList(MediaCodecList.REGULAR_CODECS).findDecoderForFormat(video) == null) {
            throw LocalMediaFormatException()
        }
        val duration = if (video.containsKey(MediaFormat.KEY_DURATION)) {
            (video.getLong(MediaFormat.KEY_DURATION) / 1000).coerceIn(0, Int.MAX_VALUE.toLong()).toInt()
        } else null
        val rotation = if (video.containsKey(MediaFormat.KEY_ROTATION)) {
            video.getInteger(MediaFormat.KEY_ROTATION)
        } else 0
        return if (rotation == 90 || rotation == 270) {
            mapOf("width" to height, "height" to width, "durationMs" to duration)
        } else {
            mapOf("width" to width, "height" to height, "durationMs" to duration)
        }
    } catch (_: java.io.IOException) {
        throw LocalMediaFormatException()
    } catch (_: IllegalArgumentException) {
        throw LocalMediaFormatException()
    } finally {
        extractor.release()
    }
}

internal fun localMediaThumbnail(source: File, output: File, video: Boolean): String? {
    if (output.isFile && output.length() > 0) return output.path
    val frame = (if (video) videoFrame(source) else firstGifFrame(source)) ?: return null
    val scale = minOf(1.0, 384.0 / maxOf(frame.width, frame.height))
    val thumbnail = if (scale == 1.0) frame else Bitmap.createScaledBitmap(
        frame,
        maxOf(1, (frame.width * scale).toInt()),
        maxOf(1, (frame.height * scale).toInt()),
        true,
    )
    output.parentFile?.mkdirs()
    val staged = File(output.parentFile, "${output.name}.part")
    try {
        val written = staged.outputStream().use { thumbnail.compress(Bitmap.CompressFormat.JPEG, 84, it) }
        return if (written && staged.renameTo(output)) output.path else null
    } finally {
        staged.delete()
        if (thumbnail !== frame) thumbnail.recycle()
        frame.recycle()
    }
}

private fun firstGifFrame(source: File): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(source.path, bounds)
    checkDimensions(bounds.outWidth, bounds.outHeight, MAX_IMAGE_PIXELS)
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 768) sample *= 2
    return BitmapFactory.decodeFile(source.path, BitmapFactory.Options().apply {
        inSampleSize = sample
    })
}

private fun videoFrame(source: File): Bitmap? {
    val retriever = MediaMetadataRetriever()
    try {
        retriever.setDataSource(source.path)
        return if (Build.VERSION.SDK_INT >= 27) {
            retriever.getScaledFrameAtTime(-1, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 384, 384)
        } else {
            retriever.frameAtTime
        }
    } finally {
        retriever.release()
    }
}
