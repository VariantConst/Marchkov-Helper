package com.variantconst.marchkov.utils

import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.*
import okhttp3.*
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import org.json.JSONObject

// 在文件顶部添加这个数据类定义
data class RideInfo(
    val id: Int,
    val statusName: String,
    val resourceName: String,
    val appointmentTime: String,
    val appointmentSignTime: String?
)

class ReservationManager(private val context: Context) {
    private val gson = Gson()

    @RequiresApi(Build.VERSION_CODES.O)
    fun performLogin(
        username: String,
        password: String,
        isToYanyuan: Boolean,
        updateLoadingMessage: (String) -> Unit,
        callback: (Boolean, String, Bitmap?, Map<String, Any>?, String?) -> Unit,
        timeoutJob: Job?
    ) {
        val client = OkHttpClient.Builder()
            .cookieJar(SimpleCookieJar())
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
                val mapType = object : TypeToken<Map<String, Any>>() {}.type
                val jsonMap: Map<String, Any> = gson.fromJson(responseBody, mapType)
                val token = jsonMap["token"] as? String ?: "Token not found"
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful && token.isNotEmpty()) {
                        callback(true, "第一步：登录账号成功\n获取 token 为 $token", null, null, null)
                    } else {
                        callback(false, "第一步登录账号失败\n获取 token 为 $token", null, null, null)
                    }
                }

                val urlWithToken = "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&token=$token"
                request = Request.Builder()
                    .url(urlWithToken)
                    .build()

                response = client.newCall(request).execute()
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        callback(true, "第二步：跟随重定向成功\n结果：${response.code}", null, null, null)
                    } else {
                        callback(false, "第二步：跟随重定向失败\n结果：${response.code}", null, null, null)
                    }
                }

                updateLoadingMessage("正在获取预约列表...")
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
                        callback(false, "第三步：获取班车信息败", null, null, null)
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

                if (isTemp) {
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
                            val creatorNameFull = (qrCodeJson["d"] as? Map<*, *>)?.get("name") as? String
                            val creatorName = creatorNameFull?.split("\r\n")?.get(0) ?: "马池口🐮🐴"
                            val creatorDepart = creatorNameFull?.split("\r\n")?.get(2) ?: "这个需要你自己衡量！"
                            saveRealName(creatorName)
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
                            callback(false, "第四步：预约班车失败\n响应为 $launchResponse", null, null, null)
                        }
                    }

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
                                val creatorName = reservation["creator_name"] as? String ?: "马池口🐮🐴"
                                val creatorDepart = reservation["creator_depart"] as? String ?: "这个需要你自己衡量！"
                                saveRealName(creatorName)
                                saveDepartment(creatorDepart)
                                reservationDetails = mapOf<String, Any>(
                                    "creator_name" to creatorName,
                                    "resource_name" to reservation["resource_name"] as String,
                                    "start_time" to startTime,
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
                            callback(false, "第五步：获取已约班车信息失败\n响应：$formattedJson", null, null, null)
                        }
                    }

                    updateLoadingMessage("正在生成二维码...")
                    val appData: List<Map<String, Any>>? = (appsMap["d"] as? Map<*, *>)?.let { map ->
                        (map["data"] as? List<*>)?.filterIsInstance<Map<String, Any>>()
                    }
                    withContext(Dispatchers.Main) {
                        callback(true, "Step 7: Processing ${appData?.size ?: 0} reservations", null, null, null)
                    }
                    if (appData?.isNotEmpty() == true) {
                        appData.forEachIndexed { index, app ->
                            try {
                                val appId = app["id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appId")
                                val appAppointmentId = app["hall_appointment_data_id"]?.toString()?.substringBefore(".") ?: throw IllegalArgumentException("Invalid appAppointmentId")

                                // 添加合法性检查
                                val appResourceId = (app["resource_id"] as? Double)?.toInt() ?: throw IllegalArgumentException("Invalid resourceId")
                                val appTime = (app["appointment_tim"] as? String)?.trim() ?: throw IllegalArgumentException("Invalid appointment_time")

                                val dateFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                                val today = dateFormatter.format(Date())

                                if (appResourceId == chosenResourceId && appTime.startsWith("$today $startTime")) {
                                    withContext(Dispatchers.Main) {
                                        callback(true, "正在为 $startTime 处理第 ${index + 1} 个预约:", null, null, null)
                                        callback(true, "  App ID: $appId", null, null, null)
                                        callback(true, "  Appointment ID: $appAppointmentId", null, null, null)
                                    }

                                    val qrCodeUrl = "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=0&id=$appId&hall_appointment_data_id=$appAppointmentId"
                                    val request = Request.Builder()
                                        .url(qrCodeUrl)
                                        .build()

                                    val response = client.newCall(request).execute()
                                    val qrCodeResponse = response.body?.string() ?: "No response body"
                                    withContext(Dispatchers.Main) {
                                        if (response.isSuccessful) {
                                            callback(true, " 乘车码响应: $qrCodeResponse", null, null, null)

                                            val qrCodeJson = gson.fromJson(qrCodeResponse, Map::class.java)
                                            val qrCodeData = (qrCodeJson["d"] as? Map<*, *>)?.get("code") as? String
                                            if (qrCodeData != null) {
                                                withContext(Dispatchers.Main) {
                                                    callback(true, "要解的乘车码字符串: $qrCodeData", null, null, qrCodeData)
                                                }
                                                try {
                                                    val qrCodeBitmap = generateQRCode(qrCodeData)
                                                    callback(true, "乘车码码成功", qrCodeBitmap, reservationDetails, qrCodeData)
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
                            } catch (e: IllegalArgumentException) {
                                withContext(Dispatchers.Main) {
                                    callback(false, "预约信息无效: ${e.message}", null, null, null)
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

    private fun saveRealName(realName: String) {
        val sharedPreferences = context.getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        val currentRealName = sharedPreferences.getString("realName", null)
        if (currentRealName == null || realName == "马池口🐮🐴") {
            with(sharedPreferences.edit()) {
                putString("realName", realName)
                apply()
            }
        }
    }

    private fun saveDepartment(department: String) {
        val sharedPreferences = context.getSharedPreferences("user_prefs", Context.MODE_PRIVATE)
        val currentDepartment = sharedPreferences.getString("department", null)
        if (currentDepartment == null || department == "这个需要你自己衡量！") {
            with(sharedPreferences.edit()) {
                putString("department", department)
                apply()
            }
        }
    }

    private fun cancelLoadingTimeout(job: Job?) {
        job?.cancel()
    }

    @RequiresApi(Build.VERSION_CODES.O)
    fun getReservationHistory(
        username: String,
        password: String,
        callback: (Boolean, String, List<RideInfo>?) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val client = OkHttpClient.Builder()
                    .cookieJar(SimpleCookieJar())
                    .connectTimeout(30, TimeUnit.SECONDS)
                    .readTimeout(30, TimeUnit.SECONDS)
                    .writeTimeout(30, TimeUnit.SECONDS)
                    .build()

                // 登录
                val loginSuccess = performLoginForHistory(username, password, client)
                if (!loginSuccess) {
                    withContext(Dispatchers.Main) {
                        callback(false, "登录失败", null)
                    }
                    return@launch
                }

                // 获取历史记录
                val request = Request.Builder()
                    .url("https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=0&status=0&sort_time=true&sort=desc")
                    .build()

                val response = client.newCall(request).execute()
                val responseBody = response.body?.string() ?: "No response body"
                
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        val jsonObject = JSONObject(responseBody)
                        val dataArray = jsonObject.getJSONObject("d").getJSONArray("data")
                        val rideInfoList = mutableListOf<RideInfo>()

                        for (i in 0 until dataArray.length()) {
                            val ride = dataArray.getJSONObject(i)
                            val statusName = ride.getString("status_name")
                            if (statusName != "已撤销") {
                                rideInfoList.add(
                                    RideInfo(
                                        id = ride.getInt("id"),
                                        statusName = statusName,
                                        resourceName = ride.getString("resource_name"),
                                        appointmentTime = ride.getString("appointment_tim").trim(),
                                        appointmentSignTime = ride.optString("appointment_sign_time", null)?.trim()
                                    )
                                )
                            }
                        }

                        // 保存到 SharedPreferences
                        saveRideInfoListToSharedPreferences(rideInfoList)

                        callback(true, responseBody, rideInfoList)
                    } else {
                        callback(false, "获取历史记录失败: $responseBody\n响应码: ${response.code}", null)
                    }
                }
            } catch (e: Exception) {
                val errorMessage = when (e) {
                    is SocketTimeoutException -> "连接超时: ${e.message}"
                    is ConnectException -> "连接失败: ${e.message}"
                    is UnknownHostException -> "无法解析主机: ${e.message}"
                    else -> "发生错误: ${e.message}\n${e.stackTraceToString()}"
                }
                withContext(Dispatchers.Main) {
                    callback(false, errorMessage, null)
                }
            }
        }
    }

    private suspend fun performLoginForHistory(username: String, password: String, client: OkHttpClient): Boolean {
        val formBody = FormBody.Builder()
            .add("appid", "wproc")
            .add("userName", username)
            .add("password", password)
            .add("redirUrl", "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/")
            .build()

        val request = Request.Builder()
            .url("https://iaaa.pku.edu.cn/iaaa/oauthlogin.do")
            .post(formBody)
            .build()

        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: "No response body"
        val jsonMap: Map<String, Any> = gson.fromJson(responseBody, object : TypeToken<Map<String, Any>>() {}.type)
        val token = jsonMap["token"] as? String ?: return false

        val urlWithToken = "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&token=$token"
        val redirectRequest = Request.Builder()
            .url(urlWithToken)
            .build()

        val redirectResponse = client.newCall(redirectRequest).execute()
        return redirectResponse.isSuccessful
    }

    private fun saveRideInfoListToSharedPreferences(rideInfoList: List<RideInfo>) {
        val sharedPreferences = context.getSharedPreferences("ride_history", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        val gson = Gson()
        val json = gson.toJson(rideInfoList)
        editor.putString("ride_info_list", json)
        editor.apply()
    }

    fun getRideInfoListFromSharedPreferences(): List<RideInfo> {
        val sharedPreferences = context.getSharedPreferences("ride_history", Context.MODE_PRIVATE)
        val json = sharedPreferences.getString("ride_info_list", null)
        return if (json != null) {
            val gson = Gson()
            val type = object : TypeToken<List<RideInfo>>() {}.type
            gson.fromJson(json, type)
        } else {
            emptyList()
        }
    }
}

data class BusInfo(
    val resourceId: Int,
    val resourceName: String,
    val startTime: String,
    val isTemp: Boolean,
    val period: Int?
)
