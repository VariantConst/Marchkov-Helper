package com.example.greetingcard

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.annotation.RequiresApi
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.*
import okhttp3.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import java.text.SimpleDateFormat
import java.time.Duration
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.*
import androidx.compose.foundation.shape.RoundedCornerShape
import android.util.Log

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person

class SimpleCookieJar : CookieJar {
    private val cookieStore = HashMap<String, List<Cookie>>()

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        cookieStore[url.host] = cookies
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val cookies = cookieStore[url.host]
        return cookies ?: ArrayList()
    }

    fun clearCookies() {
        cookieStore.clear()
    }
}

class MainActivity : ComponentActivity() {
    @RequiresApi(Build.VERSION_CODES.O)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 加载设置
        Settings.load(this)

        val sharedPreferences = getSharedPreferences("LoginPrefs", Context.MODE_PRIVATE)
        val savedUsername = sharedPreferences.getString("username", null)
        val savedPassword = sharedPreferences.getString("password", null)

        setContent {
            val prevInterval = remember { mutableStateOf(Settings.PREV_INTERVAL) }
            val nextInterval = remember { mutableStateOf(Settings.NEXT_INTERVAL) }
            var responseTexts by remember { mutableStateOf(listOf<String>()) }
            var qrCodeBitmap by remember { mutableStateOf<Bitmap?>(null) }
            var reservationDetails by remember { mutableStateOf<Map<String, Any>?>(null) }
            var qrCodeString by remember { mutableStateOf<String?>(null) }
            var isLoggedIn by remember { mutableStateOf(false) }
            var showLoading by remember { mutableStateOf(true) }
            var errorMessage by remember { mutableStateOf<String?>(null) }
            var isToYanyuan by remember { mutableStateOf(true) }
            var showSnackbar by remember { mutableStateOf(false) }
            var snackbarMessage by remember { mutableStateOf("") }
            var showLogs by remember { mutableStateOf(false) }
            var showSettingsDialog by remember { mutableStateOf(false) }

            val scope = rememberCoroutineScope()
            val context = LocalContext.current

            LaunchedEffect(Unit) {
                if (savedUsername != null && savedPassword != null) {
                    withTimeoutOrNull(10000L) {
                        performLogin(savedUsername, savedPassword, isToYanyuan) { success, response, bitmap, details, qrCode ->
                            if (success) {
                                isLoggedIn = true
                                showLoading = false
                            } else {
                                errorMessage = response
                                showLoading = false
                            }
                            responseTexts = responseTexts + response
                            qrCodeBitmap = bitmap
                            reservationDetails = details
                            qrCodeString = qrCode
                        }
                    } ?: run {
                        errorMessage = "Login timeout"
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
                        AnimatedVisibility(visible = showLoading) {
                            LoadingScreen()
                        }

                        if (!showLoading) {
                            if (isLoggedIn) {
                                if (showLogs) {
                                    LogScreen(
                                        responseTexts = responseTexts,
                                        onBack = { showLogs = false }
                                    )
                                } else {
                                    DetailScreen(
                                        responseTexts = responseTexts,
                                        qrCodeBitmap = qrCodeBitmap,
                                        reservationDetails = reservationDetails,
                                        onLogout = {
                                            isLoggedIn = false
                                            responseTexts = listOf()
                                            qrCodeBitmap = null
                                            reservationDetails = null
                                            qrCodeString = null
                                            clearLoginInfo()
                                        },
                                        onToggleBusDirection = {
                                            isToYanyuan = !isToYanyuan
                                            showLoading = true
                                            scope.launch {
                                                val sessionCookieJar = SimpleCookieJar()
                                                val client = OkHttpClient.Builder()
                                                    .cookieJar(sessionCookieJar)
                                                    .build()

                                                performLoginWithClient(savedUsername ?: "", savedPassword ?: "", isToYanyuan, client) { success, response, bitmap, details, qrCode ->
                                                    responseTexts = responseTexts + response
                                                    if (success) {
                                                        qrCodeBitmap = bitmap
                                                        reservationDetails = details
                                                        qrCodeString = qrCode
                                                        snackbarMessage = "反向预约成功"
                                                    } else {
                                                        snackbarMessage = "反向无车可坐"
                                                    }
                                                    showLoading = false
                                                    showSnackbar = true
                                                }
                                            }
                                        },
                                        onShowLogs = { showLogs = true },
                                        onEditSettings = { showSettingsDialog = true }
                                    )
                                }
                            } else {
                                errorMessage?.let { msg ->
                                    ErrorScreen(message = msg, onRetry = {
                                        errorMessage = null
                                        showLoading = true
                                        scope.launch {
                                            performLogin(savedUsername ?: "", savedPassword ?: "", isToYanyuan) { success, response, bitmap, details, qrCode ->
                                                if (success) {
                                                    isLoggedIn = true
                                                    showLoading = false
                                                } else {
                                                    errorMessage = response
                                                    showLoading = false
                                                }
                                                responseTexts = responseTexts + response
                                                qrCodeBitmap = bitmap
                                                reservationDetails = details
                                                qrCodeString = qrCode
                                            }
                                        }
                                    })
                                } ?: LoginScreen(
                                    onLogin = { username, password ->
                                        showLoading = true
                                        performLogin(username, password, isToYanyuan) { success, response, bitmap, details, qrCode ->
                                            if (success) {
                                                isLoggedIn = true
                                                showLoading = false
                                                saveLoginInfo(username, password)
                                            } else {
                                                errorMessage = response
                                                showLoading = false
                                            }
                                            responseTexts = responseTexts + response
                                            qrCodeBitmap = bitmap
                                            reservationDetails = details
                                            qrCodeString = qrCode
                                        }
                                    }
                                )
                            }
                        }

                        LaunchedEffect(showSnackbar) {
                            if (showSnackbar) {
                                delay(1000)
                                showSnackbar = false
                            }
                        }

                        if (showSnackbar) {
                            Snackbar(
                                modifier = Modifier
                                    .padding(16.dp)
                                    .align(Alignment.BottomCenter)
                                    .defaultMinSize(minWidth = 150.dp)
                            ) {
                                Text(snackbarMessage, color = MaterialTheme.colorScheme.onSecondary)
                            }
                        }

                        if (showSettingsDialog) {
                            AlertDialog(
                                onDismissRequest = { showSettingsDialog = false },
                                title = { Text("编辑配置") },
                                text = {
                                    Column {
                                        TextField(
                                            value = prevInterval.value.toString(),
                                            onValueChange = { prevInterval.value = it.toIntOrNull() ?: Settings.PREV_INTERVAL },
                                            label = { Text("PREV_INTERVAL") },
                                            modifier = Modifier.fillMaxWidth()
                                        )
                                        Spacer(modifier = Modifier.height(8.dp))
                                        TextField(
                                            value = nextInterval.value.toString(),
                                            onValueChange = { nextInterval.value = it.toIntOrNull() ?: Settings.NEXT_INTERVAL },
                                            label = { Text("NEXT_INTERVAL") },
                                            modifier = Modifier.fillMaxWidth()
                                        )
                                    }
                                },
                                confirmButton = {
                                    Button(onClick = {
                                        Settings.updatePrevInterval(context, prevInterval.value)
                                        Settings.updateNextInterval(context, nextInterval.value)
                                        showSettingsDialog = false
                                    }) {
                                        Text("保存")
                                    }
                                },
                                dismissButton = {
                                    Button(onClick = { showSettingsDialog = false }) {
                                        Text("取消")
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun performLogin(
        username: String,
        password: String,
        isToYanyuan: Boolean,
        callback: (Boolean, String, Bitmap?, Map<String, Any>?, String?) -> Unit
    ) {
        val sessionCookieJar = SimpleCookieJar()
        val client = OkHttpClient.Builder()
            .cookieJar(sessionCookieJar)
            .build()

        performLoginWithClient(username, password, isToYanyuan, client, callback)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun performLoginWithClient(
        username: String,
        password: String,
        isToYanyuan: Boolean,
        client: OkHttpClient,
        callback: (Boolean, String, Bitmap?, Map<String, Any>?, String?) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Step 1: GET request
                var request = Request.Builder()
                    .url("https://wproc.pku.edu.cn/api/login/main")
                    .build()
                var response = client.newCall(request).execute()
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        callback(true, "Step 1: GET https://wproc.pku.edu.cn/api/login/main\n${response.code}", null, null, null)
                    } else {
                        callback(false, "Step 1: GET https://wproc.pku.edu.cn/api/login/main\n${response.code}", null, null, null)
                    }
                }

                // Step 2: POST login
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

                response = client.newCall(request).execute()
                val responseBody = response.body?.string() ?: "No response body"
                val gson = Gson()
                val mapType = object : TypeToken<Map<String, Any>>() {}.type
                val jsonMap: Map<String, Any> = gson.fromJson(responseBody, mapType)
                val token = jsonMap["token"] as? String ?: "Token not found"
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful && token.isNotEmpty()) {
                        callback(true, "Step 2: POST https://iaaa.pku.edu.cn/iaaa/oauthlogin.do\nToken: $token", null, null, null)
                    } else {
                        callback(false, "Step 2: POST https://iaaa.pku.edu.cn/iaaa/oauthlogin.do\nToken: $token", null, null, null)
                    }
                }

                // Step 3: GET request with token
                val urlWithToken = "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&token=$token"
                request = Request.Builder()
                    .url(urlWithToken)
                    .build()

                response = client.newCall(request).execute()
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        callback(true, "Step 3: GET $urlWithToken\n${response.code}", null, null, null)
                    } else {
                        callback(false, "Step 3: GET $urlWithToken\n${response.code}", null, null, null)
                    }
                }

                // Step 4: GET reservation list
                val date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                val reservationListUrl = "https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=$date&p=1&page_size=0"
                request = Request.Builder()
                    .url(reservationListUrl)
                    .build()

                response = client.newCall(request).execute()
                val resourcesJson = response.body?.string() ?: "No response body"
                val resourcesMap: Map<String, Any> = gson.fromJson(resourcesJson, mapType)
                val resourceList = (resourcesMap["d"] as? Map<String, Any>)?.get("list") as? List<*>
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful && resourceList != null) {
                        callback(true, "Step 4: GET $reservationListUrl\nResources: ${resourceList.size}", null, null, null)
                    } else {
                        callback(false, "Step 4: GET $reservationListUrl\nResources: ${resourceList?.size ?: "N/A"}", null, null, null)
                    }
                }

                Log.v("MyTag", "$resourceList")

                val chosenBus = chooseBus(resourceList, isToYanyuan)
                Log.v("MyTag", "$chosenBus and direction $isToYanyuan")
                val chosenResourceId = chosenBus.first
                val chosenPeriod = chosenBus.second

                if (chosenResourceId == 0 || chosenPeriod == 0) {
                    withContext(Dispatchers.Main) {
                        callback(false, "No available bus found", null, null, null)
                    }
                    return@launch
                }

                // Step 5: Launch reservation
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
                        callback(true, "Step 5: POST https://wproc.pku.edu.cn/site/reservation/launch\n$launchResponse", null, null, null)
                    } else {
                        callback(false, "Step 5: POST https://wproc.pku.edu.cn/site/reservation/launch\n$launchResponse", null, null, null)
                    }
                }

