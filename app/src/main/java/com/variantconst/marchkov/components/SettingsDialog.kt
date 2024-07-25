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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(vertical = 16.dp)
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
            }
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
    onCriticalTimeChange: (Int) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth()
        ) {
            Text(
                text = "高级设置",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            SettingSlider(
                label = "上一时间间隔",
                value = prevInterval,
                onValueChange = onPrevIntervalChange,
                valueRange = 1f..114f,
                icon = Icons.AutoMirrored.Filled.ArrowBack,
                snapValues = (1..11).map { it * 10f }.toSet() + setOf(1f, 114f),
                valueRepresentation = { "${it.toInt()}分钟" }
            )

            SettingSlider(
                label = "下一时间间隔",
                value = nextInterval,
                onValueChange = onNextIntervalChange,
                valueRange = 1f..514f,
                icon = Icons.AutoMirrored.Filled.ArrowForward,
                snapValues = (1..51).map { it * 10f }.toSet() + setOf(1f, 514f),
                valueRepresentation = { "${it.toInt()}分钟" }
            )

            SettingSlider(
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

@Composable
private fun SettingSlider(
    label: String,
    value: Int,
    onValueChange: (Int) -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    icon: ImageVector,
    snapValues: Set<Float>,
    valueRepresentation: (Float) -> String
) {
    var sliderPosition by remember { mutableFloatStateOf(value.toFloat()) }

    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
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
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = valueRepresentation(sliderPosition),
                style = MaterialTheme.typography.bodyLarge,
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
            steps = (valueRange.endInclusive - valueRange.start).toInt() - 1,
            modifier = Modifier.padding(top = 8.dp),
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.primary,
                activeTrackColor = MaterialTheme.colorScheme.primary,
                inactiveTrackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
            )
        )
    }
}