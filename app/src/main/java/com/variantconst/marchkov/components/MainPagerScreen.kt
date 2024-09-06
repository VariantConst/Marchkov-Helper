package com.variantconst.marchkov.components

import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
    var reservationHistory by remember { mutableStateOf<String?>(null) }
    var isHistoryLoading by remember { mutableStateOf(false) }

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
                1 -> AdditionalActionsScreen(
                    onShowLogs = onShowLogs,
                    onLogout = onLogout
                )
                2 -> {
                    ReservationHistoryScreen(
                        reservationHistory = reservationHistory,
                        isLoading = isHistoryLoading,
                        onRefresh = {
                            isHistoryLoading = true
                            reservationManager.getReservationHistory(username, password) { success, response ->
                                isHistoryLoading = false
                                if (success) {
                                    reservationHistory = response
                                } else {
                                    // 显示错误消息
                                    reservationHistory = "加载失败: $response"
                                }
                            }
                        }
                    )
                }
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
    reservationHistory: String?,
    isLoading: Boolean,
    onRefresh: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            text = "预约历史",
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        if (isLoading) {
            CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
        } else if (reservationHistory == null) {
            Button(onClick = onRefresh) {
                Text("加载历史记录")
            }
        } else {
            Text(
                text = reservationHistory,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.verticalScroll(rememberScrollState())
            )
        }
    }
}

@Composable
fun ReservationHistoryItem(reservation: Map<String, Any>) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = reservation["resource_name"] as? String ?: "未知班车",
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                text = reservation["appointment_tim"] as? String ?: "未知时间",
                style = MaterialTheme.typography.bodyMedium
            )
            Text(
                text = "状态: ${reservation["status_name"] as? String ?: "未知状态"}",
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}
