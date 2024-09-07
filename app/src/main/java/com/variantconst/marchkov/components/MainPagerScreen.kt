package com.variantconst.marchkov.components

import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Code
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.accompanist.pager.ExperimentalPagerApi
import com.google.accompanist.pager.HorizontalPager
import com.google.accompanist.pager.HorizontalPagerIndicator
import com.google.accompanist.pager.rememberPagerState
import com.variantconst.marchkov.utils.Settings
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material.icons.Icons
import com.variantconst.marchkov.utils.ReservationManager
import com.variantconst.marchkov.utils.RideInfo
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.toArgb
import kotlin.math.absoluteValue
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlin.math.min

@RequiresApi(Build.VERSION_CODES.O)
@OptIn(ExperimentalPagerApi::class)
@Composable
fun MainPagerScreen(
    qrCodeBitmap: Bitmap?,
    reservationDetails: Map<String, Any>?,
    onLogout: () -> Unit,
    onToggleBusDirection: () -> Unit,
    onShowLogs: () -> Unit,
    currentPage: Int = 0,
    setPage: (Int) -> Unit,
    isReservationLoading: Boolean,
    onRefresh: suspend () -> Unit,
    reservationManager: ReservationManager,
    username: String,
    password: String
) {
    var reservationHistory by remember { mutableStateOf<List<RideInfo>?>(null) }
    var isHistoryLoading by remember { mutableStateOf(false) }

    // 在组件初始化时加载保存的历史记录
    LaunchedEffect(Unit) {
        reservationHistory = reservationManager.getRideInfoListFromSharedPreferences()
    }

    val pagerState = rememberPagerState(initialPage = currentPage)

    Column(
        modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)
    ) {
        HorizontalPager(
            count = 3,  // 增加到3个页面
            state = pagerState,
            modifier = Modifier.weight(1f)
        ) { page ->
            when (page) {
                0 -> {
                    if (isReservationLoading) {
                        LoadingScreen(message = "正在获取预约信息...")
                    } else {
                        DetailScreen(
                            qrCodeBitmap = qrCodeBitmap,
                            reservationDetails = reservationDetails,
                            onToggleBusDirection = onToggleBusDirection,
                            onRefresh = onRefresh
                        )
                    }
                }
                1 -> {
                    ReservationHistoryScreen(
                        reservationHistory = reservationHistory,
                        isLoading = isHistoryLoading,
                        onRefresh = {
                            isHistoryLoading = true
                            reservationManager.getReservationHistory(username, password) { success, response, rideInfoList ->
                                isHistoryLoading = false
                                if (success) {
                                    reservationHistory = rideInfoList
                                } else {
                                    // 显示错误消息
                                    reservationHistory = null
                                }
                            }
                        }
                    )
                }
                2 -> AdditionalActionsScreen(
                    onShowLogs = onShowLogs,
                    onLogout = onLogout
                )
            }
        }

        LaunchedEffect(pagerState.currentPage) {
            setPage(pagerState.currentPage)
        }

        HorizontalPagerIndicator(
            pagerState = pagerState,
            modifier = Modifier
                .align(Alignment.CenterHorizontally)
                .padding(16.dp),
            activeColor = MaterialTheme.colorScheme.primary,
            inactiveColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
        )
    }
}

@Composable
fun AdditionalActionsScreen(
    onShowLogs: () -> Unit,
    onLogout: () -> Unit
) {
    var visible by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val sharedPreferences: SharedPreferences = context.getSharedPreferences("user_prefs", android.content.Context.MODE_PRIVATE)
    val username = sharedPreferences.getString("username", "2301234567") ?: "2301234567"
    val realName = sharedPreferences.getString("realName", "马池口🐮🐴") ?: "马池口🐮🐴"
    val department = sharedPreferences.getString("department", "这个需要你自己衡量！") ?: "这个需要你自己衡量！"
    val scrollState = rememberScrollState()
    LaunchedEffect(Unit) {
        visible = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            UserInfoCard(
                username = username,
                realName = realName,
                department = department,
                onLogout = onLogout
            )

            SettingsScreen(
                initialPrevInterval = Settings.PREV_INTERVAL,
                initialNextInterval = Settings.NEXT_INTERVAL,
                initialCriticalTime = Settings.CRITICAL_TIME,
                onSettingsChanged = { prevInterval, nextInterval, criticalTime ->
                    Settings.updatePrevInterval(context, prevInterval)
                    Settings.updateNextInterval(context, nextInterval)
                    Settings.updateCriticalTime(context, criticalTime)
                },
            )

            ActionCard(
                icon = Icons.AutoMirrored.Filled.List,
                text = "查看日志",
                onClick = onShowLogs
            )

            Spacer(modifier = Modifier.height(8.dp))

            ActionCard(
                icon = Icons.Default.Code,
                text = "支持我们",
                onClick = {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/VariantConst/3-2-1-Marchkov/"))
                    context.startActivity(intent)
                }
            )
        }
    }
}

