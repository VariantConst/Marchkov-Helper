package com.variantconst.marchkov.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.input.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.font.FontWeight

@Composable
fun LoginScreen(onLogin: (String, String) -> Unit) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isPasswordVisible by remember { mutableStateOf(false) }
    var showError by remember { mutableStateOf(false) }
    var isLoginEnabled by remember { mutableStateOf(false) }

    LaunchedEffect(username, password) {
        isLoginEnabled = username.isNotBlank() && password.isNotBlank()
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            AnimatedLogo()
            Spacer(modifier = Modifier.height(48.dp))
            StyledTextField(
                value = username,
                onValueChange = { username = it; showError = false },
                label = "用户名",
                icon = Icons.Outlined.Person,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next)
            )
            Spacer(modifier = Modifier.height(16.dp))
            StyledTextField(
                value = password,
                onValueChange = { password = it; showError = false },
                label = "密码",
                icon = Icons.Outlined.Lock,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                isPassword = true,
                isPasswordVisible = isPasswordVisible,
                onPasswordVisibilityChange = { isPasswordVisible = it }
            )
            Spacer(modifier = Modifier.height(24.dp))
            AnimatedLoginButton(
                onClick = {
                    if (isLoginEnabled) {
                        onLogin(username, password)
                    } else {
                        showError = true
                    }
                },
                isEnabled = isLoginEnabled
            )
            AnimatedVisibility(
                visible = showError,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Text(
                    "请输入用户名和密码",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(top = 8.dp),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

@Composable
fun AnimatedLogo() {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(animationSpec = tween(1000)) + expandIn(expandFrom = Alignment.Center)
    ) {
        Text(
            text = "MARCHKOV",
            style = MaterialTheme.typography.displayLarge.copy(
                fontWeight = FontWeight.Bold,
                fontSize = MaterialTheme.typography.displayLarge.fontSize * 0.85
            ),
            color = MaterialTheme.colorScheme.primary
        )
    }
}

@Composable
fun StyledTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    icon: ImageVector,
    keyboardOptions: KeyboardOptions,
    isPassword: Boolean = false,
    isPasswordVisible: Boolean = false,
    onPasswordVisibilityChange: ((Boolean) -> Unit)? = null
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        leadingIcon = {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        },
        trailingIcon = if (isPassword) {
            {
                IconButton(onClick = { onPasswordVisibilityChange?.invoke(!isPasswordVisible) }) {
                    Icon(
                        if (isPasswordVisible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                        contentDescription = if (isPasswordVisible) "隐藏密码" else "显示密码",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else null,
        visualTransformation = if (isPassword && !isPasswordVisible) PasswordVisualTransformation() else VisualTransformation.None,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MaterialTheme.colorScheme.primary,
            unfocusedBorderColor = MaterialTheme.colorScheme.outline,
            focusedLabelColor = MaterialTheme.colorScheme.primary,
            cursorColor = MaterialTheme.colorScheme.primary
        ),
        singleLine = true,
        keyboardOptions = keyboardOptions,
        textStyle = MaterialTheme.typography.bodyLarge
    )
}

@Composable
fun AnimatedLoginButton(onClick: () -> Unit, isEnabled: Boolean) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(if (isPressed) 0.95f else 1f, label = "")

    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .scale(scale),
        shape = MaterialTheme.shapes.medium,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
            disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant,
            disabledContentColor = MaterialTheme.colorScheme.onSurfaceVariant
        ),
        enabled = isEnabled,
        interactionSource = interactionSource
    ) {
        Text("登录", style = MaterialTheme.typography.titleMedium)
    }
}