                // Step 6: GET my reservations
                val myReservationsUrl = "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc"
                request = Request.Builder()
                    .url(myReservationsUrl)
                    .build()

                response = client.newCall(request).execute()
                val appsJson = response.body?.string() ?: "No response body"
                val appsMap: Map<String, Any> = gson.fromJson(appsJson, mapType)
                val formattedJson = formatMap(appsMap)
                val reservationData = (appsMap["d"] as? Map<String, Any>)?.get("data") as? List<Map<String, Any>>
                Log.v("MyTag", "reservationData is $reservationData")
                var reservationDetails: Map<String, Any>? = null
                if (reservationData != null) {
                    for (reservation in reservationData) {
                        val reservationResourceId = (reservation["resource_id"] as Double).toInt()
                        Log.v("MyTag", "reservationResourceId is $reservationResourceId, and isToYanyuan is $isToYanyuan")
                        if ((reservationResourceId in listOf(2, 4) && isToYanyuan) ||
                            (reservationResourceId in listOf(5, 6, 7) && !isToYanyuan)) {
                            reservationDetails = reservation
                            break
                        }
                    }
                }

                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        callback(true, "Step 6: GET $myReservationsUrl\nReservations: $formattedJson", null, reservationDetails, null)
                    } else {
                        callback(false, "Step 6: GET $myReservationsUrl\nReservations: $formattedJson", null, null, null)
                    }
                }

                // Step 7: Get QR code and cancel reservations
                val appData = (appsMap["d"] as? Map<String, Any>)?.get("data") as? List<Map<String, Any>>
                withContext(Dispatchers.Main) {
                    callback(true, "Step 7: Processing ${appData?.size ?: 0} reservations", null, null, null)
                }
                if (appData?.isNotEmpty() == true) {
                    appData.forEachIndexed { index, app ->
                        val appId = app["id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appId")
                        val appAppointmentId = app["hall_appointment_data_id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appAppointmentId")

                        withContext(Dispatchers.Main) {
                            callback(true, "Processing reservation ${index + 1}:", null, null, null)
                            callback(true, "  App ID: $appId", null, null, null)
                            callback(true, "  Appointment ID: $appAppointmentId", null, null, null)
                        }

                        if (appId != null && appAppointmentId != null) {
                            // Get QR code
                            val qrCodeUrl = "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=0&id=$appId&hall_appointment_data_id=$appAppointmentId"
                            request = Request.Builder()
                                .url(qrCodeUrl)
                                .build()

                            response = client.newCall(request).execute()
                            val qrCodeResponse = response.body?.string() ?: "No response body"
                            withContext(Dispatchers.Main) {
                                if (response.isSuccessful) {
                                    callback(true, "  QR Code response: $qrCodeResponse", null, null, null)

                                    // Parse the QR code response and generate the QR code bitmap
                                    val qrCodeJson = Gson().fromJson(qrCodeResponse, Map::class.java)
                                    val qrCodeData = (qrCodeJson["d"] as? Map<*, *>)?.get("code") as? String
                                    if (qrCodeData != null) {
                                        withContext(Dispatchers.Main) {
                                            callback(true, "QR Code string to decode: $qrCodeData", null, null, qrCodeData)
                                        }
                                        try {
                                            val qrCodeBitmap = generateQRCode(qrCodeData, 300, 300)
                                            callback(true, "QR Code generated", qrCodeBitmap, reservationDetails, qrCodeData)
                                        } catch (e: IllegalArgumentException) {
                                            withContext(Dispatchers.Main) {
                                                callback(false, "Failed to decode QR code: ${e.message}", null, null, qrCodeData)
                                            }
                                        }
                                    } else {
                                        withContext(Dispatchers.Main) {
                                            callback(false, "QR code data not found", null, null, null)
                                        }
                                    }
                                } else {
                                    callback(false, "QR Code response: $qrCodeResponse", null, null, null)
                                }
                            }
                        } else {
                            withContext(Dispatchers.Main) {
                                callback(false, "  Failed to process this reservation: missing ID or appointment ID", null, null, null)
                            }
                        }
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        callback(true, "No reservations to process", null, null, null)
                    }
                }

            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(false, "Failed to execute request: ${e.message}", null, null, null)
                    callback(false, "Stack trace: ${e.stackTraceToString()}", null, null, null)
                }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun chooseBus(resourceList: List<*>?, isToYanyuan: Boolean): Pair<Int, Int> {
        var chosenResourceId = 0
        var chosenPeriod = 0
        if (resourceList != null) {
            val currentTime = LocalDateTime.now(ZoneId.of("Asia/Shanghai"))
            for (bus in resourceList) {
                if (bus is Map<*, *>) {
                    val resourceIdStr = bus["id"] as Double
                    val resourceId = resourceIdStr.toInt()
                    val routeName = bus["name"] as String

                    if (!(resourceId in listOf(2, 4) && isToYanyuan || resourceId in listOf(5, 6, 7) && !isToYanyuan)) {
                        continue
                    }

                    val periods = (bus["table"] as Map<String, List<Map<String, Any>>>).values.first()
                    Log.v("periods", "$periods")
                    for (period in periods) {
                        val timeId = (period["time_id"] as Double).toInt()
                        val date = period["date"] as String
                        val startTime = period["yaxis"] as String
                        val margin = ((period["row"] as Map<String, Any>)["margin"] as Double).toInt()
                        if (margin == 0) {
                            continue
                        }

                        val naiveDateTime = LocalDateTime.parse(
                            "$date $startTime",
                            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
                        )
                        val awareDateTime = naiveDateTime.atZone(ZoneId.of("Asia/Shanghai"))
                        val timeDiffWithSign = Duration.between(currentTime, awareDateTime).toMinutes()
                        val hasExpiredBus = -Settings.PREV_INTERVAL < timeDiffWithSign && timeDiffWithSign < 0
                        val hasFutureBus = 0 <= timeDiffWithSign && timeDiffWithSign < Settings.NEXT_INTERVAL

                        if (!hasExpiredBus && !hasFutureBus) {
                            continue
                        }
                        Log.v("details", "$routeName at $date $startTime has a valid bus")
                        chosenResourceId = resourceId
                        chosenPeriod = timeId
                        Log.v("details", "chosenResourceId $chosenResourceId chosenPeriod $chosenPeriod")
                        break
                    }
                }
            }
        }
        return Pair(chosenResourceId, chosenPeriod)
    }

    private fun generateQRCode(content: String, width: Int, height: Int): Bitmap {
        val writer = QRCodeWriter()
        val bitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, width, height)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
        for (x in 0 until width) {
            for (y in 0 until height) {
                bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
            }
        }
        return bitmap
    }

    private fun formatMap(map: Map<String, Any>): String {
        return map.entries.joinToString(", ", "{", "}") { (k, v) ->
            "\"$k\": ${formatValue(v)}"
        }
    }

    private fun formatValue(value: Any?): String {
        return when (value) {
            is Map<*, *> -> formatMap(value as Map<String, Any>)
            is List<*> -> value.joinToString(", ", "[", "]") { formatValue(it) }
            is String -> "\"$value\""
            is Number, is Boolean -> value.toString()
            null -> "null"
            else -> "\"$value\""
        }
    }

    private fun saveLoginInfo(username: String, password: String) {
        val sharedPreferences = getSharedPreferences("LoginPrefs", Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putString("username", username)
            putString("password", password)
            apply()
        }
    }

    private fun clearLoginInfo() {
        val sharedPreferences = getSharedPreferences("LoginPrefs", Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            remove("username")
            remove("password")
            apply()
        }
    }
}

