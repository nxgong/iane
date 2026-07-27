package com.example.iane

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val LOGIN_CHANNEL = "location"
        private const val LOCATION_CHANNEL = "location_service"
        private const val PREF_NAME = "USER_INFO"
        private const val KEY_USER_ID = "USER_ID"
        private const val KEY_USER_NM = "USER_NM"
        private const val KEY_USER_TYPE = "USER_TYPE"
        private const val KEY_COMPANY_CD = "COMPANY_CD"
        private const val KEY_LOCATION_SEND_YN = "LOCATION_SEND_YN"
        private const val KEY_LOCATION_SEND_MIN = "LOCATION_SEND_MIN"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        /**
         * 로그인 정보 저장
         * Flutter :
         * MethodChannel("location")
         * invokeMethod("setLoginInfo", ...)
         */
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOGIN_CHANNEL
        ).setMethodCallHandler { call, result ->

            Log.d("LocationService", "★★★★★ LOGIN_CHANNEL : ${call.method}")
            when (call.method) {
                "setLoginInfo" -> {
                    val userId = call.argument<String>("userId") ?: ""
                    val userNm = call.argument<String>("userNm") ?: ""
                    val userType = call.argument<String>("userType") ?: ""
                    val companyCd = call.argument<String>("companyCd") ?: ""
                    // 20260722 추가
                    val locationSendYn = call.argument<String>("locationSendYn") ?: ""
                    val locationSendMin = call.argument<String>("locationSendMin") ?: ""

                    // 20260722 locationSendYn  locationSendMin 추가
                    saveUserInfo(userId, userNm, userType, companyCd, locationSendYn, locationSendMin)
                    Log.d(
                        "LocationService",
                        """
                        ★★★★★ 로그인 정보 저장
                        USER_ID=$userId
                        USER_NM=$userNm
                        USER_TYPE=$userType
                        COMPANY_CD=$companyCd
                        """.trimIndent()
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        /**
         * 위치 서비스 제어
         * Flutter :
         * MethodChannel("location_service")
         * invokeMethod("startLocationService")
         */
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            Log.d("LocationService", "★★★★★ LOCATION_CHANNEL : ${call.method}")
            when (call.method) {
                "startLocationService" -> {
                    val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
                    val userId = prefs.getString(KEY_USER_ID, "") ?: ""
                    Log.d("LocationService", "★★★★★ startLocationService USER_ID=$userId")
                    startLocationService(userId)
                    result.success(true)
                }

                "stopLocationService" -> {
                    Log.d("LocationService", "★★★★★ stopLocationService")
                    stopLocationService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 로그인 정보 저장
     */
    private fun saveUserInfo(
        userId: String,
        userNm: String,
        userType: String,
        companyCd: String,
        // 20260722
        locationSendYn: String,
        locationSendMin: String
    ) {
        getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_USER_ID, userId)
            .putString(KEY_USER_NM, userNm)
            .putString(KEY_USER_TYPE, userType)
            .putString(KEY_COMPANY_CD, companyCd)
            .putString(KEY_LOCATION_SEND_YN, locationSendYn)
            .putString(KEY_LOCATION_SEND_MIN, locationSendMin)
            .apply()
    }

    /**
     * 위치 서비스 시작
     */
    private fun startLocationService(userId: String) {

        if (userId.isBlank()) {
            Log.e("LocationService", "USER_ID 없음. 위치 서비스 시작 취소")
            return
        }

        val intent = Intent(this, LocationService::class.java).apply {
            putExtra("USER_ID", userId)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }

        Log.d(
            "LocationService",
            """
            ★★★★★ 위치 서비스 시작
            USER_ID=$userId
            """.trimIndent()
            )
        }

    /**
     * 위치 서비스 종료
     */
    private fun stopLocationService() {

        stopService(Intent(this, LocationService::class.java))
        Log.d("LocationService", "★★★★★ 위치 서비스 종료")
    }
}