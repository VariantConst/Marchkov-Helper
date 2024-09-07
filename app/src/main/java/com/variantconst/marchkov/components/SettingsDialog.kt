package com.variantconst.marchkov.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.ExperimentalMaterial3Api
import com.variantconst.marchkov.utils.Settings

@Composable
fun SettingsScreen(
    initialPrevInterval: Int,
    initialNextInterval: Int,
    initialCriticalTime: Int,
    onSettingsChanged: (Int, Int, Int) -> Unit
) {
    var prevInterval by remember { mutableIntStateOf(initialPrevInterval) }
    var nextInterval by remember { mutableIntStateOf(initialNextInterval) }
    var criticalTime by remember { mutableIntStateOf(initialCriticalTime) }
    var resetTrigger by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 24.dp)
    ) {
        AdvancedSettingsCard(
            prevInterval = prevInterval,
            nextInterval = nextInterval,
            criticalTime = criticalTime,
            onPrevIntervalChange = {
                prevInterval = it
                onSettingsChanged(it, nextInterval, criticalTime)
            },
            onNextIntervalChange = {
                nextInterval = it
                onSettingsChanged(prevInterval, it, criticalTime)
            },
            onCriticalTimeChange = {
                criticalTime = it
                onSettingsChanged(prevInterval, nextInterval, it)
            },
            onReset = {
                prevInterval = Settings.DEFAULT_PREV_INTERVAL
                nextInterval = Settings.DEFAULT_NEXT_INTERVAL
                criticalTime = Settings.DEFAULT_CRITICAL_TIME
                onSettingsChanged(prevInterval, nextInterval, criticalTime)
                resetTrigger = !resetTrigger  // 触发重组
            },
            resetTrigger = resetTrigger
        )
    }
}

@Composable
fun AdvancedSettingsCard(
    prevInterval: Int,
    nextInterval: Int,
    criticalTime: Int,
    onPrevIntervalChange: (Int) -> Unit,
    onNextIntervalChange: (Int) -> Unit,
    onCriticalTimeChange: (Int) -> Unit,
    onReset: () -> Unit,
    resetTrigger: Boolean
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
    ) {
        Column(
            modifier = Modifier
                .padding(24.dp)
                .fillMaxWidth()
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "高级设置",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                
                IconButton(onClick = onReset) {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = "复位设置",
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            SettingSlider(
                key = "prevInterval$resetTrigger",
                label = "上一时间间隔",
                value = prevInterval,
                onValueChange = onPrevIntervalChange,
                valueRange = 1f..114f,
                icon = Icons.AutoMirrored.Filled.ArrowBack,
                snapValues = (1..11).map { it * 10f }.toSet() + setOf(1f, 114f),
                valueRepresentation = { "${it.toInt()}分钟" }
            )

            Spacer(modifier = Modifier.height(20.dp))

            SettingSlider(
                key = "nextInterval$resetTrigger",
                label = "下一时间间隔",
                value = nextInterval,
                onValueChange = onNextIntervalChange,
                valueRange = 1f..514f,
                icon = Icons.AutoMirrored.Filled.ArrowForward,
                snapValues = (1..51).map { it * 10f }.toSet() + setOf(1f, 514f),
                valueRepresentation = { "${it.toInt()}分钟" }
            )

            Spacer(modifier = Modifier.height(20.dp))

            SettingSlider(
                key = "criticalTime$resetTrigger",
                label = "临界时间",
                value = criticalTime,
                onValueChange = onCriticalTimeChange,
                valueRange = 6f..22f,
                icon = Icons.Default.Timer,
                snapValues = (6..22).map { it.toFloat() }.toSet(),
                valueRepresentation = { "${it.toInt()}:00" }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingSlider(
    key: Any,
    label: String,
    value: Int,
    onValueChange: (Int) -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    icon: ImageVector,
    snapValues: Set<Float>,
    valueRepresentation: (Float) -> String
) {
    key(key) {
        var sliderPosition by remember { mutableFloatStateOf(value.toFloat()) }

        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = valueRepresentation(sliderPosition),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            Slider(
                value = sliderPosition,
                onValueChange = { newValue ->
                    val snappedValue = snapValues.minByOrNull { kotlin.math.abs(it - newValue) } ?: newValue
                    sliderPosition = snappedValue
                    onValueChange(snappedValue.toInt())
                },
                valueRange = valueRange,
                steps = 0,
                modifier = Modifier
                    .padding(top = 8.dp)
                    .fillMaxWidth(),
                colors = SliderDefaults.colors(
                    thumbColor = MaterialTheme.colorScheme.primary,
                    activeTrackColor = MaterialTheme.colorScheme.primary,
                    inactiveTrackColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f)
                )
            )
        }
    }
}