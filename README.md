# SignalFinder

不是“提高网速”，而是“在弱网下让你用得不卡”。

SignalFinder 是一个面向 Android 的 Flutter 弱网诊断与信号辅助工具。它不“增强信号”，而是帮助用户看清当前网络状态、定位相对更好的信号位置，并给出可执行的网络调优建议。

## 功能概览

- 实时监测：检测当前网络类型、延迟、丢包率、下载测速，并支持自动监测启停。
- 找信号：读取 Android `CellInfo` / `SignalStrength`，展示当前服务小区、邻近小区、dBm、ASU、Level、PCI、TAC/LAC、CI/NCI、频点等信息。
- 基站距离估计：直连手机时基于 dBm/RSRP 使用路径损耗算法估算距离；有多个本地基站点位时自动使用加权最小二乘算法提高稳定性。
- DNS 优选：测试常见公共 DNS 的解析延迟，辅助用户选择更快 DNS。
- 网络诊断：根据延迟、丢包、下载速度和网络类型生成评分与优化建议。
- 网络调优：提供 Wi-Fi 频段、省流量模式、Wi-Fi 高性能锁、移动网络设置等检测与引导。
- 高级模式：检测 Root/su 状态；Root 可用时支持白名单命令的复制与用户授权执行。

## 重要边界

SignalFinder 遵循普通 Android 应用权限边界：

- 不能增强手机信号。
- 不能替用户开启 Root。
- 不能静默修改 APN、首选网络类型、飞行模式、随机 MAC、全局 IPv6 或内核 TCP 参数。
- 不能强制手机连接某个基站。
- 基站距离无法仅靠手机本地 API 直接精确读取。本应用会根据 dBm/RSRP、参考信号强度和传播损耗指数，通过路径损耗算法估算距离；如果同时有至少 3 个已知经纬度的基站点位，会进一步使用加权最小二乘算法估算位置并反推距离。

## 找信号说明

“找信号”页面用于在车厢、商场、地下空间等弱网场景中比较不同位置的信号质量。

关键字段：

- dBm：信号功率，通常是负数，越接近 0 越强。
- ASU：Android 信号单位，通常越大越好。
- Level：Android 归一化等级，范围 0-4。
- PCI：物理小区标识。
- TAC/LAC：跟踪区或位置区编号。
- CI/NCI：4G/5G 小区身份标识。
- 频点：EARFCN/NRARFCN 等无线频率编号。

如果系统不开放完整 `CellInfo`，页面会回退显示当前 `SignalStrength` 概览。Android 10+ 通常需要同时允许“电话”和“位置”权限，并打开系统位置信息开关。

### 基站点位库

基站距离估计使用纯本地数据，不依赖外部服务。点位文件位于：

```text
android/app/src/main/assets/cell_towers.json
```

每条记录至少需要 `key`、`lat`、`lon`。`key` 格式为：

```text
制式:区域码:小区ID
```

当前原生层生成的 key：

- 4G：`LTE:TAC:CI`
- 5G：`NR:TAC:NCI`
- 3G WCDMA：`WCDMA:LAC:CID`
- 3G TD-SCDMA：`TDSCDMA:LAC:CID`
- 2G GSM：`GSM:LAC:CID`
- CDMA：`CDMA:NetworkId:BaseStationId`

示例：

```json
{
  "key": "LTE:12345:67890123",
  "lat": 31.230416,
  "lon": 121.473701,
  "referenceRsrpDbm": -85,
  "referenceDistanceMeters": 100,
  "pathLossExponent": 3.2
}
```

`referenceRsrpDbm`、`referenceDistanceMeters`、`pathLossExponent` 用于把 RSRP 近似换算成测距约束。没有实测校准时可以先使用默认值。找信号页面会先通过路径损耗算法估算距离；当读到 3 个以上已配置点位的小区时，会输出“加权最小二乘”距离。

## 网络调优

普通模式支持：

- 查看当前 Wi-Fi 频段。
- 打开 Wi-Fi、移动网络、省流量设置。
- 开启/关闭 Wi-Fi 高性能锁。
- 检测省流量模式。
- 给出 DNS、IPv6、APN、5G/4G 偏好等操作建议。

高级模式支持：

- 检测 `su` 是否可用。
- Root 可用时执行白名单命令，例如查看 TCP 拥塞控制、查看 TCP 缓冲区、查看私有 DNS、刷新 DNS 缓存。
- 每个 Root 命令都需要用户确认，并由系统 su 管理器授权。

## 权限

Android 侧使用的主要权限：

- `INTERNET`
- `ACCESS_NETWORK_STATE`
- `ACCESS_WIFI_STATE`
- `CHANGE_NETWORK_STATE`
- `READ_PHONE_STATE`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_FINE_LOCATION`

其中“找信号”读取小区信息通常需要电话权限、位置权限和系统定位开关。

## 开发环境

- Flutter SDK：3.x
- Dart SDK：3.x
- Android Gradle Plugin / Gradle：使用项目内 Android 配置
- Java：17

安装依赖：

```bash
flutter pub get
```

静态检查：

```bash
flutter analyze
```

当前项目仍有一个模板遗留测试错误：`test/widget_test.dart` 引用旧的 `MyApp` 类。该错误不影响 release APK 构建。

## 构建

构建 release APK：

```bash
flutter build apk --release
```

正式命名产物：

```text
build/app/outputs/apk/release/SignalFinder-v1.0.0-release.apk
```

Flutter 同时会生成标准复制产物：

```text
build/app/outputs/flutter-apk/app-release.apk
```

安装到已连接 Android 设备：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 目录结构

```text
lib/
  models/                 数据模型
  providers/              状态管理
  screens/                页面
  services/               网络、DNS、诊断、平台通道服务
android/
  app/src/main/kotlin/    Android 原生能力与 MethodChannel
```

## 当前限制

- 部分厂商系统会限制邻近小区数据，可能只能读取当前信号概览。
- 5G NSA 场景下，系统可能只暴露 LTE 锚点；页面会显示为 `5G NSA · LTE锚点`。
- 基站距离估计依赖信号强度质量和 `cell_towers.json` 中的点位质量；坐标误差、遮挡、反射和基站发射功率都会影响算法结果。
- Root 高级调优只提供白名单命令，不支持任意命令输入。