object Settings {
    private const val PREFS_NAME = "SettingsPrefs"
    private const val KEY_PREV_INTERVAL = "prev_interval"
    private const val KEY_NEXT_INTERVAL = "next_interval"
    private const val DEFAULT_PREV_INTERVAL = 30
    private const val DEFAULT_NEXT_INTERVAL = 300

    var PREV_INTERVAL = DEFAULT_PREV_INTERVAL
        private set
    var NEXT_INTERVAL = DEFAULT_NEXT_INTERVAL
        private set

    fun load(context: Context) {
        val sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        PREV_INTERVAL = sharedPreferences.getInt(KEY_PREV_INTERVAL, DEFAULT_PREV_INTERVAL)
        NEXT_INTERVAL = sharedPreferences.getInt(KEY_NEXT_INTERVAL, DEFAULT_NEXT_INTERVAL)
    }

    fun save(context: Context) {
        val sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putInt(KEY_PREV_INTERVAL, PREV_INTERVAL)
            putInt(KEY_NEXT_INTERVAL, NEXT_INTERVAL)
            apply()
        }
    }

    fun updatePrevInterval(context: Context, value: Int) {
        PREV_INTERVAL = value
        save(context)
    }

    fun updateNextInterval(context: Context, value: Int) {
        NEXT_INTERVAL = value
        save(context)
    }
}

