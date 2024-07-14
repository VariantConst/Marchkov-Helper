package com.example.greetingcard

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandIn
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.IntOffset


@Composable
fun WelcomeHeader(creatorName: String) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 0.dp) // 减小垂直padding
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn() + expandIn(expandFrom = Alignment.Center)
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp) // 稍微减小图标大小
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primaryContainer)
                    .padding(10.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.AccountCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.size(36.dp)
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp)) // 减小水平间距

        Column(verticalArrangement = Arrangement.Center) { // 使用verticalArrangement来控制垂直对齐
            AnimatedVisibility(
                visible = visible,
                enter = fadeIn() + slideIn(initialOffset = { IntOffset(0, -20) })
            ) {
                Text(
                    text = "欢迎回来",
                    style = MaterialTheme.typography.titleMedium, // 减小字体大小
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
            }

            Spacer(modifier = Modifier.height(2.dp)) // 减小文字之间的间距

            AnimatedVisibility(
                visible = visible,
                enter = fadeIn() + slideIn(initialOffset = { IntOffset(0, 20) })
            ) {
                Text(
                    text = creatorName,
                    style = MaterialTheme.typography.headlineSmall.copy( // 减小字体大小
                        fontWeight = FontWeight.Bold
                    ),
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

@Composable
fun ReservationCard(
    isTemp: Boolean,
    resourceName: String,
    period: String,
    qrCodeBitmap: Bitmap?
) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(animationSpec = tween(durationMillis = 500)) +
                expandVertically(animationSpec = tween(durationMillis = 500)),
        exit = fadeOut(animationSpec = tween(durationMillis = 300)) +
                shrinkVertically(animationSpec = tween(durationMillis = 300))
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    ReservationDetailItem("发车时间", period, Icons.Default.Schedule, Modifier.weight(1f))
                    ReservationDetailItem("预约类型", if (isTemp) "临时码" else "乘车码", Icons.Default.QrCode, Modifier.weight(1f))
                }
                ReservationDetailItem("班车路线", resourceName, Icons.Default.DirectionsBus, Modifier.fillMaxWidth())

                qrCodeBitmap?.let { bitmap ->
                    QrCodeSection(bitmap)
                }
            }
        }
    }
}

@Composable
fun ReservationDetailItem(label: String, value: String, icon: ImageVector, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(32.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    }
}


@Composable
fun QrCodeSection(bitmap: Bitmap) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "QR Code",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Fit
        )
    }
}

@Composable
fun ToggleDirectionButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    var isRotated by remember { mutableStateOf(false) }
    val rotation by animateFloatAsState(
        targetValue = if (isRotated) 180f else 0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        )
    )
    val scale by animateFloatAsState(
        targetValue = if (isRotated) 1.05f else 1f,
        animationSpec = tween(durationMillis = 200)
    )

    Button(
        onClick = {
            isRotated = !isRotated
            onClick()
        },
        modifier = modifier
            .fillMaxWidth()
            .scale(scale)
            .padding(horizontal = 8.dp)
            .heightIn(min = 56.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
            contentColor = MaterialTheme.colorScheme.onPrimaryContainer
        ),
        contentPadding = PaddingValues(16.dp),
        shape = RoundedCornerShape(16.dp),
        elevation = ButtonDefaults.elevatedButtonElevation(
            defaultElevation = 4.dp,
            pressedElevation = 8.dp
        )
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.SwapVert,
                contentDescription = "切换方向",
                modifier = Modifier
                    .size(28.dp)
                    .rotate(rotation),
                tint = MaterialTheme.colorScheme.onPrimaryContainer
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                "乘坐反向班车",
                color = MaterialTheme.colorScheme.onPrimaryContainer,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold
                )
            )
        }
    }
}



@Composable
fun ErrorScreen(message: String, onRetry: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(text = "Error: $message", color = MaterialTheme.colorScheme.error, fontSize = 20.sp)
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = onRetry) {
                Text("Retry")
            }
        }
    }
}



@Composable
fun ActionCard(
    icon: ImageVector,
    text: String,
    gradient: Brush,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(60.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Box(
            modifier = Modifier
                .background(gradient)
                .fillMaxSize()
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    icon,
                    contentDescription = text,
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text,
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(),
        content = content
    )
}
