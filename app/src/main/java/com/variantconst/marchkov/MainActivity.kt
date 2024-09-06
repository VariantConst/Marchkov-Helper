package com.variantconst.marchkov

import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.annotation.RequiresApi
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.tooling.preview.Preview
import kotlinx.coroutines.*
import android.util.Log
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.variantconst.marchkov.components.LogScreen
import com.variantconst.marchkov.components.LoginScreen
import com.variantconst.marchkov.components.MainPagerScreen
import com.variantconst.marchkov.components.LoadingScreen
import com.variantconst.marchkov.utils.*
import com.variantconst.marchkov.utils.Settings

@RequiresApi(Build.VERSION_CODES.O)
class MainActivity : ComponentActivity() {
    private lateinit var reservationManager: ReservationManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        reservationManager = ReservationManager(this)

        // 加载设置
        Settings.load(this)

        val sharedPreferences = getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        val savedUsername = sharedPreferences.getString("username", null)
        val savedPassword = sharedPreferences.getString("password", null)

        setContent {
            var responseTexts by remember { mutableStateOf(listOf<String>()) }
            var qrCodeBitmap by remember { mutableStateOf<Bitmap?>(null) }
            var reservationDetails by remember { mutableStateOf<Map<String, Any>?>(null) }
            var qrCodeString by remember { mutableStateOf<String?>(null) }
            var isLoggedIn by remember { mutableStateOf(false) }
            var showLoading by remember { mutableStateOf(true) }
            var errorMessage by remember { mutableStateOf<String?>(null) }
            var isToYanyuan by remember { mutableStateOf(getInitialDirection()) }
            var showLogs by remember { mutableStateOf(false) }
            var currentPage by remember { mutableIntStateOf(0) }
            var isReservationLoaded by remember { mutableStateOf(false) }
            var isReservationLoading by remember { mutableStateOf(false) }
            var loadingMessage by remember { mutableStateOf("") }
            var isTimeout by remember { mutableStateOf(false) }
            val scope = rememberCoroutineScope()
            var timeoutJob by remember { mutableStateOf<Job?>(null) }

            LaunchedEffect(Unit) {
                if (savedUsername != null && savedPassword != null) {
                    val firstAttemptSuccess = performLoginAndHandleResult(
                        username = savedUsername,
                        password = savedPassword,
                        isToYanyuan = isToYanyuan,
                        updateLoadingMessage = { message -> loadingMessage = message },
                        handleResult = { success, response, bitmap, details, qrCode ->
                            responseTexts = responseTexts + response
                            Log.v("Mytag", "response is $response and success is $success")
                            if (success) {
                                isLoggedIn = true
                                showLoading = details == null
                                isReservationLoaded = details != null
                                currentPage = 0
                                qrCodeBitmap = bitmap
                                reservationDetails = details
                                qrCodeString = qrCode

                                if (!isReservationLoaded) {
                                    isReservationLoading = true
                                    timeoutJob = startLoadingTimeout(scope) {
                                        isTimeout = true
                                        showLoading = false
                                        errorMessage = "加载超时，请重试"
                                        isReservationLoading = false
                                    }
                                }
                            } else {
                                errorMessage = response
                                showLoading = false
                            }
                        },
                        timeoutJob = timeoutJob
                    )
                    Log.v("Mytag", "firstAttemptSuccess is $firstAttemptSuccess")

                    if (!isLoggedIn) {
                        errorMessage = "当前时段无车可坐！"
                        showLoading = false
                    }
                } else {
                    showLoading = false
                }
            }

            AppTheme {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    Color(0xFFF0F4F8),
                                    Color(0xFFE1E8ED)
                                )
                            )
                        )
                ) {
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = Color.Transparent
                    ) {
                        Box(modifier = Modifier.fillMaxSize()) {
                            AnimatedVisibility(
                                visible = (showLoading || loadingMessage.isNotEmpty()) && !isTimeout,
                                enter = fadeIn(),
                                exit = fadeOut()
                            ) {
                                Box(
                                    modifier = Modifier.fillMaxSize(),
                                    contentAlignment = Alignment.Center
                                ) {
                                    LoadingScreen(message = loadingMessage)
                                }
                            }

                            if (!showLoading && loadingMessage.isEmpty()) {
                                if (isLoggedIn) {
                                    if (showLogs) {
                                        LogScreen(
                                            responseTexts = responseTexts,
                                            onBack = {
                                                showLogs = false
                                                currentPage = 1
                                            }
                                        )
                                    } else {
                                        MainPagerScreen(
                                            qrCodeBitmap = qrCodeBitmap,
                                            reservationDetails = reservationDetails,
                                            onLogout = {
                                                isLoggedIn = false
                                                responseTexts = listOf()
                                                qrCodeBitmap = null
                                                reservationDetails = null
                                                qrCodeString = null
                                                clearLoginInfo()
                                                errorMessage = null
                                                showLoading = false
                                            },
                                            onToggleBusDirection = {
                                                isToYanyuan = !isToYanyuan
                                                isReservationLoading = true
                                                scope.launch {
                                                    performLoginAndHandleResult(
                                                        username = savedUsername ?: "",
                                                        password = savedPassword ?: "",
                                                        isToYanyuan = isToYanyuan,
                                                        updateLoadingMessage = { message -> loadingMessage = message },
                                                        handleResult = { success, response, bitmap, details, qrCode ->
                                                            responseTexts = responseTexts + response
                                                            Log.v("Mytag", "response is $response and success is $success")
                                                            if (success) {
                                                                isLoggedIn = true
                                                                showLoading = details == null
                                                                isReservationLoaded = details != null
                                                                currentPage = 0
                                                                qrCodeBitmap = bitmap
                                                                reservationDetails = details
                                                                qrCodeString = qrCode

                                                                if (!isReservationLoaded) {
                                                                    isReservationLoading = true
                                                                    timeoutJob = startLoadingTimeout(scope) {
                                                                        isTimeout = true
                                                                        showLoading = false
                                                                        errorMessage = "加载超时，请重试"
                                                                        isReservationLoading = false
                                                                    }
                                                                }
                                                            } else {
                                                                errorMessage = response
                                                                showLoading = false
                                                            }
                                                        },
                                                        timeoutJob = timeoutJob
                                                    )
                                                }
                                            },
                                            onShowLogs = { showLogs = true },
                                            currentPage = currentPage,
                                            setPage = { currentPage = it },
                                            isReservationLoading = isReservationLoading,
                                            onRefresh = {
                                                performLoginAndHandleResult(
                                                    username = savedUsername ?: "",
                                                    password = savedPassword ?: "",
                                                    isToYanyuan = isToYanyuan,
                                                    updateLoadingMessage = { message -> loadingMessage = message },
                                                    handleResult = { success, response, bitmap, details, qrCode ->
                                                        responseTexts = responseTexts + response
                                                        Log.v("Mytag", "response is $response and success is $success")
                                                        if (success) {
                                                            isLoggedIn = true
                                                            showLoading = details == null
                                                            isReservationLoaded = details != null
                                                            currentPage = 0
                                                            qrCodeBitmap = bitmap
                                                            reservationDetails = details
                                                            qrCodeString = qrCode

                                                            if (!isReservationLoaded) {
                                                                isReservationLoading = true
                                                                timeoutJob = startLoadingTimeout(scope) {
                                                                    isTimeout = true
                                                                    showLoading = false
                                                                    errorMessage = "加载超时，请重试"
                                                                    isReservationLoading = false
                                                                }
                                                            }
                                                        } else {
                                                            errorMessage = response
                                                            showLoading = false
                                                        }
                                                    },
                                                    timeoutJob = timeoutJob
                                                )
                                            },
                                            reservationManager = reservationManager,
                                            username = savedUsername ?: "",
                                            password = savedPassword ?: ""
                                        )
                                    }
                                } else {
                                    errorMessage?.let { msg ->
                                        ErrorScreen(message = msg, onRetry = {
                                            errorMessage = null
                                            showLoading = true
                                            scope.launch {
                                                reservationManager.performLogin(
                                                    username = savedUsername ?: "",
                                                    password = savedPassword ?: "",
                                                    isToYanyuan = isToYanyuan,
                                                    updateLoadingMessage = { message ->
                                                        loadingMessage = message
                                                    },
                                                    callback = { success, response, bitmap, details, qrCode ->
                                                        responseTexts = responseTexts + response
                                                        if (success) {
                                                            isLoggedIn = true
                                                            showLoading = false
                                                            currentPage = 0
                                                            qrCodeBitmap = bitmap
                                                            reservationDetails = details
                                                            qrCodeString = qrCode
                                                        } else {
                                                            errorMessage = response
                                                            showLoading = false
                                                        }
                                                    },
                                                    timeoutJob = timeoutJob
                                                )
                                            }
                                        })
                                    } ?: LoginScreen(
                                        onLogin = { username, password ->
                                            showLoading = true
                                            reservationManager.performLogin(
                                                username = username,
                                                password = password,
                                                isToYanyuan = isToYanyuan,
                                                updateLoadingMessage = { message ->
                                                    loadingMessage = message
                                                },
                                                callback = { success, response, bitmap, details, qrCode ->
                                                    responseTexts = responseTexts + response
                                                    if (success) {
                                                        isLoggedIn = true
                                                        showLoading = false
                                                        saveLoginInfo(username, password)
                                                        currentPage = 0
                                                        qrCodeBitmap = bitmap
                                                        reservationDetails = details
                                                        qrCodeString = qrCode
                                                    } else {
                                                        errorMessage = response
                                                        showLoading = false
                                                    }
                                                },
                                                timeoutJob = timeoutJob
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private fun startLoadingTimeout(scope: CoroutineScope, onTimeout: () -> Unit): Job {
        return scope.launch {
            delay(1000)
            onTimeout()
        }
    }

    private fun cancelLoadingTimeout(job: Job?) {
        job?.cancel()
    }

    private suspend fun performLoginAndHandleResult(
        username: String,
        password: String,
        isToYanyuan: Boolean,
        updateLoadingMessage: (String) -> Unit,
        handleResult: (Boolean, String, Bitmap?, Map<String, Any>?, String?) -> Unit,
        timeoutJob: Job?
    ): Boolean {
        val deferredResult = CompletableDeferred<Boolean>()

        reservationManager.performLogin(username, password, isToYanyuan, updateLoadingMessage, { success, response, bitmap, details, qrCode ->
            handleResult(success, response, bitmap, details, qrCode)
            deferredResult.complete(success)
        }, timeoutJob)

        return deferredResult.await()
    }

    private fun saveLoginInfo(username: String, password: String) {
        val sharedPreferences = getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putString("username", username)
            putString("password", password)
            apply()
        }
    }

    private fun clearLoginInfo() {
        val sharedPreferences = getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            remove("username")
            remove("password")
            remove("realName")
            remove("department")
            apply()
        }
    }
}

@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    AppTheme {
        LoginScreen(onLogin = { _, _ -> })
    }
}