@Composable
fun LoadingScreen() {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.fillMaxSize()
    ) {
        CircularProgressIndicator()
    }
}

@Composable
fun LoginScreen(onLogin: (String, String) -> Unit) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "三、二、一，马池口！",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(bottom = 32.dp)
        )

        OutlinedTextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("用户名") },
            leadingIcon = { Icon(Icons.Default.Person, contentDescription = "用户名") },
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("密码") },
            visualTransformation = PasswordVisualTransformation(),
            leadingIcon = { Icon(Icons.Default.Lock, contentDescription = "密码") },
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        Button(
            onClick = { onLogin(username, password) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp)
                .height(50.dp),
            shape = RoundedCornerShape(8.dp)
        ) {
            Text("登录")
        }
    }
}


@Composable
fun DetailScreen(
    responseTexts: List<String>,
    qrCodeBitmap: Bitmap?,
    reservationDetails: Map<String, Any>?,
    onLogout: () -> Unit,
    onToggleBusDirection: () -> Unit,
    onShowLogs: () -> Unit,
    onEditSettings: () -> Unit
) {
    var isButtonEnabled by remember { mutableStateOf(true) }
    var showSnackbar by remember { mutableStateOf(false) }
    var snackbarMessage by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(rememberScrollState())
    ) {
        reservationDetails?.let { details ->
            val creatorName = details["creator_name"] as? String ?: "N/A"
            val resourceName = details["resource_name"] as? String ?: "N/A"
            val periodText = (details["period_text"] as? Map<*, *>)?.values?.firstOrNull() as? Map<*, *>
            val period = (periodText?.get("text") as? List<*>)?.firstOrNull() as? String ?: "N/A"

            qrCodeBitmap?.let { bitmap ->
                Card(
                    modifier = Modifier
                        .padding(16.dp)
                        .fillMaxWidth(),
                    elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "欢迎，$creatorName",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(bottom = 16.dp)
                        )
                        Divider(color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.3f))
                        Spacer(modifier = Modifier.height(16.dp))

                        Surface(
                            modifier = Modifier.fillMaxWidth(),
                            color = MaterialTheme.colorScheme.primary,
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                                horizontalAlignment = Alignment.Start
                            ) {
                                ReservationDetailRow(label = "路线", value = resourceName)
                                ReservationDetailRow(label = "时间", value = period)
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = "QR Code",
                            modifier = Modifier.size(200.dp)
                        )
                    }
                }
            } ?: Text("没有找到二维码或预约信息", color = MaterialTheme.colorScheme.error)
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            Button(
                onClick = onShowLogs,
                modifier = Modifier.weight(1f).padding(end = 8.dp)
            ) {
                Text("查看log")
            }

            Button(
                onClick = onToggleBusDirection,
                modifier = Modifier.weight(1f).padding(start = 8.dp, end = 8.dp)
            ) {
                Text("乘坐反向班车")
            }

            Button(
                onClick = onEditSettings,
                modifier = Modifier.weight(1f).padding(start = 8.dp)
            ) {
                Text("编辑配置")
            }

            Button(
                onClick = onLogout,
                modifier = Modifier.weight(1f).padding(start = 8.dp)
            ) {
                Text("Logout")
            }
        }
    }

    if (showSnackbar) {
        Snackbar(
            modifier = Modifier
                .padding(16.dp)
                .defaultMinSize(minWidth = 150.dp)
        ) {
            Text(snackbarMessage, color = MaterialTheme.colorScheme.onSecondary)
        }
    }
}

@Composable
fun LogScreen(responseTexts: List<String>, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Button(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        ) {
            Text("返回")
        }

        Card(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalAlignment = Alignment.Start
            ) {
                Text(
                    text = "Logs:",
                    fontSize = 20.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                responseTexts.forEach { responseText ->
                    Text(
                        text = responseText,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
fun ErrorScreen(message: String, onRetry: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.fillMaxSize().padding(16.dp)
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
fun ReservationDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Text(text = value, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
    }
}

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(),
        content = content
    )
}
