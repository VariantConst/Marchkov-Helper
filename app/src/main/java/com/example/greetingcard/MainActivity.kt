package com.example.greetingcard

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Bundle
import android.util.Base64
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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
import java.util.*
import androidx.compose.foundation.shape.RoundedCornerShape
import android.util.Log

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
    private val cookieJar = SimpleCookieJar()
    private val client by lazy {
        OkHttpClient.Builder()
            .cookieJar(cookieJar)
            .build()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sharedPreferences = getSharedPreferences("LoginPrefs", Context.MODE_PRIVATE)
        val savedUsername = sharedPreferences.getString("username", null)
        val savedPassword = sharedPreferences.getString("password", null)

        setContent {
            AppTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    var responseTexts by remember { mutableStateOf(listOf<String>()) }
                    var qrCodeBitmap by remember { mutableStateOf<Bitmap?>(null) }
                    var reservationDetails by remember { mutableStateOf<Map<String, Any>?>(null) }
                    var qrCodeString by remember { mutableStateOf<String?>(null) }
                    var isLoggedIn by remember { mutableStateOf(false) }
                    var showLoading by remember { mutableStateOf(true) }

                    LaunchedEffect(Unit) {
                        if (savedUsername != null && savedPassword != null) {
                            performLogin(savedUsername, savedPassword) { success, response, bitmap, details, qrCode ->
                                if (success) {
                                    isLoggedIn = true
                                    showLoading = false
                                }
                                responseTexts = responseTexts + response
                                qrCodeBitmap = bitmap
                                reservationDetails = details
                                qrCodeString = qrCode
                            }
                        } else {
                            showLoading = false
                        }
                    }

                    Box(modifier = Modifier.fillMaxSize()) {
                        AnimatedVisibility(visible = showLoading) {
                            LoadingScreen()
                        }

                        if (!showLoading) {
                            if (isLoggedIn) {
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
                                        cookieJar.clearCookies()
                                        clearLoginInfo()
                                    }
                                )
                            } else {
                                LoginScreen(
                                    onLogin = { username, password ->
                                        performLogin(username, password) { success, response, bitmap, details, qrCode ->
                                            if (success) {
                                                isLoggedIn = true
                                                showLoading = false
                                                saveLoginInfo(username, password)
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
                    }
                }
            }
        }
    }

    private fun performLogin(
        username: String,
        password: String,
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
                    callback(false, "Step 1: GET https://wproc.pku.edu.cn/api/login/main\n${response.code}", null, null, null)
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
                    callback(false, "Step 2: POST https://iaaa.pku.edu.cn/iaaa/oauthlogin.do\nToken: $token", null, null, null)
                }

                // Step 3: GET request with token
                val urlWithToken = "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&token=$token"
                request = Request.Builder()
                    .url(urlWithToken)
                    .build()

                response = client.newCall(request).execute()
                withContext(Dispatchers.Main) {
                    callback(false, "Step 3: GET $urlWithToken\n${response.code}", null, null, null)
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
                    callback(false, "Step 4: GET $reservationListUrl\nResources: ${resourceList?.size ?: "N/A"}", null, null, null)
                }

                Log.v("MyTag", "$resourceList")

                // Step 5: Launch reservation
                val launchBody = FormBody.Builder()
                    .add("resource_id", "7")
                    .add("data", "[{\"date\": \"$date\", \"period\": 47, \"sub_resource_id\": 0}]")
                    .build()
                request = Request.Builder()
                    .url("https://wproc.pku.edu.cn/site/reservation/launch")
                    .post(launchBody)
                    .build()

                response = client.newCall(request).execute()
                val launchResponse = response.body?.string() ?: "No response body"
                withContext(Dispatchers.Main) {
                    callback(false, "Step 5: POST https://wproc.pku.edu.cn/site/reservation/launch\n$launchResponse", null, null, null)
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
                val reservationDetails = reservationData?.firstOrNull()
                withContext(Dispatchers.Main) {
                    callback(true, "Step 6: GET $myReservationsUrl\nReservations: $formattedJson", null, reservationDetails, null)
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
                                callback(true, "  QR Code response: $qrCodeResponse", null, null, null)

                                // Parse the QR code response and generate the QR code bitmap
                                val qrCodeJson = Gson().fromJson(qrCodeResponse, Map::class.java)
                                val qrCodeData = (qrCodeJson["d"] as? Map<*, *>)?.get("code") as? String
                                if (qrCodeData != null) {
                                    withContext(Dispatchers.Main) {
                                        callback(true, "QR Code string to decode: $qrCodeData", null, null,qrCodeData)
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
                            }

                            // Cancel reservation
                            // val cancelBody = FormBody.Builder()
                            //     .add("appointment_id", appId)
                            //     .add("data_id[0]", appAppointmentId)
                            //     .build()
                            //
                            // request = Request.Builder()
                            //     .url("https://wproc.pku.edu.cn/site/reservation/single-time-cancel")
                            //     .post(cancelBody)
                            //     .build()
                            //
                            // response = client.newCall(request).execute()
                            // val cancelResponse = response.body?.string() ?: "No response body"
                            // withContext(Dispatchers.Main) {
                            //     callback("  Cancel response: $cancelResponse", null, null, null)
                            // }
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
        TextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Username") },
            modifier = Modifier.fillMaxWidth()
        )

        TextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth()
        )

        Button(
            onClick = { onLogin(username, password) },
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp)
        ) {
            Text("Login")
        }
    }
}

@Composable
fun DetailScreen(
    responseTexts: List<String>,
    qrCodeBitmap: Bitmap?,
    reservationDetails: Map<String, Any>?,
    onLogout: () -> Unit
) {
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
            }
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

        Button(
            onClick = onLogout,
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp)
        ) {
            Text("Logout")
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
