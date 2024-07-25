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
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.*
import okhttp3.*
import java.text.SimpleDateFormat
import java.util.*
import android.util.Log
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import com.variantconst.marchkov.components.LogScreen
import com.variantconst.marchkov.components.LoginScreen
import com.variantconst.marchkov.components.MainPagerScreen
import com.variantconst.marchkov.components.LoadingScreen
import com.variantconst.marchkov.utils.*
import com.variantconst.marchkov.utils.SimpleCookieJar
import com.variantconst.marchkov.utils.Settings

@RequiresApi(Build.VERSION_CODES.O)
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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

                                // 开始加载预约信息时启动超时计时器
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
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
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
                                            currentPage = 1 // 返回时设置页码为第二屏
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
                                                val sessionCookieJar = SimpleCookieJar()
                                                val client = OkHttpClient.Builder()
                                                    .cookieJar(sessionCookieJar)
                                                    .build()

                                                performLoginWithClient(
                                                    username = savedUsername ?: "",
                                                    password = savedPassword ?: "",
                                                    isToYanyuan = isToYanyuan,
                                                    client = client,
                                                    updateLoadingMessage = { message ->
                                                        loadingMessage = message
                                                    },
                                                    callback = { success, response, bitmap, details, qrCode ->
                                                        cancelLoadingTimeout(timeoutJob)
                                                        responseTexts = responseTexts + response
                                                        if (success) {
                                                            qrCodeBitmap = bitmap
                                                            reservationDetails = details
                                                            qrCodeString = qrCode
                                                        }
                                                        isReservationLoading = false
                                                    },
                                                    timeoutJob = timeoutJob
                                                )
                                            }
                                        },
                                        onShowLogs = { showLogs = true },
                                        currentPage = currentPage,
                                        setPage = { currentPage = it },
                                        isReservationLoading = isReservationLoading
                                    )
                                }
                            } else {
                                errorMessage?.let { msg ->
                                    ErrorScreen(message = msg, onRetry = {
                                        errorMessage = null
                                        showLoading = true
                                        scope.launch {
                                            performLogin(
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
                                        performLogin(
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

    private fun startLoadingTimeout(scope: CoroutineScope, onTimeout: () -> Unit): Job {
        return scope.launch {
            delay(500) // 10秒
            onTimeout()
        }
    }

    private fun cancelLoadingTimeout(job: Job?) {
        job?.cancel()
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private suspend fun performLoginAndHandleResult(
        username: String,
        password: String,
        isToYanyuan: Boolean,
        updateLoadingMessage: (String) -> Unit,
        handleResult: (Boolean, String, Bitmap?, Map<String, Any>?, String?) -> Unit,
        timeoutJob: Job?
    ): Boolean {
        val deferredResult = CompletableDeferred<Boolean>()

        performLogin(username, password, isToYanyuan, updateLoadingMessage, { success, response, bitmap, details, qrCode ->
            handleResult(success, response, bitmap, details, qrCode)
            deferredResult.complete(success)
        }, timeoutJob)

        return deferredResult.await()
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun performLogin(
        username: String,
        password: String,
        isToYanyuan: Boolean,
        updateLoadingMessage: (String) -> Unit,
        callback: (Boolean, String, Bitmap?, Map<String, Any>?, String?) -> Unit,
        timeoutJob: Job?
    ) {
        val sessionCookieJar = SimpleCookieJar()
        val client = OkHttpClient.Builder()
            .cookieJar(sessionCookieJar)
            .build()

        performLoginWithClient(username, password, isToYanyuan, client, updateLoadingMessage, callback, timeoutJob)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun performLoginWithClient(
        username: String,
        password: String,
        isToYanyuan: Boolean,
        client: OkHttpClient,
        updateLoadingMessage: (String) -> Unit,
        callback: (Boolean, String, Bitmap?, Map<String, Any>?, String?) -> Unit,
        timeoutJob: Job?
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                updateLoadingMessage("正在登录...")
                // Step 1: GET request and POST login
                var request: Request

                val formBody = FormBody.Builder()
                    .add("appid", "wproc")
                    .add("userName", username)
                    .add("password", password)
                    .add("redirUrl", "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/")
                    .build()

                request = Request.Builder()
                    .url("https://iaaa.pku.edu.cn/iaaa/oauthlogin.do")
                    .post(formBody)
                    .build()

                var response = client.newCall(request).execute()
                val responseBody = response.body?.string() ?: "No response body"
                val gson = Gson()
                val mapType = object : TypeToken<Map<String, Any>>() {}.type
                val jsonMap: Map<String, Any> = gson.fromJson(responseBody, mapType)
                val token = jsonMap["token"] as? String ?: "Token not found"
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful && token.isNotEmpty()) {
                        callback(true, "第一步：登录账号成功\n获取 token 为 $token", null, null, null)
                    } else {
                        callback(false, "第一步：登录账号失败\n获取 token 为 $token", null, null, null)
                    }
                }

                // Step 2: GET request with token
                val urlWithToken = "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&token=$token"
                request = Request.Builder()
                    .url(urlWithToken)
                    .build()

                response = client.newCall(request).execute()
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        callback(true, "第二步：跟随重定向成功\n结果：${response.code}", null, null, null)
                    } else {
                        callback(false, "第二步：跟随重定向失败\n" +
                                "结果：${response.code}", null, null, null)
                    }
                }

                updateLoadingMessage("正在获取预约列表...")
                // Step 3: GET reservation list
                val date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                val reservationListUrl = "https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=$date&p=1&page_size=0"
                request = Request.Builder()
                    .url(reservationListUrl)
                    .build()

                response = client.newCall(request).execute()
                val resourcesJson = response.body?.string() ?: "No response body"
                val resourcesMap: Map<String, Any> = gson.fromJson(resourcesJson, mapType)
                val resourceList: List<*>? = (resourcesMap["d"] as? Map<*, *>)?.let { map ->
                    (map["list"] as? List<*>)
                }
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful && resourceList != null) {
                        callback(true, "第三步：获取班车信息成功\n共获取 ${resourceList.size} 条班车信息", null, null, null)
                    } else {
                        callback(false, "第三步：获取班车信息失败", null, null, null)
                    }
                }

                Log.v("MyTag", "$resourceList")

                val chosenBus = chooseBus(resourceList, isToYanyuan)
                Log.v("MyTag", "$chosenBus and direction $isToYanyuan")
                val chosenResourceId = chosenBus.resourceId
                val chosenPeriod = chosenBus.period
                val startTime = chosenBus.startTime
                val isTemp = chosenBus.isTemp
                val resourceName = chosenBus.resourceName

                if (chosenResourceId == 0 || chosenPeriod == 0) {
                    withContext(Dispatchers.Main) {
                        callback(false, "没有找到可约的班车", null, null, null)
                        updateLoadingMessage("")
                    }
                    return@launch
                }

                // Step 4: Launch reservation
                if (isTemp) {
                    // 生成临时码
                    updateLoadingMessage("正在获取临时码...")
                    val tempQrCodeUrl = "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id=$chosenResourceId&text=$startTime"
                    request = Request.Builder()
                        .url(tempQrCodeUrl)
                        .build()

                    response = client.newCall(request).execute()
                    val tempQrCodeResponse = response.body?.string() ?: "No response body"
                    withContext(Dispatchers.Main) {
                        if (response.isSuccessful) {
                            val qrCodeJson = gson.fromJson(tempQrCodeResponse, Map::class.java)
                            val qrCodeData = (qrCodeJson["d"] as? Map<*, *>)?.get("code") as? String
                            Log.v("MyTag", "临时码响应是 is $tempQrCodeResponse")
                            val creatorNameFull = (qrCodeJson["d"] as? Map<*, *>)?.get("name") as? String
                            val creatorName = creatorNameFull?.split("\r\n")?.get(0) ?: "马池口🐮🐴"
                            saveRealName(creatorName)
                            val creatorDepart = creatorNameFull?.split("\r\n")?.get(2) ?: "这个需要你自己衡量！"
                            saveDepartment(creatorDepart)
                            val reservationDetails = mapOf<String, Any>(
                                "creator_name" to (creatorName),
                                "resource_name" to resourceName,
                                "start_time" to startTime,
                                "is_temp" to true
                            )
                            if (qrCodeData != null) {
                                try {
                                    val qrCodeBitmap = generateQRCode(qrCodeData)
                                    callback(true, "成功获取临时码", qrCodeBitmap, reservationDetails, qrCodeData)
                                } catch (e: IllegalArgumentException) {
                                    callback(false, "无法解码临时码字符串: ${e.message}", null, null, qrCodeData)
                                }
                            } else {
                                callback(false, "找不到临时码字符串", null, null, null)
                            }
                        } else {
                            callback(false, "临时码请求响应为: $tempQrCodeResponse", null, null, null)
                        }
                    }
                } else {
                    val launchBody = FormBody.Builder()
                        .add("resource_id", "$chosenResourceId")
                        .add("data", "[{\"date\": \"$date\", \"period\": \"$chosenPeriod\", \"sub_resource_id\": 0}]")
                        .build()
                    request = Request.Builder()
                        .url("https://wproc.pku.edu.cn/site/reservation/launch")
                        .post(launchBody)
                        .build()

                    response = client.newCall(request).execute()
                    val launchResponse = response.body?.string() ?: "No response body"
                    withContext(Dispatchers.Main) {
                        if (response.isSuccessful) {
                            callback(true, "第四步：预约班车成功\n响应为 $launchResponse", null, null, null)
                        } else {
                            callback(false, "第四步：预约班车失败\n" +
                                    "响应为 $launchResponse", null, null, null)
                        }
                    }

                    // Step 5: GET my reservations
                    val myReservationsUrl = "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc"
                    request = Request.Builder()
                        .url(myReservationsUrl)
                        .build()

                    response = client.newCall(request).execute()
                    val appsJson = response.body?.string() ?: "No response body"
                    val appsMap: Map<String, Any> = gson.fromJson(appsJson, mapType)
                    val formattedJson = formatMap(appsMap)
                    val reservationData: List<Map<String, Any>>? = (appsMap["d"] as? Map<*, *>)?.let { map ->
                        (map["data"] as? List<*>)?.filterIsInstance<Map<String, Any>>()
                    }
                    Log.v("MyTag", "reservationData is $reservationData")
                    var reservationDetails: Map<String, Any>? = null
                    if (reservationData != null) {
                        for (reservation in reservationData) {
                            val reservationResourceId = (reservation["resource_id"] as Double).toInt()
                            Log.v("MyTag", "reservationResourceId is $reservationResourceId, and isToYanyuan is $isToYanyuan")
                            if ((reservationResourceId in listOf(2, 4) && isToYanyuan) ||
                                (reservationResourceId in listOf(5, 6, 7) && !isToYanyuan)) {
                                Log.v("MyTag", "reservationDetails is $reservation")
                                val periodText = (reservation["period_text"] as? Map<*, *>)?.values?.firstOrNull() as? Map<*, *>
                                val period = (periodText?.get("text") as? List<*>)?.firstOrNull() as? String ?: "未知时间"
                                val creatorName = reservation["creator_name"] as? String ?: "马池口🐮🐴"
                                val creatorDepart = reservation["creator_depart"] as? String ?: "这个需要你自己衡量！"
                                saveRealName(creatorName)
                                saveDepartment(creatorDepart)
                                reservationDetails = mapOf<String, Any>(
                                    "creator_name" to creatorName,
                                    "resource_name" to reservation["resource_name"] as String,
                                    "start_time" to period,
                                    "is_temp" to false
                                )
                                break
                            }
                        }
                    }

                    withContext(Dispatchers.Main) {
                        if (response.isSuccessful) {
                            callback(true, "第五步：获取已约班车信息成功\n响应：$formattedJson", null, reservationDetails, null)
                        } else {
                            callback(false, "第五步：获取已约班车信息失败\n" +
                                    "响应：$formattedJson", null, null, null)
                        }
                    }

                    updateLoadingMessage("正在生成二维码...")
                    // Step 6: Get QR code and cancel reservations
                    val appData: List<Map<String, Any>>? = (appsMap["d"] as? Map<*, *>)?.let { map ->
                        (map["data"] as? List<*>)?.filterIsInstance<Map<String, Any>>()
                    }
                    withContext(Dispatchers.Main) {
                        callback(true, "Step 7: Processing ${appData?.size ?: 0} reservations", null, null, null)
                    }
                    if (appData?.isNotEmpty() == true) {
                        appData.forEachIndexed { index, app ->
                            val appId = app["id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appId")
                            val appAppointmentId = app["hall_appointment_data_id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appAppointmentId")

                            withContext(Dispatchers.Main) {
                                callback(true, "正在处理第 ${index + 1} 个预约:", null, null, null)
                                callback(true, "  App ID: $appId", null, null, null)
                                callback(true, "  Appointment ID: $appAppointmentId", null, null, null)
                            }

                            // Get QR code
                            val qrCodeUrl = "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=0&id=$appId&hall_appointment_data_id=$appAppointmentId"
                            request = Request.Builder()
                                .url(qrCodeUrl)
                                .build()

                            response = client.newCall(request).execute()
                            val qrCodeResponse = response.body?.string() ?: "No response body"
                            withContext(Dispatchers.Main) {
                                if (response.isSuccessful) {
                                    callback(true, " 乘车码响应: $qrCodeResponse", null, null, null)

                                    // Parse the QR code response and generate the QR code bitmap
                                    val qrCodeJson = Gson().fromJson(qrCodeResponse, Map::class.java)
                                    val qrCodeData = (qrCodeJson["d"] as? Map<*, *>)?.get("code") as? String
                                    if (qrCodeData != null) {
                                        withContext(Dispatchers.Main) {
                                            callback(true, "要解码的乘车码字符串: $qrCodeData", null, null, qrCodeData)
                                        }
                                        try {
                                            val qrCodeBitmap = generateQRCode(qrCodeData)
                                            callback(true, "乘车码解码成功", qrCodeBitmap, reservationDetails, qrCodeData)
                                        } catch (e: IllegalArgumentException) {
                                            withContext(Dispatchers.Main) {
                                                callback(false, "无法解码乘车码字符串: ${e.message}", null, null, qrCodeData)
                                            }
                                        }
                                    } else {
                                        withContext(Dispatchers.Main) {
                                            callback(false, "找不到乘车码", null, null, null)
                                        }
                                    }
                                } else {
                                    callback(false, "乘车码请求响应: $qrCodeResponse", null, null, null)
                                }
                            }
                        }
                    } else {
                        withContext(Dispatchers.Main) {
                            callback(false, "找不到预约信息。可能是时间太早还无法查看乘车码。", null, null, null)
                        }
                    }
                }
                updateLoadingMessage("")
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(false, "无法执行请求: ${e.message}", null, null, null)
                    callback(false, "Stack trace: ${e.stackTraceToString()}", null, null, null)
                }
            } finally {
                withContext(Dispatchers.Main) {
                    cancelLoadingTimeout(timeoutJob)
                }
            }
        }
    }

    private fun saveLoginInfo(username: String, password: String) {
        val sharedPreferences = getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putString("username", username)
            putString("password", password)
            apply()
        }
    }

    private fun saveRealName(realName: String) {
        val sharedPreferences = getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        val currentRealName = sharedPreferences.getString("realName", null)
        if (currentRealName == null || realName == "马池口🐮🐴") {
            with(sharedPreferences.edit()) {
                putString("realName", realName)
                apply()
            }
        }
    }

    private fun saveDepartment(department: String) {
        val sharedPreferences = getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        val currentDepartment = sharedPreferences.getString("department", null)
        if (currentDepartment == null || department == "这个需要你自己衡量！") {
            with(sharedPreferences.edit()) {
                putString("department", department)
                apply()
            }
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

data class BusInfo(
    val resourceId: Int,
    val resourceName: String,
    val startTime: String,
    val isTemp: Boolean,
    val period: Int?)
