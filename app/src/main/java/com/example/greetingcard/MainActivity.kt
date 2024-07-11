package com.example.greetingcard

import android.graphics.Bitmap
import android.graphics.Color
import android.os.Bundle
import android.util.Base64
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import okhttp3.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import java.text.SimpleDateFormat
import java.util.*

class SimpleCookieJar : CookieJar {
    private val cookieStore = HashMap<String, List<Cookie>>()

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        cookieStore[url.host] = cookies
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val cookies = cookieStore[url.host]
        return cookies ?: ArrayList()
    }
}

class MainActivity : ComponentActivity() {
    private val client by lazy {
        OkHttpClient.Builder()
            .cookieJar(SimpleCookieJar())
            .build()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    var responseTexts by remember { mutableStateOf(listOf<String>()) }
                    var qrCodeBitmap by remember { mutableStateOf<Bitmap?>(null) }

                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp)
                            .verticalScroll(rememberScrollState())
                    ) {
                        Greeting(
                            name = "Android",
                            responseTexts = responseTexts,
                            qrCodeBitmap = qrCodeBitmap,
                            onLogin = { username, password ->
                                performLogin(username, password) { response, bitmap ->
                                    responseTexts = responseTexts + response
                                    qrCodeBitmap = bitmap
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private fun performLogin(username: String, password: String, callback: (String, Bitmap?) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Step 1: GET request
                var request = Request.Builder()
                    .url("https://wproc.pku.edu.cn/api/login/main")
                    .build()
                var response = client.newCall(request).execute()
                withContext(Dispatchers.Main) {
                    callback("Step 1: GET https://wproc.pku.edu.cn/api/login/main\n${response.code}", null)
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
                    callback("Step 2: POST https://iaaa.pku.edu.cn/iaaa/oauthlogin.do\nToken: $token", null)
                }

                // Step 3: GET request with token
                val urlWithToken = "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&token=$token"
                request = Request.Builder()
                    .url(urlWithToken)
                    .build()

                response = client.newCall(request).execute()
                withContext(Dispatchers.Main) {
                    callback("Step 3: GET $urlWithToken\n${response.code}", null)
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
                    callback("Step 4: GET $reservationListUrl\nResources: ${resourceList?.size ?: "N/A"}", null)
                }

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
                    callback("Step 5: POST https://wproc.pku.edu.cn/site/reservation/launch\n$launchResponse", null)
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
                withContext(Dispatchers.Main) {
                    callback("Step 6: GET $myReservationsUrl\nReservations: $formattedJson", null)
                }

                // Step 7: Get QR code and cancel reservations
                val appData = (appsMap["d"] as? Map<String, Any>)?.get("data") as? List<Map<String, Any>>
                withContext(Dispatchers.Main) {
                    callback("Step 7: Processing ${appData?.size ?: 0} reservations", null)
                }
                if (appData?.isNotEmpty() == true) {
                    appData.forEachIndexed { index, app ->
                        val appId = app["id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appId")
                        val appAppointmentId = app["hall_appointment_data_id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appAppointmentId")

                        withContext(Dispatchers.Main) {
                            callback("Processing reservation ${index + 1}:", null)
                            callback("  App ID: $appId", null)
                            callback("  Appointment ID: $appAppointmentId", null)
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
                                callback("  QR Code response: $qrCodeResponse", null)

                                // Parse the QR code response and generate the QR code bitmap
                                val qrCodeJson = Gson().fromJson(qrCodeResponse, Map::class.java)
                                val qrCodeData = (qrCodeJson["d"] as? Map<*, *>)?.get("code") as? String
                                if (qrCodeData != null) {
                                    val decodedQrCode = String(Base64.decode(qrCodeData, Base64.DEFAULT))
                                    val qrCodeBitmap = generateQRCode(decodedQrCode, 300, 300)
                                    callback("QR Code generated", qrCodeBitmap)
                                }
                            }

                            // Cancel reservation
//                            val cancelBody = FormBody.Builder()
//                                .add("appointment_id", appId)
//                                .add("data_id[0]", appAppointmentId)
//                                .build()
//
//                            request = Request.Builder()
//                                .url("https://wproc.pku.edu.cn/site/reservation/single-time-cancel")
//                                .post(cancelBody)
//                                .build()
//
//                            response = client.newCall(request).execute()
//                            val cancelResponse = response.body?.string() ?: "No response body"
//                            withContext(Dispatchers.Main) {
//                                callback("  Cancel response: $cancelResponse", null)
//                            }
                        } else {
                            withContext(Dispatchers.Main) {
                                callback("  Failed to process this reservation: missing ID or appointment ID", null)
                            }
                        }
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        callback("No reservations to process", null)
                    }
                }

            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback("Failed to execute request: ${e.message}", null)
                    callback("Stack trace: ${e.stackTraceToString()}", null)
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
}

@Composable
fun Greeting(name: String, responseTexts: List<String>, qrCodeBitmap: Bitmap?, onLogin: (String, String) -> Unit) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    Column {
        Text(text = "Hello $name!")
        Spacer(modifier = Modifier.height(8.dp))
        TextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Username") }
        )
        Spacer(modifier = Modifier.height(8.dp))
        TextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation()
        )
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = { onLogin(username, password) }) {
            Text("Login")
        }
        Spacer(modifier = Modifier.height(16.dp))
        for (responseText in responseTexts) {
            Text(text = responseText)
            Spacer(modifier = Modifier.height(8.dp))
        }
        qrCodeBitmap?.let { bitmap ->
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "QR Code",
                modifier = Modifier.size(300.dp)
            )
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