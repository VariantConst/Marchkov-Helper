package com.example.greetingcard.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties

@Composable
fun SettingsDialog(
    onDismiss: () -> Unit,
    onSave: (Int, Int, Int) -> Unit,
    initialPrevInterval: Int,
    initialNextInterval: Int,
    initialCriticalTime: Int
) {
    var prevInterval by remember { mutableStateOf(initialPrevInterval.toString()) }
    var nextInterval by remember { mutableStateOf(initialNextInterval.toString()) }
    var criticalTime by remember { mutableStateOf(initialCriticalTime.toString()) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.5f))
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Card(
                modifier = Modifier
                    .fillMaxWidth(0.9f)
                    .animateContentSize(
                        animationSpec = spring(
                            dampingRatio = Spring.DampingRatioMediumBouncy,
                            stiffness = Spring.StiffnessLow
                        )
                    ),
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    DialogHeader(title = "高级设置")
                    EnhancedSettingField(
                        label = "上一时间间隔",
                        value = prevInterval,
                        onValueChange = { prevInterval = it },
                        icon = Icons.AutoMirrored.Filled.ArrowBack
                    )
                    EnhancedSettingField(
                        label = "下一时间间隔",
                        value = nextInterval,
                        onValueChange = { nextInterval = it },
                        icon = Icons.AutoMirrored.Filled.ArrowForward
                    )
                    EnhancedSettingField(
                        label = "临界时间",
                        value = criticalTime,
                        onValueChange = { criticalTime = it },
                        icon = Icons.Default.Timer
                    )
                    DialogActions(
                        onDismiss = onDismiss,
                        onSave = {
                            onSave(
                                prevInterval.toIntOrNull() ?: initialPrevInterval,
                                nextInterval.toIntOrNull() ?: initialNextInterval,
                                criticalTime.toIntOrNull() ?: initialCriticalTime
                            )
                            onDismiss()
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun DialogHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.headlineMedium.copy(
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        ),
        modifier = Modifier.padding(bottom = 8.dp)
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EnhancedSettingField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    icon: ImageVector
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        leadingIcon = {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(0.dp)),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MaterialTheme.colorScheme.primary,
            unfocusedBorderColor = MaterialTheme.colorScheme.outline,
            focusedLabelColor = MaterialTheme.colorScheme.primary,
            cursorColor = MaterialTheme.colorScheme.primary
        ),
        textStyle = MaterialTheme.typography.bodyLarge
    )
}

@Composable
private fun DialogActions(onDismiss: () -> Unit, onSave: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically
    ) {
        TextButton(
            onClick = onDismiss,
            colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.secondary)
        ) {
            Text("取消", style = MaterialTheme.typography.labelLarge)
        }
        Spacer(modifier = Modifier.width(16.dp))
        Button(
            onClick = onSave,
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
            elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp)
        ) {
            Text(
                "保存",
                color = MaterialTheme.colorScheme.onPrimary,
                style = MaterialTheme.typography.labelLarge
            )
        }
    }
}