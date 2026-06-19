# SignalFinder

不是“提高网速”，而是帮助你在弱网环境下看清问题、找到更稳的位置，并减少不必要的联网干扰。

SignalFinder 是一个面向 Android 的 Flutter 弱网诊断工具。项目包名仍为 `netboost`，应用展示名为 `SignalFinder`。它不会增强手机信号，也不会绕过 Android 系统权限限制；当前实现重点是网络状态监测、小区信号查看、DNS 延迟测试、诊断建议、普通网络调优入口，以及一个基于本地 VPN 的 App 联网白名单。

## 当前功能

- 实时监测：自动或手动检测网络类型、延迟、丢包率、下载速度，并保留最近 50 条历史记录。
- 找信号：读取 Android `CellInfo` / `SignalStrength`，展示服务小区和邻近小区的 dBm、ASU、Level、PCI、TAC/LAC、CI/NCI、频点等信息。
- 距离估计：基于本地 `cell_towers.json` 点位和信号强度做路径损耗估算；当匹配到至少 3 个已知点位时，尝试使用加权最小二乘估算。
- DNS 优选：测试阿里、腾讯、114、百度、Cloudflare、Google 以及运营商默认 DNS 对 `baidu.com` 的解析延迟。
- 网络诊断：结合延迟、丢包、下载速度、网络类型和应用流量统计，生成 0-100 分评分与建议。
- 网络调优：展示 Wi-Fi 频段、省流量状态、Wi-Fi 高性能锁状态，并跳转到系统 Wi-Fi、移动网络、省流量、VPN 等设置页。
- App 联网白名单：通过 Android `VpnService` 临时放行已选择 App，其它 App 流量进入本地 VPN 后被丢弃，用于弱网下减少后台占用。
- 高级模式：检测 `su` 状态；Root 可用时提供少量白名单命令的复制和用户确认执行。
- 日志与二维码：应用内展示运行日志，并内置个人微信、公众号、视频号二维码图片，可保存到相册。

## 重要边界

SignalFinder 遵循普通 Android 应用能力边界：

- 不能增强手机信号，不能强制手机连接某个基站。
- 不能替用户开启 Root，也不会静默提权。
- 不能静默修改 APN、首选网络类型、飞行模式、随机 MAC、全局 IPv6、私有 DNS 或内核 TCP 参数。
- App 联网白名单不是加速器，也不是代理服务；它只是使用本地 VPN 拦截未放行应用的流量。
- 基站距离不是系统直接给出的精确距离，而是根据信号强度、参考信号、参考距离、路径损耗指数和本地点位数据估算，误差会受遮挡、反射、发射功率和点位质量影响。

## 主要页面

### 实时监测

首页每 30 秒自动刷新一次网络状态，也可以手动暂停或刷新。快速检测包含当前连接类型、延迟和丢包；完整诊断会额外执行下载测速。

测速实现说明：

- 延迟/丢包：通过 TCP 连接 `baidu.com:80` 做多次采样。
- 下载速度：优先请求 Cloudflare speed test 地址，失败后降级请求 `https://www.baidu.com`。
- 结果用于应用内判断和建议，不等同于专业测速平台结果。

### 找信号

“找信号”页面适合在地铁、商场、地下空间、车厢等弱网场景中比较不同位置的信号质量。

常见字段：

- `dBm`：信号功率，通常为负数，越接近 0 越强。
- `ASU`：Android 信号单位，通常越大越好。
- `Level`：Android 归一化等级，范围通常为 0-4。
- `PCI`：物理小区标识。
- `TAC/LAC`：跟踪区或位置区编号。
- `CI/NCI`：4G/5G 小区身份标识。
- `EARFCN/NRARFCN/UARFCN/ARFCN`：无线频点编号。

Android 10+ 通常需要同时允许电话权限、位置权限，并打开系统定位开关。部分厂商系统会限制邻近小区数据，可能只能显示当前信号概览；5G NSA 场景下也可能只暴露 LTE 锚点。

### DNS 优选

DNS 页面会依次向内置公共 DNS 发起 UDP A 记录查询，并按可达延迟排序。页面只负责测试和建议，更换全局 DNS 仍需用户在系统或路由器设置中手动完成。

内置列表：

- 阿里 DNS：`223.5.5.5`
- 腾讯 DNS：`119.29.29.29`
- 114 DNS：`114.114.114.114`
- 百度 DNS：`180.76.76.76`
- Cloudflare：`1.1.1.1`
- Google DNS：`8.8.8.8`
- 运营商默认：系统当前 DNS

### 网络诊断

诊断页面会执行完整网络检测，并根据以下因素生成评分和建议：

- 是否联网。
- 延迟是否超过 150ms / 300ms。
- 丢包率是否超过 10% / 30%。
- 下载速度是否低于 1Mbps。
- 移动网络下是否存在高延迟和丢包叠加的人群拥塞特征。
- 如果用户授予“使用情况访问权限”，会展示近期流量较高的应用作为排查参考。

### 网络调优与白名单 VPN

普通调优能力包括：

- 查看当前 Wi-Fi SSID、频段和频率。
- 打开 Wi-Fi、移动网络、省流量、VPN、应用管理等系统设置。
- 开启或关闭 Wi-Fi 高性能锁。
- 检测系统省流量状态。
- 提示 DNS、IPv6、随机 MAC、APN、5G/4G 偏好等需要用户或系统权限处理的项目。

