package com.variantconst.marchkov.utils

import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.variantconst.marchkov.utils.BusInfo
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

fun generateQRCode(content: String): Bitmap {
    val width = 300
    val height = 300
    val writer = QRCodeWriter()
    val bitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, width, height)

    // Find the boundaries of the QR code content to remove the white border
    var startX = width
    var startY = height
    var endX = 0
    var endY = 0
    for (x in 0 until width) {
        for (y in 0 until height) {
            if (bitMatrix[x, y]) {
                if (x < startX) startX = x
                if (y < startY) startY = y
                if (x > endX) endX = x
                if (y > endY) endY = y
            }
        }
    }

    // Calculate the actual size of the QR code
    val actualWidth = endX - startX + 1
    val actualHeight = endY - startY + 1

    // Create a Bitmap with the actual size and transparent background
    val bitmap = Bitmap.createBitmap(actualWidth, actualHeight, Bitmap.Config.ARGB_8888)
    for (x in 0 until actualWidth) {
        for (y in 0 until actualHeight) {
            bitmap.setPixel(x, y, if (bitMatrix[x + startX, y + startY]) android.graphics.Color.BLACK else android.graphics.Color.TRANSPARENT)
        }
    }

    return bitmap
}

@RequiresApi(Build.VERSION_CODES.O)
fun getInitialDirection(): Boolean {
    val currentTime = LocalDateTime.now(ZoneId.of("Asia/Shanghai")).hour
    return currentTime < Settings.CRITICAL_TIME
}

@RequiresApi(Build.VERSION_CODES.O)
fun chooseBus(resourceList: List<*>?, isToYanyuan: Boolean): BusInfo {
    var chosenResourceId = 0
    var chosenPeriod = 0
    var startTime = ""
    if (resourceList != null) {
        val currentTime = LocalDateTime.now(ZoneId.of("Asia/Shanghai"))
        for (bus in resourceList) {
            if (bus is Map<*, *>) {
                val resourceIdStr = bus["id"] as Double
                val resourceId = resourceIdStr.toInt()
                val routeName = bus["name"] as String

                if (!(resourceId in listOf(2, 4) && isToYanyuan || resourceId in listOf(5, 6, 7) && !isToYanyuan)) {
                    continue
                }
                Log.v("MyTag", "resourceId is $resourceId, routeName is $routeName")
                val periods = (bus["table"] as Map<String, List<Map<String, Any>>>).values.first()
                for (period in periods) {
                    val timeId = (period["time_id"] as Double).toInt()
                    val date = period["date"] as String
                    startTime = period["yaxis"] as String
                    val margin = ((period["row"] as? Map<*, *>)?.get("margin") as? Double)?.toInt() ?: 0
                    if (margin == 0) {
                        continue
                    }

                    val awareDateTime = LocalDateTime.parse(
                        "$date $startTime",
                        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
                    )
                    val duration = Duration.between(currentTime, awareDateTime)
                    val timeDiffWithSign = duration.seconds.toDouble() / 60.0
                    val hasExpiredBus = -Settings.PREV_INTERVAL < timeDiffWithSign && timeDiffWithSign <= 0
                    val hasFutureBus = 0 < timeDiffWithSign && timeDiffWithSign < Settings.NEXT_INTERVAL

                    if (hasExpiredBus || hasFutureBus) {
                        chosenResourceId = resourceId
                        chosenPeriod = timeId
                        Log.v("MyTag", "chosenResourceId is $chosenResourceId, chosenPeriod is $chosenPeriod, startTime is $startTime, currentTime is $currentTime, awareDateTime is $awareDateTime, timeDiffWithSign is $timeDiffWithSign")
                        return BusInfo(chosenResourceId, routeName, startTime, hasExpiredBus, chosenPeriod)
                    }
                }
            }
        }
    }
    return BusInfo(chosenResourceId, "", startTime, false, chosenPeriod)
}

fun formatMap(map: Map<String, Any>): String {
    return map.entries.joinToString(", ", "{", "}") { (k, v) ->
        "\"$k\": ${formatValue(v)}"
    }
}

fun formatValue(value: Any?): String {
    return when (value) {
        is Map<*, *> -> formatMap(value as Map<String, Any>)
        is List<*> -> value.joinToString(", ", "[", "]") { formatValue(it) }
        is String -> "\"$value\""
        is Number, is Boolean -> value.toString()
        null -> "null"
        else -> "\"$value\""
    }
}