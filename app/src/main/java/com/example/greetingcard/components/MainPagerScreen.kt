package com.example.greetingcard.components

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import com.example.greetingcard.ActionCard
import com.example.greetingcard.DetailScreen
import com.example.greetingcard.LoadingScreen
import com.google.accompanist.pager.ExperimentalPagerApi
import com.google.accompanist.pager.HorizontalPager
import com.google.accompanist.pager.HorizontalPagerIndicator
import com.google.accompanist.pager.rememberPagerState

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
        modifier = Modifier.fillMaxSize()
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
                .padding(top = 4.dp)
                .padding(bottom = 12.dp),
        )
    }
}

@Composable
fun AdditionalActionsScreen(
    onShowLogs: () -> Unit,
    onEditSettings: () -> Unit,
    onLogout: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        ActionCard(
            icon = Icons.AutoMirrored.Filled.List,
            text = "查看日志",
            gradient = Brush.horizontalGradient(
                colors = listOf(
                    MaterialTheme.colorScheme.primary,
                    MaterialTheme.colorScheme.primary.copy(alpha = 0.7f)
                )
            ),
            onClick = onShowLogs
        )

        Spacer(modifier = Modifier.height(16.dp))

        ActionCard(
            icon = Icons.Default.Settings,
            text = "高级设置",
            gradient = Brush.horizontalGradient(
                colors = listOf(
                    MaterialTheme.colorScheme.secondary,
                    MaterialTheme.colorScheme.secondary.copy(alpha = 0.7f)
                )
            ),
            onClick = onEditSettings
        )

        Spacer(modifier = Modifier.height(16.dp))

        ActionCard(
            icon = Icons.AutoMirrored.Filled.ExitToApp,
            text = "退出登录",
            gradient = Brush.horizontalGradient(
                colors = listOf(
                    MaterialTheme.colorScheme.error,
                    MaterialTheme.colorScheme.error.copy(alpha = 0.7f)
                )
            ),
            onClick = onLogout
        )
    }
}