@Composable
fun UserInfoCard(
    username: String,
    realName: String,
    department: String,
    onLogout: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.AccountCircle,
                    contentDescription = "用户头像",
                    modifier = Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.width(16.dp))
                Text(
                    text = realName,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.weight(1f))
                IconButton(
                    onClick = onLogout,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ExitToApp,
                        contentDescription = "退出登录",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(32.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Business,
                        contentDescription = "部门",
                        modifier = Modifier.size(24.dp),
                        tint = MaterialTheme.colorScheme.secondary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = department,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Tag,
                        contentDescription = "用户名",
                        modifier = Modifier.size(24.dp),
                        tint = MaterialTheme.colorScheme.secondary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = username,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
        }
    }
}

@Composable
fun ActionCard(
    icon: ImageVector,
    text: String,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(24.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Row(
            modifier = Modifier
                .padding(24.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(16.dp))
            Text(
                text = text,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
fun ReservationHistoryScreen(
    reservationHistory: List<RideInfo>?,
    isLoading: Boolean,
    onRefresh: () -> Unit
) {
    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "预约历史",
                    style = MaterialTheme.typography.headlineMedium
                )
                reservationHistory?.let {
                    Text(
                        text = "共 ${it.size} 条有效预约",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
            Button(
                onClick = onRefresh,
                enabled = !isLoading
            ) {
                Text("刷新")
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))

        if (isLoading) {
            Box(modifier = Modifier.fillMaxWidth().height(200.dp)) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            }
        } else if (reservationHistory == null) {
            Text(
                "无法加载历史记录",
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        } else if (reservationHistory.isEmpty()) {
            Text(
                "暂无预约历史",
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        } else {
            // 添加乘车时间统计卡片
            RideTimeStatisticsCard(reservationHistory)
            
            Spacer(modifier = Modifier.height(16.dp))

            // 添加签到时间差统计卡片
            SignInTimeStatisticsCard(reservationHistory)

            Spacer(modifier = Modifier.height(16.dp))

            // 添加爽约分析卡片
            NoShowAnalysisCard(reservationHistory)
        }
    }
}

@Composable
fun SignInTimeStatisticsCard(rideInfoList: List<RideInfo>) {
    val signInTimeDifferences = calculateSignInTimeDifferences(rideInfoList)
    
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(300.dp)
            .padding(vertical = 8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "签到时间差统计",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(8.dp))
            SignInTimeStatisticsChart(signInTimeDifferences)
        }
    }
}

@Composable
fun SignInTimeStatisticsChart(signInTimeDifferences: List<Int>) {
    val sortedDifferences = signInTimeDifferences.sorted()
    val totalCount = sortedDifferences.size
    var lowerBound = 0
    var upperBound = 0
    var coveredCount = sortedDifferences.count { it == 0 }

    while (coveredCount.toFloat() / totalCount < 0.95) {
        lowerBound--
        upperBound++
        coveredCount = sortedDifferences.count { it in lowerBound..upperBound }
    }

    val trimmedDifferences = sortedDifferences.filter { it in lowerBound..upperBound }
    val frequencyMap = trimmedDifferences.groupingBy { it }.eachCount()
    val maxFrequency = frequencyMap.values.maxOrNull() ?: 0

    val primaryColor = MaterialTheme.colorScheme.primary

    Canvas(modifier = Modifier
        .fillMaxWidth()
        .height(200.dp)
    ) {
        val canvasWidth = size.width
        val canvasHeight = size.height
        val barWidth = canvasWidth / (upperBound - lowerBound + 3) // 给两边留一些空间
        
        // 绘制x轴
        drawLine(
            color = Color.Gray,
            start = Offset(0f, canvasHeight - 20f),
            end = Offset(canvasWidth, canvasHeight - 20f),
            strokeWidth = 2f
        )

        // 绘制横向虚线和y轴标签
        val yAxisSteps = 5
        for (i in 1..yAxisSteps) {
            val y = canvasHeight - 20f - (i.toFloat() / yAxisSteps) * (canvasHeight - 40f)
            drawLine(
                color = Color.LightGray,
                start = Offset(0f, y),
                end = Offset(canvasWidth, y),
                strokeWidth = 1f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 5f), 0f)
            )
            drawIntoCanvas { canvas ->
                val paint = Paint().apply {
                    color = Color.Gray.toArgb()
                    textAlign = Paint.Align.RIGHT
                    textSize = 24f
                }
                canvas.nativeCanvas.drawText(
                    "${(i.toFloat() / yAxisSteps * maxFrequency).toInt()}",
                    40f,
                    y - 5f,
                    paint
                )
            }
        }

        // 绘制柱状图
        frequencyMap.forEach { (difference, frequency) ->
            val x = (difference - lowerBound + 1) * barWidth
            val barHeight = (frequency.toFloat() / maxFrequency) * (canvasHeight - 40f)
            
            drawRect(
                color = primaryColor,
                topLeft = Offset(x, canvasHeight - 20f - barHeight),
                size = Size(barWidth * 0.8f, barHeight),
                alpha = 0.7f
            )
        }

        // 绘制x轴刻度
        val paint = Paint().apply {
            color = Color.Black.toArgb()
            textAlign = Paint.Align.CENTER
            textSize = 24f
        }

        for (diff in lowerBound..upperBound step 5) {
            val x = (diff - lowerBound + 1) * barWidth + barWidth / 2
            drawIntoCanvas { canvas ->
                canvas.nativeCanvas.drawText(
                    "$diff",
                    x,
                    canvasHeight,
                    paint
                )
            }
        }
    }
}

