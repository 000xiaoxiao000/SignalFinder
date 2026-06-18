package com.example.netboost

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.CellInfo
import android.telephony.CellInfoCdma
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoTdscdma
import android.telephony.CellInfoWcdma
import android.telephony.ServiceState
import android.telephony.SignalStrength
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt
import java.util.concurrent.Executor

class MainActivity : FlutterActivity() {
    private val channelName = "netboost/mobile_network"
    private var highPerfWifiLock: WifiManager.WifiLock? = null
    private val cellInfoTimeoutMs = 10000L

    private data class TowerPoint(
        val lat: Double,
        val lon: Double,
        val referenceRsrpDbm: Int = -85,
        val referenceDistanceMeters: Double = 100.0,
        val pathLossExponent: Double = 3.2,
    )

    private data class EstimatedPosition(
        val lat: Double,
        val lon: Double,
        val confidenceMeters: Double,
    )

    private data class TowerMeasurement(
        val cellKey: String,
        val point: TowerPoint,
        val dbm: Int,
        val estimatedDistanceMeters: Double,
        val weight: Double,
    )

    private data class CartesianPoint(val x: Double, val y: Double)

    private val towerPointDatabase: Map<String, TowerPoint> by lazy {
        loadTowerPointDatabase()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMobileNetworkGeneration" -> result.success(getMobileNetworkGeneration())
                "getCellSignals" -> getCellSignals(result)
                "getNetworkTuningStatus" -> result.success(getNetworkTuningStatus())
                "checkRootStatus" -> result.success(checkRootStatus())
                "runRootCommand" -> {
                    val commandId = call.argument<String>("commandId").orEmpty()
                    result.success(runRootCommand(commandId))
                }
                "setHighPerfWifiLock" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(setHighPerfWifiLock(enabled))
                }
                "openWifiSettings" -> {
                    openWifiSettings()
                    result.success(null)
                }
                "openDataSaverSettings" -> {
                    openDataSaverSettings()
                    result.success(null)
                }
                "openMobileNetworkSettings" -> {
                    openMobileNetworkSettings()
                    result.success(null)
                }
                "openManageApplicationsSettings" -> {
                    openManageApplicationsSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkRootStatus(): Map<String, Any?> {
        val probe = runCommand(listOf("su", "-c", "id"), timeoutMs = 3000)
        val output = (probe["output"] as? String).orEmpty()
        val exitCode = probe["exitCode"] as? Int ?: -1
        val available = exitCode == 0 && "uid=0" in output
        return mapOf(
            "available" to available,
            "checked" to true,
            "detail" to if (available) output.trim() else "未获得 su 授权或设备未 Root",
        )
    }

    private fun runRootCommand(commandId: String): Map<String, Any?> {
        val command = when (commandId) {
            "show_tcp_congestion" -> "sysctl net.ipv4.tcp_congestion_control"
            "show_tcp_buffers" -> "sysctl net.core.rmem_max net.core.wmem_max"
            "show_private_dns" -> "settings get global private_dns_mode; settings get global private_dns_specifier"
            "show_data_roaming" -> "settings get global data_roaming"
            "flush_dns" -> "ndc resolver flushdefaultif; ndc resolver flushif wlan0; ndc resolver flushif rmnet_data0"
            else -> return mapOf(
                "ok" to false,
                "output" to "未知命令，已拒绝执行",
                "exitCode" to -1,
            )
        }

        val result = runCommand(listOf("su", "-c", command), timeoutMs = 8000)
        val exitCode = result["exitCode"] as? Int ?: -1
        return mapOf(
            "ok" to (exitCode == 0),
            "output" to result["output"],
            "exitCode" to exitCode,
        )
    }

    private fun runCommand(command: List<String>, timeoutMs: Long): Map<String, Any?> {
        return runCatching {
            val process = ProcessBuilder(command)
                .redirectErrorStream(true)
                .start()
            val completed = process.waitFor(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
            if (!completed) {
                process.destroyForcibly()
                return mapOf(
                    "exitCode" to -1,
                    "output" to "命令超时",
                )
            }
            mapOf(
                "exitCode" to process.exitValue(),
                "output" to process.inputStream.bufferedReader().readText().trim(),
            )
        }.getOrElse {
            mapOf(
                "exitCode" to -1,
                "output" to (it.message ?: "命令执行失败"),
            )
        }
    }

    private fun getNetworkTuningStatus(): Map<String, Any?> {
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val frequency = runCatching { wifiManager.connectionInfo.frequency }
            .getOrDefault(0)
        val ssid = runCatching {
            wifiManager.connectionInfo.ssid?.trim('"').orEmpty()
        }.getOrDefault("")
        val bssid = runCatching { wifiManager.connectionInfo.bssid.orEmpty() }
            .getOrDefault("")
        val dataSaverStatus = runCatching {
            connectivityManager.restrictBackgroundStatus
        }.getOrDefault(ConnectivityManager.RESTRICT_BACKGROUND_STATUS_DISABLED)

        return mapOf(
            "wifiFrequencyMhz" to frequency,
            "wifiBand" to when {
                frequency >= 5925 -> "6GHz"
                frequency > 4900 -> "5GHz"
                frequency > 2400 -> "2.4GHz"
                else -> "未知"
            },
            "wifiSsid" to ssid,
            "wifiBssid" to bssid,
            "highPerfWifiLockHeld" to (highPerfWifiLock?.isHeld == true),
            "dataSaverStatus" to dataSaverStatus,
        )
    }

    private fun setHighPerfWifiLock(enabled: Boolean): Boolean {
        return runCatching {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (enabled) {
                if (highPerfWifiLock?.isHeld != true) {
                    highPerfWifiLock = wifiManager.createWifiLock(
                        WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                        "NetBoostHighPerfWifiLock"
                    ).apply {
                        setReferenceCounted(false)
                        acquire()
                    }
                }
            } else {
                highPerfWifiLock?.takeIf { it.isHeld }?.release()
                highPerfWifiLock = null
            }
            highPerfWifiLock?.isHeld == true
        }.getOrDefault(false)
    }

    private fun getCellSignals(result: MethodChannel.Result) {
        val telephonyManager =
            getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            runCatching {
                var completed = false
                val handler = Handler(Looper.getMainLooper())
                val timeout = Runnable {
                    if (!completed) {
                        completed = true
                        result.success(getCachedCellSignals(telephonyManager))
                    }
                }
                handler.postDelayed(timeout, cellInfoTimeoutMs)

                telephonyManager.requestCellInfoUpdate(
                    mainExecutorCompat(),
                    object : TelephonyManager.CellInfoCallback() {
                        override fun onCellInfo(cellInfo: MutableList<CellInfo>) {
                            if (!completed) {
                                completed = true
                                handler.removeCallbacks(timeout)
                                result.success(mapCellSignals(cellInfo, telephonyManager))
                            }
                        }

                        override fun onError(errorCode: Int, detail: Throwable?) {
                            if (!completed) {
                                completed = true
                                handler.removeCallbacks(timeout)
                                result.success(getCachedCellSignals(telephonyManager))
                            }
                        }
                    }
                )
            }.onFailure {
                result.success(getCachedCellSignals(telephonyManager))
            }
            return
        }

        result.success(getCachedCellSignals(telephonyManager))
    }

    private fun mainExecutorCompat(): Executor {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            mainExecutor
        } else {
            Executor { command -> runOnUiThread(command) }
        }
    }

