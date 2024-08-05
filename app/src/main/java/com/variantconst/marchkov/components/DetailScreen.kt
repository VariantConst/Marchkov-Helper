package com.variantconst.marchkov.components

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.variantconst.marchkov.ReservationCard
import com.variantconst.marchkov.ToggleDirectionButton
import com.variantconst.marchkov.WelcomeHeader

import androidx.compose.foundation.layout.Box
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterialApi::class)
@Composable
fun DetailScreen(
    qrCodeBitmap: Bitmap?,
    reservationDetails: Map<String, Any>?,
    onToggleBusDirection: () -> Unit,
    onRefresh: suspend () -> Unit
) {
    var showSnackbar by remember { mutableStateOf(false) }
    var snackbarMessage by remember { mutableStateOf("") }

    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }

    val pullRefreshState = rememberPullRefreshState(refreshing, {
        scope.launch {
            refreshing = true
            try {
                onRefresh()
                snackbarMessage = "刷新成功"
            } catch (e: Exception) {
                snackbarMessage = "刷新失败: ${e.message}"
            } finally {
                refreshing = false
                showSnackbar = true
            }
        }
    })

    Box(
        modifier = Modifier
            .fillMaxSize()
            .pullRefresh(pullRefreshState)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 80.dp) // 为底部按钮留出空间
        ) {
            if (reservationDetails != null) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState())
                        .padding(24.dp)
                        .align(Alignment.Center) // 使内容垂直居中
                ) {
                    val creatorName = reservationDetails["creator_name"] as? String ?: "访客"
                    var resourceName = reservationDetails["resource_name"] as? String ?: "未知路线"
                    var period = reservationDetails["start_time"] as? String ?: "未知时间"
                    val isTemp = reservationDetails["is_temp"] as? Boolean ?: false

                    resourceName = resourceName.replace("→", "➔")
                    period = period.replace("\n", "")

                    WelcomeHeader(creatorName)

                    Spacer(modifier = Modifier.height(12.dp))

                    ReservationCard(
                        isTemp = isTemp,
                        resourceName = resourceName,
                        period = period,
                        qrCodeBitmap = qrCodeBitmap
                    )

                    Spacer(modifier = Modifier.height(12.dp))
                }
            } else {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    NoBusAvailableMessage()
                }
            }
        }

        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 16.dp)
        ) {
            ToggleDirectionButton(
                onClick = onToggleBusDirection,
                modifier = Modifier
                    .padding(horizontal = 24.dp)
            )
        }

        PullRefreshIndicator(refreshing, pullRefreshState, Modifier.align(Alignment.TopCenter))

        if (showSnackbar) {
            LaunchedEffect(showSnackbar) {
                delay(2000)
                showSnackbar = false
            }
            Snackbar(
                modifier = Modifier
                    .padding(16.dp)
                    .align(Alignment.BottomCenter)
                    .defaultMinSize(minWidth = 150.dp),
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            ) {
                Text(snackbarMessage, color = MaterialTheme.colorScheme.onPrimary)
            }
        }
    }
}

@Composable
fun NoBusAvailableMessage() {
    var visible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        visible = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(animationSpec = tween(durationMillis = 500)) +
                    expandVertically(animationSpec = tween(durationMillis = 500))
        ) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                shape = RoundedCornerShape(16.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Filled.Info,
                        contentDescription = "信息图标",
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(48.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "当前方向无车可坐",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.error
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "请尝试切换方向或稍后再试",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                }
            }
        }
    }
}