fun calculateSignInTimeDifferences(rideInfoList: List<RideInfo>): List<Int> {
    val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
    val appointmentFormat = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())

    return rideInfoList
        .filter { it.appointmentSignTime?.isNotBlank() == true }
        .mapNotNull { rideInfo ->
            try {
                val signInTime = dateFormat.parse(rideInfo.appointmentSignTime!!)
                val appointmentTime = appointmentFormat.parse(rideInfo.appointmentTime.trim())
                
                if (signInTime != null && appointmentTime != null) {
                    ((signInTime.time - appointmentTime.time) / (60 * 1000)).toInt()
                } else {
                    null
                }
            } catch (e: Exception) {
                null
            }
        }
}

@Composable
fun RideTimeStatisticsCard(rideInfoList: List<RideInfo>) {
    val toYanyuanColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f)
    val toChangpingColor = MaterialTheme.colorScheme.secondary.copy(alpha = 0.7f)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(390.dp)
            .padding(vertical = 8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "乘车时间统计",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(8.dp))
            RideTimeStatisticsChart(rideInfoList, toYanyuanColor, toChangpingColor)
            Spacer(modifier = Modifier.height(8.dp))  // 减小图表和图例之间的间距
            RideTimeLegend(toYanyuanColor, toChangpingColor)
        }
    }
}

@Composable
fun RideTimeStatisticsChart(
    rideInfoList: List<RideInfo>,
    toYanyuanColor: Color,
    toChangpingColor: Color
) {
    val toYanyuanCounts = IntArray(24)
    val toChangpingCounts = IntArray(24)

    // 统计各时间段的乘车次数
    rideInfoList.forEach { ride ->
        val hour = ride.appointmentTime.substring(11, 13).toInt()
        if (ride.resourceName.indexOf("新") < ride.resourceName.indexOf("燕")) {
            toYanyuanCounts[hour]++
        } else {
            toChangpingCounts[hour]++
        }
    }

    val maxCount = (toYanyuanCounts.maxOrNull() ?: 0).coerceAtLeast(toChangpingCounts.maxOrNull() ?: 0)

    Canvas(modifier = Modifier
        .fillMaxWidth()
        .height(280.dp)
        .padding(start = 20.dp, end = 8.dp, top = 16.dp, bottom = 24.dp)
    ) {
        val canvasWidth = size.width
        val canvasHeight = size.height
        val barWidth = canvasWidth / 17  // 6点到22点，共17个小时
        val centerY = canvasHeight / 2

        val paint = Paint().apply {
            textSize = 24f
            typeface = Typeface.DEFAULT
            textAlign = Paint.Align.RIGHT
        }

        // 绘制y轴刻度和标签
        val yAxisSteps = 2
        val maxYValue = maxCount / 2
        for (i in -yAxisSteps..yAxisSteps) {
            val y = centerY - (centerY * i / yAxisSteps)
            // 绘制水平网格线
            drawLine(
                color = Color.LightGray,
                start = Offset(-50f, y),
                end = Offset(canvasWidth, y),
                strokeWidth = 1f
            )
            drawIntoCanvas { canvas ->
                canvas.nativeCanvas.drawText(
                    "${(maxYValue * i / yAxisSteps).absoluteValue}",
                    -25f,
                    y - 4f,  // 将y轴标签向上移动
                    paint
                )
            }
        }

        // 绘制x轴
        drawLine(
            color = Color.LightGray,
            start = Offset(0f, canvasHeight),
            end = Offset(canvasWidth, canvasHeight),
            strokeWidth = 1f
        )

        for (hour in 6..22) {
            val x = (hour - 6) * barWidth
            val toYanyuanHeight = (toYanyuanCounts[hour] / maxCount.toFloat()) * centerY
            val toChangpingHeight = (toChangpingCounts[hour] / maxCount.toFloat()) * centerY

            // 绘制去燕园的柱形（下半部分）
            drawRoundRect(
                color = toYanyuanColor,
                topLeft = Offset(x + barWidth * 0.3f, centerY),
                size = Size(barWidth * 0.4f, toYanyuanHeight),
                cornerRadius = CornerRadius(0.dp.toPx(), 4.dp.toPx())  // 只在底部有圆角
            )

            // 绘制回昌平的柱形（上半部分）
            drawRoundRect(
                color = toChangpingColor,
                topLeft = Offset(x + barWidth * 0.3f, centerY - toChangpingHeight),
                size = Size(barWidth * 0.4f, toChangpingHeight),
                cornerRadius = CornerRadius(4.dp.toPx(), 0.dp.toPx())  // 只在顶部有圆角
            )

            // 每隔4小时绘制一次x轴标签
            if ((hour - 6) % 4 == 0 || hour == 22) {
                drawIntoCanvas { canvas ->
                    canvas.nativeCanvas.drawText(
                        String.format("%02d:00", hour),
                        x + barWidth / 2 + 5f,  // 将x轴标签向右移动
                        canvasHeight + 30f,
                        paint.apply { textAlign = Paint.Align.CENTER }
                    )
                }
                // 绘制垂直虚线，延长至超过横线
                drawLine(
                    color = Color.LightGray,
                    start = Offset(x, -20f),  // 向上延伸
                    end = Offset(x, canvasHeight + 10f),  // 向下延伸
                    strokeWidth = 1f,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f, 5f), 0f)
                )
            }
        }
    }
}

