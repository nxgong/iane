package com.example.iane

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import java.net.HttpURLConnection
import java.net.URL
import android.content.Context

class LocationService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var userId: String = ""
    private var userNm: String = ""
    private var userType: String = ""
    private var companyCd: String = ""
    // 20260722 추가
    private var locationSendYn: String = ""
    private var locationSendMin: String = ""

    private var lastSendTime = 0L
    private val SEND_INTERVAL = 5 * 60 * 1000L   // 5분

    override fun onCreate() {
        super.onCreate()

        Log.d("LocationService", "★★★★★ LocationService 시작")
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                //val sendIntervalMin = locationSendMin.toLongOrNull() ?: return
                val sendIntervalMin = locationSendMin.toLongOrNull()
                if (sendIntervalMin == null) {
                    Log.d("LocationService", "LOCATION_SEND_MIN 없음")
                    return
                }
                val sendInterval = sendIntervalMin * 60 * 1000L
                val now = System.currentTimeMillis()

                for (location in result.locations) {
                    Log.d("LocationService", "위치 수신 USER=$userId LAT=${location.latitude} LNG=${location.longitude}")

                    if (now - lastSendTime >= sendInterval) {
                        lastSendTime = now
                        Log.d("LocationService", "★★★★★ ${locationSendMin}분 경과 → 위치 저장")
                        saveLocation(location.latitude, location.longitude)
                    } else {
                        val remainSec = (sendInterval - (now - lastSendTime)) / 1000
                        Log.d("LocationService", "${locationSendMin}분 미경과 → 저장 안함 (남은 ${remainSec}초)")
                    }
                }
            }
        }
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        Log.d("LocationService", "onStartCommand 호출")
        userId = intent?.getStringExtra("USER_ID") ?: ""
        Log.d("LocationService", "USER_ID=$userId")
        val prefs = getSharedPreferences("USER_INFO", Context.MODE_PRIVATE)
        userId = prefs.getString("USER_ID", "") ?: ""
        userNm = prefs.getString("USER_NM", "") ?: ""
        userType = prefs.getString("USER_TYPE", "") ?: ""
        companyCd = prefs.getString("COMPANY_CD", "") ?: ""
        // 20260722 추가
        locationSendYn = prefs.getString("LOCATION_SEND_YN", "") ?: ""
        //locationSendYn = prefs.getString("LOCATION_SEND_MIN", "") ?: ""
        locationSendMin = prefs.getString("LOCATION_SEND_MIN", "") ?: ""

        Log.d(
            "LocationService",
            """
            USER_ID=$userId
            USER_NM=$userNm
            USER_TYPE=$userType
            COMPANY_CD=$companyCd
            LOCATION_SEND_YN=$locationSendYn
            LOCATION_SEND_MIN=$locationSendMin
            """.trimIndent()
        )

        if (userId.isBlank()) {
            Log.e("LocationService", "USER_ID 없음")
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(1001, createNotification())
        startLocation()
        return START_STICKY
    }

    private fun startLocation() {

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            10000   // 10000 → 위치 요청 주기(10초)
        ).setMinUpdateIntervalMillis(50000) // 5000 → 최소 업데이트 간격(5초)
            .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                request,
                locationCallback,
                mainLooper
            )
            Log.d("LocationService", "GPS 추적 시작")
        } catch (e: SecurityException) {
            Log.e("LocationService", "위치 권한 없음 ${e.message}")
        }
    }

    private fun saveLocation(latitude: Double, longitude: Double) {

        // 20260722 추가 locationSendYn != "Y"
        if (userId.isBlank() || locationSendYn != "Y") {
            Log.d("LocationService", "위치 저장 건너뜀 USER_ID=$userId LOCATION_SEND_YN=$locationSendYn")
            return
        }

        Thread {
            try {
                val url = URL("https://erp.easisoft.co.kr/admin/userLocationInsert.do")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.useCaches = false
                conn.setRequestProperty( "Content-Type",  "application/x-www-form-urlencoded" )

                val param =
                    "userId=$userId" +
                            "&userNm=$userNm" +
                            "&userType=$userType" +
                            "&companyCd=$companyCd" +
                            "&latitude=$latitude" +
                            "&longitude=$longitude" +
                            "&osType=AndroidApp"

                Log.d("LocationService", "PARAM=$param")
                conn.outputStream.use {
                    it.write(param.toByteArray(Charsets.UTF_8))
                    it.flush()
                }

                val responseCode = conn.responseCode
                val response = conn.inputStream.bufferedReader().use { it.readText() }
                Log.d("LocationService", "responseCode=$responseCode")
                Log.d("LocationService", "response=$response")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e("LocationService", "저장 실패", e)
            }
        }.start()
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, "location_channel")
            .setContentTitle("위치 서비스 실행 중")
            .setContentText("현재 위치를 저장하고 있습니다.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "location_channel",
                "위치 추적",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("LocationService", "★★★★★ LocationService 종료")
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}