    private fun getCachedCellSignals(
        telephonyManager: TelephonyManager
    ): List<Map<String, Any?>> {
        return runCatching {
            val mapped = mapCellSignals(telephonyManager.allCellInfo.orEmpty(), telephonyManager)
            mapped.ifEmpty {
                listOfNotNull(
                    getCurrentSignalFallback(
                        telephonyManager,
                        "系统未返回缓存小区列表，已尝试显示当前信号强度",
                    )
                )
            }
        }.getOrDefault(emptyList())
    }

    private fun mapCellSignals(
        cellInfo: List<CellInfo>,
        telephonyManager: TelephonyManager
    ): List<Map<String, Any?>> {
        return runCatching {
            val operatorName = telephonyManager.networkOperatorName.orEmpty()
            val mobileGeneration = getMobileNetworkGeneration()
            val rawSignals = cellInfo.map { item ->
                cellInfoToMap(item, operatorName, mobileGeneration)
            }
            val signals = applyWeightedLeastSquaresDistance(rawSignals)
            signals.ifEmpty {
                listOfNotNull(
                    getCurrentSignalFallback(
                        telephonyManager,
                        "系统本次返回空小区列表，已尝试显示当前信号强度",
                    )
                )
            }
        }.getOrDefault(emptyList())
    }