@Composable
fun RideTimeLegend(toYanyuanColor: Color, toChangpingColor: Color) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(toChangpingColor, CircleShape)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text("回昌平", style = MaterialTheme.typography.labelSmall)
        }
        Spacer(modifier = Modifier.width(16.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(toYanyuanColor, CircleShape)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text("去燕园", style = MaterialTheme.typography.labelSmall)
        }
    }
}

// 新增爽约分析卡片组件
@Composable
fun NoShowAnalysisCard(rideInfoList: List<RideInfo>) {
    val validRideCount = rideInfoList.size
    val noShowCount = rideInfoList.count { it.statusName == "已预约" }
    val showUpCount = validRideCount - noShowCount
    val noShowRate = noShowCount.toFloat() / validRideCount

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(300.dp)
            .padding(vertical = 8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "爽约分析",
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                text = if (noShowRate > 0.3) {
                    "你爽约了${validRideCount}次预约中的${noShowCount}次。咕咕咕？"
                } else {
                    "你在${validRideCount}次预约中只爽约了${noShowCount}次。很有精神！"
                },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                NoShowPieChart(showUpCount, noShowCount)
                NoShowLegend()
            }
        }
    }
}

@Composable
fun NoShowPieChart(showUpCount: Int, noShowCount: Int) {
    val showUpColor = MaterialTheme.colorScheme.primary
    val noShowColor = MaterialTheme.colorScheme.error

    Canvas(modifier = Modifier.size(150.dp)) {
        val canvasWidth = size.width
        val canvasHeight = size.height
        val radius = min(canvasWidth, canvasHeight) / 2 * 0.8f
        val center = Offset(canvasWidth / 2, canvasHeight / 2)
        
        val total = showUpCount + noShowCount
        val showUpAngle = 360f * showUpCount / total
        val noShowAngle = 360f * noShowCount / total

        drawArc(
            color = showUpColor,
            startAngle = 0f,
            sweepAngle = showUpAngle,
            useCenter = true,
            topLeft = Offset(center.x - radius, center.y - radius),
            size = Size(radius * 2, radius * 2)
        )

        drawArc(
            color = noShowColor,
            startAngle = showUpAngle,
            sweepAngle = noShowAngle,
            useCenter = true,
            topLeft = Offset(center.x - radius, center.y - radius),
            size = Size(radius * 2, radius * 2)
        )

        // 添加白色边框
        drawCircle(
            color = Color.White,
            radius = radius,
            center = center,
            style = Stroke(width = 2.dp.toPx())
        )
    }
}

@Composable
fun NoShowLegend() {
    Column(
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.Start
    ) {
        LegendItem(
            color = MaterialTheme.colorScheme.primary,
            text = "已签到"
        )
        Spacer(modifier = Modifier.height(8.dp))
        LegendItem(
            color = MaterialTheme.colorScheme.error,
            text = "已爽约"
        )
    }
}

@Composable
fun LegendItem(color: Color, text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(16.dp)
                .background(color, shape = CircleShape)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}
