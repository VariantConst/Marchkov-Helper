package com.example.greetingcard.components

import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.accompanist.pager.ExperimentalPagerApi
import com.google.accompanist.pager.HorizontalPager
import com.google.accompanist.pager.HorizontalPagerIndicator
import com.google.accompanist.pager.rememberPagerState
import kotlinx.coroutines.launch

@OptIn(ExperimentalPagerApi::class)
@Composable
fun MainPagerScreen(
    qrCodeBitmap: Bitmap?,
    reservationDetails: Map<String, Any>?,
    onLogout: () -> Unit,
    onToggleBusDirection: () -> Unit,
    onShowLogs: () -> Unit,
    onEditSettings: () -> Unit,
    currentPage: Int = 0,
    setPage: (Int) -> Unit,
    isReservationLoading: Boolean
) {
    val pagerState = rememberPagerState(initialPage = currentPage)

    Column(
        modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)
    ) {
        HorizontalPager(
            count = 2,
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
                        )
                    }
                }
                1 -> AdditionalActionsScreen(
                    onShowLogs = onShowLogs,
                    onEditSettings = onEditSettings,
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
    onEditSettings: () -> Unit,
    onLogout: () -> Unit
) {
    var visible by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        visible = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            SectionTitle(text = "更多选项")

            AnimatedActionCard(
                icon = Icons.AutoMirrored.Filled.List,
                text = "查看日志",
                description = "查看系统运行日志",
                gradient = Brush.linearGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.primary,
                        MaterialTheme.colorScheme.tertiary
                    )
                ),
                onClick = { coroutineScope.launch { onShowLogs() } },
                visible = visible,
                delay = 0
            )

            AnimatedActionCard(
                icon = Icons.Default.Settings,
                text = "高级设置",
                description = "不懂啥意思就别改",
                gradient = Brush.linearGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.secondary,
                        MaterialTheme.colorScheme.primaryContainer
                    )
                ),
                onClick = { coroutineScope.launch { onEditSettings() } },
                visible = visible,
                delay = 100
            )

            AnimatedActionCard(
                icon = Icons.Default.Code,
                text = "支持我们",
                description = "访问我们的 GitHub 项目",
                gradient = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF24292E).copy(alpha = 0.5f),
                        Color(0xFF1A1E21).copy(alpha = 0.7f)
                    )
                ),
                onClick = {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/VariantConst/3-2-1-Marchkov/"))
                    context.startActivity(intent)
                },
                visible = visible,
                delay = 200
            )

            AnimatedActionCard(
                icon = Icons.AutoMirrored.Filled.ExitToApp,
                text = "退出登录",
                description = "安全退出当前账号",
                gradient = Brush.linearGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.error,
                        MaterialTheme.colorScheme.errorContainer
                    )
                ),
                onClick = { coroutineScope.launch { onLogout() } },
                visible = visible,
                delay = 300
            )
        }
    }
}

@Composable
fun SectionTitle(text: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 24.dp)
    ) {
        Column {
            Text(
                text = text,
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.5.sp
                ),
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            Divider(
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f),
                thickness = 2.dp,
                modifier = Modifier.width(110.dp)
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnimatedActionCard(
    icon: ImageVector,
    text: String,
    description: String,
    gradient: Brush,
    onClick: () -> Unit,
    visible: Boolean,
    delay: Int
) {
    val transition = updateTransition(targetState = visible, label = "cardTransition")

    val scale by transition.animateFloat(
        transitionSpec = { tween(durationMillis = 300, delayMillis = delay) },
        label = "scaleTransition"
    ) { if (it) 1f else 0.8f }

    val alpha by transition.animateFloat(
        transitionSpec = { tween(durationMillis = 300, delayMillis = delay) },
        label = "alphaTransition"
    ) { if (it) 1f else 0f }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(100.dp)
            .padding(vertical = 8.dp)
            .scale(scale)
            .alpha(alpha)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(gradient)
                .padding(16.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(40.dp)
                )
                Column {
                    Text(
                        text = text,
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = description,
                        color = Color.White.copy(alpha = 0.8f),
                        fontSize = 14.sp
                    )
                }
            }
        }
    }
}