    private fun getCurrentSignalFallback(
        telephonyManager: TelephonyManager,
        refreshNote: String = "系统未开放小区列表，已显示当前信号强度",
    ): Map<String, Any?>? {
        return runCatching {
            val signalStrength = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                telephonyManager.signalStrength
            } else {
                null
            } ?: return@runCatching null

            val dbm = getBestDbm(signalStrength)
            val level = signalStrength.level
            mapOf(
                "radio" to getMobileNetworkGeneration().let {
                    if (it == "unknown") "移动网络" else it
                },
                "registered" to true,
                "level" to level,
                "dbm" to dbm,
                "asu" to null,
                "ci" to null,
                "tac" to null,
                "pci" to null,
                "arfcn" to null,
                "operatorName" to telephonyManager.networkOperatorName.orEmpty(),
                "distanceLabel" to "需至少3个有点位的小区",
                "refreshNote" to refreshNote,
                "fallback" to true,
            )
        }.getOrNull()
    }

    private fun getBestDbm(signalStrength: SignalStrength): Int? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            signalStrength.cellSignalStrengths
                .map { it.dbm }
                .filter { it != Int.MAX_VALUE }
                .maxOrNull()
                ?.let { return it }
        }
        return signalStrength.gsmSignalStrength
            .takeIf { it in 0..31 }
            ?.let { -113 + 2 * it }
    }

    private fun cellInfoToMap(
        cellInfo: CellInfo,
        operatorName: String,
        mobileGeneration: String
    ): Map<String, Any?> {
        return when (cellInfo) {
            is CellInfoNr -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "radio" to "5G NR",
                    "registered" to cellInfo.isRegistered,
                    "level" to signal.level,
                    "dbm" to signal.dbm,
                    "asu" to signal.asuLevel,
                    "ci" to getIdentityValue(identity, "getNci"),
                    "tac" to getIdentityValue(identity, "getTac"),
                    "pci" to getIdentityValue(identity, "getPci"),
                    "arfcn" to getIdentityValue(identity, "getNrarfcn"),
                    "operatorName" to operatorName,
                    "distanceLabel" to "需基站点位数据",
                    "cellKey" to buildCellKey("NR", getIdentityValue(identity, "getTac"), getIdentityValue(identity, "getNci")),
                )
            }
            is CellInfoLte -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                val radioLabel = if (mobileGeneration == "5G" && cellInfo.isRegistered) {
                    "5G NSA · LTE锚点"
                } else {
                    "4G LTE"
                }
                mapOf(
                    "radio" to radioLabel,
                    "registered" to cellInfo.isRegistered,
                    "level" to signal.level,
                    "dbm" to signal.dbm,
                    "asu" to signal.asuLevel,
                    "ci" to identity.ci.toString(),
                    "tac" to identity.tac,
                    "pci" to identity.pci,
                    "arfcn" to identity.earfcn,
                    "operatorName" to operatorName,
                    "distanceLabel" to "需基站点位数据",
                    "cellKey" to buildCellKey("LTE", identity.tac, identity.ci),
                )
            }
            is CellInfoWcdma -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "radio" to "3G WCDMA",
                    "registered" to cellInfo.isRegistered,
                    "level" to signal.level,
                    "dbm" to signal.dbm,
                    "asu" to signal.asuLevel,
                    "ci" to identity.cid.toString(),
                    "tac" to identity.lac,
                    "pci" to identity.psc,
                    "arfcn" to identity.uarfcn,
                    "operatorName" to operatorName,
                    "distanceLabel" to "需基站点位数据",
                    "cellKey" to buildCellKey("WCDMA", identity.lac, identity.cid),
                )
            }
            is CellInfoTdscdma -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "radio" to "3G TD-SCDMA",
                    "registered" to cellInfo.isRegistered,
                    "level" to signal.level,
                    "dbm" to signal.dbm,
                    "asu" to signal.asuLevel,
                    "ci" to identity.cid.toString(),
                    "tac" to identity.lac,
                    "pci" to identity.cpid,
                    "arfcn" to identity.uarfcn,
                    "operatorName" to operatorName,
                    "distanceLabel" to "需基站点位数据",
                    "cellKey" to buildCellKey("TDSCDMA", identity.lac, identity.cid),
                )
            }
            is CellInfoGsm -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "radio" to "2G GSM",
                    "registered" to cellInfo.isRegistered,
                    "level" to signal.level,
                    "dbm" to signal.dbm,
                    "asu" to signal.asuLevel,
                    "ci" to identity.cid.toString(),
                    "tac" to identity.lac,
                    "pci" to identity.bsic,
                    "arfcn" to identity.arfcn,
                    "operatorName" to operatorName,
                    "distanceLabel" to "需基站点位数据",
                    "cellKey" to buildCellKey("GSM", identity.lac, identity.cid),
                )
            }
            is CellInfoCdma -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "radio" to "2G/3G CDMA",
                    "registered" to cellInfo.isRegistered,
                    "level" to signal.level,
                    "dbm" to signal.dbm,
                    "asu" to signal.asuLevel,
                    "ci" to identity.basestationId.toString(),
                    "tac" to identity.networkId,
                    "pci" to identity.systemId,
                    "arfcn" to null,
                    "operatorName" to operatorName,
                    "distanceLabel" to "需基站点位数据",
                    "cellKey" to buildCellKey("CDMA", identity.networkId, identity.basestationId),
                )
            }
            else -> mapOf(
                "radio" to "Unknown",
                "registered" to cellInfo.isRegistered,
                "level" to 0,
                "dbm" to null,
                "asu" to null,
                "ci" to null,
                "tac" to null,
                "pci" to null,
                "arfcn" to null,
                "operatorName" to operatorName,
                "distanceLabel" to "需基站点位数据",
                "cellKey" to null,
            )
        }
    }

    private fun buildCellKey(radio: String, area: Any?, cellId: Any?): String? {
        val normalizedArea = area?.toString()?.takeUnless { it.isBlank() || it == Int.MAX_VALUE.toString() }
        val normalizedCellId = cellId?.toString()?.takeUnless { it.isBlank() || it == Int.MAX_VALUE.toString() || it == Long.MAX_VALUE.toString() }
        if (normalizedArea == null || normalizedCellId == null) return null
        return "$radio:$normalizedArea:$normalizedCellId"
    }

    private fun loadTowerPointDatabase(): Map<String, TowerPoint> {
        return runCatching {
            val json = assets.open("cell_towers.json").bufferedReader().use { it.readText() }
            val root = JSONObject(json)
            val towers = root.optJSONArray("towers") ?: JSONArray()
            buildMap {
                for (index in 0 until towers.length()) {
                    val item = towers.optJSONObject(index) ?: continue
                    val key = item.optString("key").takeIf { it.isNotBlank() }
                        ?: buildCellKey(
                            item.optString("radio"),
                            item.opt("area"),
                            item.opt("cellId"),
                        )
                        ?: continue

                    if (!item.has("lat") || !item.has("lon")) continue
                    put(
                        key,
                        TowerPoint(
                            lat = item.optDouble("lat"),
                            lon = item.optDouble("lon"),
                            referenceRsrpDbm = item.optInt("referenceRsrpDbm", -85),
                            referenceDistanceMeters = item.optDouble("referenceDistanceMeters", 100.0),
                            pathLossExponent = item.optDouble("pathLossExponent", 3.2),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyMap())
    }

    private fun applyWeightedLeastSquaresDistance(
        signals: List<Map<String, Any?>>
    ): List<Map<String, Any?>> {
        if (signals.isEmpty()) return signals

        val measurements = signals.mapNotNull { signal ->
            val cellKey = signal["cellKey"] as? String ?: return@mapNotNull null
            val tower = towerPointDatabase[cellKey] ?: return@mapNotNull null
            val dbm = signal["dbm"] as? Int ?: return@mapNotNull null
            val distance = estimateDistanceFromRsrp(dbm, tower)
            TowerMeasurement(
                cellKey = cellKey,
                point = tower,
                dbm = dbm,
                estimatedDistanceMeters = distance,
                weight = signalWeight(dbm, distance),
            )
        }

        if (measurements.size < 3) {
            return signals.map { signal ->
                signal + mapOf(
                    "distanceLabel" to "需至少3个有点位的小区",
                    "distanceMethod" to "WLS待计算",
                    "refreshNote" to "已读取小区信号；距离估计还缺基站经纬度点位",
                )
            }
        }

        val position = estimatePositionWeightedLeastSquares(measurements)
            ?: return signals.map { signal ->
                signal + mapOf(
                    "distanceLabel" to "信号不足，暂无法收敛",
                    "distanceMethod" to "WLS未收敛",
                    "refreshNote" to "已读取小区信号；本次距离估计未收敛",
                )
            }

        return signals.map { signal ->
            val cellKey = signal["cellKey"] as? String
            val tower = cellKey?.let { towerPointDatabase[it] }
            if (tower == null) {
                signal + mapOf(
                    "distanceLabel" to "无该小区点位",
                    "distanceMethod" to "WLS待计算",
                    "refreshNote" to "已读取小区信号；部分小区缺少基站经纬度点位",
                )
            } else {
                val distance = haversineMeters(position.lat, position.lon, tower.lat, tower.lon)
                signal + mapOf(
                    "distanceLabel" to "${formatMeters(distance)} · WLS",
                    "distanceMethod" to "加权最小二乘",
                    "estimatedDistanceMeters" to distance.roundToInt(),
                    "estimatedLatitude" to position.lat,
                    "estimatedLongitude" to position.lon,
                    "estimationConfidenceMeters" to position.confidenceMeters.roundToInt(),
                    "refreshNote" to "已基于RSRP和基站点位估计距离",
                )
            }
        }
    }

    private fun estimateDistanceFromRsrp(dbm: Int, tower: TowerPoint): Double {
        val exponent = tower.pathLossExponent.coerceIn(2.0, 5.0)
        val distance = tower.referenceDistanceMeters *
            10.0.pow((tower.referenceRsrpDbm - dbm) / (10.0 * exponent))
        return distance.coerceIn(20.0, 30000.0)
    }

    private fun signalWeight(dbm: Int, distanceMeters: Double): Double {
        val signalQuality = ((dbm + 130).coerceIn(0, 60) + 1).toDouble()
        return signalQuality / distanceMeters.coerceAtLeast(20.0).pow(2.0)
    }

    private fun estimatePositionWeightedLeastSquares(
        measurements: List<TowerMeasurement>
    ): EstimatedPosition? {
        val origin = measurements.first().point
        val cartesian = measurements.map {
            Triple(
                toCartesianMeters(origin, it.point),
                it.estimatedDistanceMeters,
                it.weight,
            )
        }

        var x = cartesian.sumOf { it.first.x * it.third } / cartesian.sumOf { it.third }
        var y = cartesian.sumOf { it.first.y * it.third } / cartesian.sumOf { it.third }

        repeat(12) {
            var h00 = 0.0
            var h01 = 0.0
            var h11 = 0.0
            var g0 = 0.0
            var g1 = 0.0

            cartesian.forEach { (point, measuredDistance, weight) ->
                val dx = x - point.x
                val dy = y - point.y
                val predicted = sqrt(dx * dx + dy * dy).coerceAtLeast(1.0)
                val residual = predicted - measuredDistance
                val j0 = dx / predicted
                val j1 = dy / predicted
                h00 += weight * j0 * j0
                h01 += weight * j0 * j1
                h11 += weight * j1 * j1
                g0 += weight * j0 * residual
                g1 += weight * j1 * residual
            }

            val det = h00 * h11 - h01 * h01
            if (det == 0.0 || det.isNaN()) return null
            val stepX = (h11 * g0 - h01 * g1) / det
            val stepY = (-h01 * g0 + h00 * g1) / det
            x -= stepX.coerceIn(-2000.0, 2000.0)
            y -= stepY.coerceIn(-2000.0, 2000.0)
            if (sqrt(stepX * stepX + stepY * stepY) < 1.0) return@repeat
        }

        val confidence = sqrt(
            cartesian.sumOf { (point, measuredDistance, weight) ->
                val predicted = sqrt((x - point.x).pow(2.0) + (y - point.y).pow(2.0))
                weight * (predicted - measuredDistance).pow(2.0)
            } / cartesian.sumOf { it.third }
        )
        val latLon = fromCartesianMeters(origin, CartesianPoint(x, y))
        return EstimatedPosition(latLon.first, latLon.second, confidence)
    }

    private fun toCartesianMeters(origin: TowerPoint, point: TowerPoint): CartesianPoint {
        val metersPerDegreeLat = 111_320.0
        val metersPerDegreeLon = metersPerDegreeLat * cos(origin.lat * PI / 180.0)
        return CartesianPoint(
            x = (point.lon - origin.lon) * metersPerDegreeLon,
            y = (point.lat - origin.lat) * metersPerDegreeLat,
        )
    }

    private fun fromCartesianMeters(origin: TowerPoint, point: CartesianPoint): Pair<Double, Double> {
        val metersPerDegreeLat = 111_320.0
        val metersPerDegreeLon = metersPerDegreeLat * cos(origin.lat * PI / 180.0)
        return Pair(
            origin.lat + point.y / metersPerDegreeLat,
            origin.lon + point.x / metersPerDegreeLon,
        )
    }

    private fun haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val radius = 6_371_000.0
        val dLat = (lat2 - lat1) * PI / 180.0
        val dLon = (lon2 - lon1) * PI / 180.0
        val a = kotlin.math.sin(dLat / 2).pow(2.0) +
            cos(lat1 * PI / 180.0) * cos(lat2 * PI / 180.0) *
            kotlin.math.sin(dLon / 2).pow(2.0)
        return 2 * radius * kotlin.math.atan2(sqrt(a), sqrt(1 - a))
    }

    private fun formatMeters(meters: Double): String {
        return if (meters >= 1000) {
            "${String.format("%.1f", meters / 1000.0)} km"
        } else {
            "${meters.roundToInt()} m"
        }
    }

    private fun getIdentityValue(identity: Any, methodName: String): String? {
        return runCatching {
            val value = identity.javaClass.getMethod(methodName).invoke(identity)
            value?.toString()?.takeUnless {
                it == Int.MAX_VALUE.toString() || it == Long.MAX_VALUE.toString()
            }
        }.getOrNull()
    }

    private fun getMobileNetworkGeneration(): String {
        return runCatching {
            val radioGeneration = getRadioGenerationFromSystemProperties()
            if (radioGeneration != "unknown") {
                return@runCatching radioGeneration
            }

            val telephonyManager =
                getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                isNrConnected(telephonyManager.serviceState)
            ) {
                return@runCatching "5G"
            }

            val networkType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                telephonyManager.dataNetworkType
            } else {
                @Suppress("DEPRECATION")
                telephonyManager.networkType
            }

            when (networkType) {
                TelephonyManager.NETWORK_TYPE_NR -> "5G"
                TelephonyManager.NETWORK_TYPE_LTE,
                TelephonyManager.NETWORK_TYPE_IWLAN -> "4G"
                TelephonyManager.NETWORK_TYPE_UMTS,
                TelephonyManager.NETWORK_TYPE_EVDO_0,
                TelephonyManager.NETWORK_TYPE_EVDO_A,
                TelephonyManager.NETWORK_TYPE_HSDPA,
                TelephonyManager.NETWORK_TYPE_HSUPA,
                TelephonyManager.NETWORK_TYPE_HSPA,
                TelephonyManager.NETWORK_TYPE_EVDO_B,
                TelephonyManager.NETWORK_TYPE_EHRPD,
                TelephonyManager.NETWORK_TYPE_HSPAP,
                TelephonyManager.NETWORK_TYPE_TD_SCDMA -> "3G"
                TelephonyManager.NETWORK_TYPE_GPRS,
                TelephonyManager.NETWORK_TYPE_EDGE,
                TelephonyManager.NETWORK_TYPE_CDMA,
                TelephonyManager.NETWORK_TYPE_1xRTT,
                TelephonyManager.NETWORK_TYPE_IDEN,
                TelephonyManager.NETWORK_TYPE_GSM -> "2G"
                else -> "unknown"
            }
        }.getOrDefault("unknown")
    }

    private fun getRadioGenerationFromSystemProperties(): String {
        val networkType = listOf(
            "gsm.network.type",
            "ril.data.network.type",
            "gsm.voice.network.type"
        ).mapNotNull { key ->
            runCatching {
                val systemProperties = Class.forName("android.os.SystemProperties")
                val get = systemProperties.getMethod("get", String::class.java, String::class.java)
                get.invoke(null, key, "") as? String
            }.getOrNull()
        }.joinToString(",").uppercase()

        return when {
            "NR" in networkType -> "5G"
            "LTE" in networkType || "IWLAN" in networkType -> "4G"
            "HSPA" in networkType || "UMTS" in networkType ||
                "EVDO" in networkType || "EHRPD" in networkType ||
                "TD-SCDMA" in networkType -> "3G"
            "GPRS" in networkType || "EDGE" in networkType ||
                "CDMA" in networkType || "1XRTT" in networkType ||
                "GSM" in networkType -> "2G"
            else -> "unknown"
        }
    }

    private fun isNrConnected(serviceState: ServiceState?): Boolean {
        if (serviceState == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return false
        }

        val nrState = runCatching {
            val method = ServiceState::class.java.getMethod("getNrState")
            method.invoke(serviceState) as? Int
        }.getOrNull() ?: return false

        val connected = runCatching {
            ServiceState::class.java.getField("NR_STATE_CONNECTED").getInt(null)
        }.getOrDefault(3)
        val notRestricted = runCatching {
            ServiceState::class.java.getField("NR_STATE_NOT_RESTRICTED").getInt(null)
        }.getOrDefault(2)

        return nrState == connected || nrState == notRestricted
    }

    private fun openMobileNetworkSettings() {
        val intent = Intent(Settings.ACTION_DATA_ROAMING_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { startActivity(intent) }
            .onFailure {
                startActivity(
                    Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            }
    }

    private fun openWifiSettings() {
        val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { startActivity(intent) }
            .onFailure {
                startActivity(
                    Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            }
    }

    private fun openDataSaverSettings() {
        val intent = Intent("android.settings.DATA_SAVER_SETTINGS").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { startActivity(intent) }
            .onFailure {
                startActivity(
                    Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            }
    }

    private fun openManageApplicationsSettings() {
        val intent = Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        runCatching { startActivity(intent) }
            .onFailure {
                startActivity(
                    Intent(Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            }
    }
}