App 联网白名单基于 Android `VpnService` 实现。开启前用户需要选择要放行的应用，并授权系统 VPN 弹窗。服务运行时：

- 已选择应用通过 `addDisallowedApplication` 绕过本地 VPN，保持联网。
- 其它应用流量进入本地 VPN 接口后被读取并丢弃。
- 系统同一时间通常只能启用一个 VPN，因此会占用当前 VPN 能力。
- 用完后应在应用内或系统 VPN 设置中关闭白名单。

### 高级模式

高级模式只在设备已经 Root 且用户通过 su 管理器授权后执行命令。当前命令集合固定，不支持任意命令输入：

- 查看 TCP 拥塞控制。
- 查看 TCP 缓冲区上限。
- 查看私有 DNS 配置。
- 刷新系统 DNS 缓存。

每个命令执行前都会弹出确认框，页面也提供命令复制，便于用户自行检查。

## 基站点位库

基站点位数据位于：

```text
android/app/src/main/assets/cell_towers.json
```

当前仓库中的文件只有示例点位，示例里也明确标注为 `Example only`。如果需要实际距离估计，应替换为合法来源或自行采集校准后的点位数据。

数据结构：

```json
{
  "version": 1,
  "towers": [
    {
      "key": "LTE:12345:67890123",
      "radio": "LTE",
      "area": 12345,
      "cellId": 67890123,
      "lat": 31.230416,
      "lon": 121.473701,
      "referenceRsrpDbm": -85,
      "referenceDistanceMeters": 100,
      "pathLossExponent": 3.2,
      "note": "Example only. Replace with collected or licensed tower coordinates."
    }
  ]
}
```

`key` 格式为：

```text
制式:区域码:小区ID
```

原生层生成的 key：

- 4G：`LTE:TAC:CI`
- 5G：`NR:TAC:NCI`
- 3G WCDMA：`WCDMA:LAC:CID`
- 3G TD-SCDMA：`TDSCDMA:LAC:CID`
- 2G GSM：`GSM:LAC:CID`
- CDMA：`CDMA:NetworkId:BaseStationId`

`referenceRsrpDbm`、`referenceDistanceMeters`、`pathLossExponent` 用于把 RSRP 近似换算成距离约束。没有实测校准时可以先使用默认值，但结果只能作为方向性参考。

## 权限说明

Android 侧主要权限：

- `INTERNET`：网络检测、DNS 测试、下载测速。
- `ACCESS_NETWORK_STATE`：读取网络连接状态。
- `ACCESS_WIFI_STATE` / `CHANGE_NETWORK_STATE`：读取 Wi-Fi 状态，配合 Wi-Fi 高性能锁。
- `READ_PHONE_STATE`：读取移动网络制式和小区信息。
- `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION`：读取小区信息通常需要位置权限和系统定位开关。
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` / `POST_NOTIFICATIONS`：白名单 VPN 前台服务和通知。
- `PACKAGE_USAGE_STATS`：读取应用流量统计，需要用户在系统设置中手动授权。
- `WRITE_EXTERNAL_STORAGE`：Android 9 及以下保存二维码到相册。

## 开发环境

- Flutter SDK：3.x
- Dart SDK：`>=3.0.0 <4.0.0`
- Java：17
- Android Gradle / Kotlin Gradle：使用项目内配置

安装依赖：

```bash
flutter pub get
```

静态检查：

```bash
flutter analyze
```

当前检查结果：

```text
No issues found!
```

仓库当前没有 `test/` 目录，暂未配置自动化测试。

## 运行与构建

连接 Android 设备后运行：

```bash
flutter run
```

构建 release APK：

```bash
flutter build apk --release
```

项目会把 release 产物命名为：

```text
build/app/outputs/apk/release/SignalFinder-v1.0.0-release.apk
```

Flutter 同时会生成标准复制产物：

```text
build/app/outputs/flutter-apk/app-release.apk
```

安装到已连接设备：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

注意：当前 `android/app/build.gradle.kts` 的 release 构建仍使用 debug signing config，适合本地安装验证；正式发布前应替换为正式签名，并修改默认 `applicationId = "com.example.netboost"`。

## 目录结构

```text
lib/
  main.dart                       应用入口、全局异常日志、Provider 注入
  models/                         数据模型
  providers/network_provider.dart  页面状态和业务流程编排
  screens/                        实时监测、找信号、DNS、诊断、调优、日志页面
  services/                       网络检测、DNS、诊断、日志服务
android/
  app/src/main/kotlin/            Android 原生 MethodChannel 与 VpnService
  app/src/main/assets/            本地基站点位 JSON
assets/qr/                        二维码图片资源
```

## 已知限制

- 小区信息读取受 Android 版本、厂商 ROM、SIM 状态、定位开关和权限影响较大。
- 5G NSA 下系统可能只暴露 LTE 锚点，不能保证拿到完整 NR 小区信息。
- DNS 延迟只代表当前网络到测试域名和 DNS 服务器的单次环境表现，不代表长期质量。
- App 联网白名单会占用系统 VPN，不能与其它 VPN 同时正常使用。
- 使用情况访问权限需要用户手动开启，应用不能自行授予。
- Root 高级模式只提供固定白名单命令，不支持任意命令输入。
