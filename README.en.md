# SignalFinder

Language: [中文](./README.md) | English

SignalFinder does not "boost network speed". It helps you understand weak-network problems, find a more stable location, and reduce unnecessary network interference.

SignalFinder is a Flutter-based weak-network diagnostics tool for Android. The package name is still `netboost`, while the app display name is `SignalFinder`. It does not amplify mobile signal and does not bypass Android system permission limits. The current implementation focuses on network status monitoring, cell signal inspection, DNS latency testing, diagnostics advice, regular network tuning shortcuts, and an app network whitelist based on a local VPN.

## Compliance And Disclaimer

This project is intended only for lawful network diagnostics, weak-network troubleshooting, Android permission and network capability learning, and local debugging on devices owned or controlled by the user. Users must comply with applicable laws, carrier terms, platform rules, and internal security policies.

- This project is not a proxy, accelerator, censorship circumvention tool, or network control bypass tool.
- This project does not provide access to restricted overseas network services and must not be modified for that purpose.
- This project does not bypass the Android permission model, silently escalate privileges, or hide system command execution.
- Users must not use this project to disrupt network order, evade lawful network management, collect data illegally, infringe privacy, or perform any unlawful activity.
- This document only describes technical boundaries and usage notes. It is not legal advice. For formal legal judgment, consult a qualified professional.

## Privacy And Data Handling

The current implementation focuses on local diagnostics. It does not include user accounts, a remote backend, or diagnostic data upload logic.

- Network checks access test domains, speed-test URLs, and DNS servers to calculate latency, packet loss, download speed, and DNS response time.
- Cell information, network status, installed app lists, and traffic statistics obtained through usage access are displayed and processed locally.
- The app network whitelist uses a local `VpnService` to drop traffic from non-whitelisted apps. It does not forward traffic to a remote server.
- App logs are used for local troubleshooting. Before sharing logs externally, remove phone numbers, locations, app lists, network identifiers, and other sensitive information.
- Saving QR code images to the gallery only happens after explicit user action.

## Prohibited Uses

Do not use this project or modified versions for the following purposes:

- Evading network regulation, bypassing carrier or organization access controls, or accessing illegal content.
- Distributing, trading, or bulk-collecting unauthorized base station coordinates, geolocation data, device identifiers, app usage records, or other sensitive data.
- Adding hidden uploads, remote control, silent privilege escalation, arbitrary root command execution, proxy forwarding, traffic relay, or VPN prompt bypass behavior.
- Publishing a modified version as if it were the official project, or misleading users into granting permissions unrelated to the app's functionality.

## Features

- Real-time monitoring: automatically or manually detects network type, latency, packet loss, download speed, and keeps the latest 50 history records.
- Signal finder: reads Android `CellInfo` / `SignalStrength`, and displays dBm, ASU, Level, PCI, TAC/LAC, CI/NCI, frequency numbers, and other details for serving and neighboring cells.
- Distance estimation: uses local `cell_towers.json` points and signal strength for path-loss estimation; when at least 3 known points match, it attempts weighted least squares estimation.
- DNS selection: tests Alibaba, Tencent, 114, Baidu, Cloudflare, Google, and carrier-default DNS latency for resolving `baidu.com`.
- Network diagnostics: combines latency, packet loss, download speed, network type, and app traffic statistics to produce a 0-100 score and advice.
- Network tuning: displays Wi-Fi band, data saver status, Wi-Fi high-performance lock status, and opens system settings for Wi-Fi, mobile network, data saver, VPN, and more.
- App network whitelist: temporarily allows selected apps through Android `VpnService`; other app traffic enters the local VPN and is dropped, reducing background usage in weak networks.
- Advanced mode: checks `su` status; when root is available, provides a small fixed set of allowlisted commands for copying and user-confirmed execution.
- Logs and QR codes: displays runtime logs in the app, and includes personal WeChat, public account, and video channel QR code images that can be saved to the gallery.

## Important Boundaries

SignalFinder follows the boundaries of a normal Android app:

- It cannot amplify mobile signal or force the phone to connect to a specific base station.
- It cannot root the device for the user and does not silently elevate privileges.
- It cannot silently modify APN, preferred network type, airplane mode, randomized MAC, global IPv6, private DNS, or kernel TCP parameters.
- The app network whitelist is not an accelerator or proxy service. It only uses a local VPN to intercept traffic from non-whitelisted apps.
- Base station distance is not a precise distance returned by the system. It is estimated from signal strength, reference signal, reference distance, path-loss exponent, and local tower point data. Obstructions, reflections, transmit power, and point quality can cause significant error.

## Main Screens

### Real-Time Monitoring

The home screen refreshes network status every 30 seconds by default. Users can pause or refresh manually. Quick checks include current connection type, latency, and packet loss. Full diagnostics additionally run a download speed test.

Measurement details:

- Latency / packet loss: sampled through multiple TCP connections to `baidu.com:80`.
- Download speed: first requests the Cloudflare speed test URL, then falls back to `https://www.baidu.com` if needed.
- Results are used for in-app judgment and advice. They are not equivalent to professional speed-test platforms.

### Signal Finder

The "Signal Finder" screen is designed for comparing signal quality across locations such as subways, malls, underground spaces, and vehicles.

Common fields:

- `dBm`: signal power, usually negative. Values closer to 0 are stronger.
- `ASU`: Android signal unit, usually higher is better.
- `Level`: Android normalized level, usually in the 0-4 range.
- `PCI`: physical cell identity.
- `TAC/LAC`: tracking area code or location area code.
- `CI/NCI`: 4G/5G cell identity.
- `EARFCN/NRARFCN/UARFCN/ARFCN`: radio frequency channel numbers.

On Android 10+, phone permission, location permission, and the system location switch are usually required together. Some vendor ROMs restrict neighboring cell data and may only expose the current signal summary. In 5G NSA scenarios, the system may expose only the LTE anchor.

### DNS Selection

The DNS screen sends UDP A-record queries to built-in public DNS servers and sorts them by reachable latency. The screen only tests and recommends. Changing global DNS still requires manual configuration in the system or router settings.

Built-in list:

- Alibaba DNS: `223.5.5.5`
- Tencent DNS: `119.29.29.29`
- 114 DNS: `114.114.114.114`
- Baidu DNS: `180.76.76.76`
- Cloudflare: `1.1.1.1`
- Google DNS: `8.8.8.8`
- Carrier default: current system DNS

### Network Diagnostics

The diagnostics screen runs a full network check and generates a score and advice based on:

- Whether the device is connected.
- Whether latency exceeds 150ms / 300ms.
- Whether packet loss exceeds 10% / 30%.
- Whether download speed is below 1Mbps.
- Whether high latency and packet loss on mobile network suggest crowd congestion.
- If usage access is granted, recently high-traffic apps are shown as troubleshooting references.

### Network Tuning And Whitelist VPN

Regular tuning capabilities include:

- Viewing current Wi-Fi SSID, band, and frequency.
- Opening system settings for Wi-Fi, mobile network, data saver, VPN, and app management.
- Enabling or disabling Wi-Fi high-performance lock.
- Checking system data saver status.
- Showing prompts for DNS, IPv6, randomized MAC, APN, and 5G/4G preference items that require user action or system-level permission.

The app network whitelist is based on Android `VpnService`. Before enabling it, users must select apps to allow and approve the system VPN dialog. While the service is running:

- Selected apps bypass the local VPN through `addDisallowedApplication` and keep network access.
- Other app traffic enters the local VPN interface, is read, and is dropped.
- Android usually allows only one VPN at a time, so this occupies the current VPN capability.
- Disable the whitelist in the app or system VPN settings after use.

### Advanced Mode

Advanced mode executes commands only when the device is already rooted and the user grants authorization through an `su` manager. The current command set is fixed and does not support arbitrary command input:

- View TCP congestion control.
- View TCP buffer limits.
- View private DNS configuration.
- Flush system DNS cache.

Each command shows a confirmation dialog before execution. The screen also provides command copying for manual inspection.

## Base Station Point Database

Base station point data is located at:

```text
android/app/src/main/assets/cell_towers.json
```

The file in this repository contains only example points, and the examples are explicitly marked as `Example only`. For practical distance estimation, replace it only with legally sourced data or self-collected calibrated point data.

Do not submit unauthorized real, precise base station coordinates to a public repository or distribute them inside an APK. If users or downstream developers replace `cell_towers.json`, they must verify the data source, authorization scope, applicable regional laws, and privacy compliance requirements, and assume the corresponding responsibility.

Data structure:

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

`key` format:

```text
Radio:AreaCode:CellId
```

Keys generated by the native layer:

- 4G: `LTE:TAC:CI`
- 5G: `NR:TAC:NCI`
- 3G WCDMA: `WCDMA:LAC:CID`
- 3G TD-SCDMA: `TDSCDMA:LAC:CID`
- 2G GSM: `GSM:LAC:CID`
- CDMA: `CDMA:NetworkId:BaseStationId`

`referenceRsrpDbm`, `referenceDistanceMeters`, and `pathLossExponent` are used to approximately convert RSRP into a distance constraint. Default values can be used without field calibration, but the result should only be treated as directional reference.

## Permissions

Main Android permissions:

- `INTERNET`: network checks, DNS testing, download speed testing.
- `ACCESS_NETWORK_STATE`: reads network connection status.
- `ACCESS_WIFI_STATE` / `CHANGE_NETWORK_STATE`: reads Wi-Fi status and works with Wi-Fi high-performance lock.
- `READ_PHONE_STATE`: reads mobile network generation and cell information.
- `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION`: cell information usually requires location permission and the system location switch.
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` / `POST_NOTIFICATIONS`: whitelist VPN foreground service and notification.
- `PACKAGE_USAGE_STATS`: reads app traffic statistics, and must be manually granted in system settings.
- `WRITE_EXTERNAL_STORAGE`: saves QR codes to gallery on Android 9 and below.

## Development Environment

- Flutter SDK: 3.x
- Dart SDK: `>=3.0.0 <4.0.0`
- Java: 17
- Android Gradle / Kotlin Gradle: uses project configuration

Install dependencies:

```bash
flutter pub get
```

Static analysis:

```bash
flutter analyze
```

Current analysis result:

```text
No issues found!
```

The repository currently has no `test/` directory and no automated tests configured.

## Run And Build

Run on a connected Android device:

```bash
flutter run
```

Build release APK:

```bash
flutter build apk --release
```

The project renames the release artifact to:

```text
build/app/outputs/apk/release/SignalFinder-v1.0.0-release.apk
```

Flutter also generates the standard copied artifact:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install on a connected device:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Note: the current release build in `android/app/build.gradle.kts` still uses the debug signing config, which is suitable for local installation and verification. Before formal release, replace it with a proper release signature and change the default `applicationId = "com.example.netboost"`.

Release suggestions:

- Use a dedicated release keystore before formally publishing APKs. Do not keep using debug signing.
- State official release channels, version numbers, and signing information in GitHub Releases, the app's about page, or release notes.
- Build artifacts in the source repository do not automatically represent official releases. Users should download only from channels declared by the developer.
- Do not commit signing certificates, keystore passwords, API keys, or other private configuration to the repository.

## Project Structure

```text
lib/
  main.dart                       App entry, global error logs, Provider injection
  models/                         Data models
  providers/network_provider.dart Page state and business flow orchestration
  screens/                        Monitoring, signal finder, DNS, diagnostics, tuning, logs
  services/                       Network checks, DNS, diagnostics, log services
android/
  app/src/main/kotlin/            Android native MethodChannel and VpnService
  app/src/main/assets/            Local base station point JSON
assets/qr/                        QR code image assets
```

## Known Limitations

- Cell information access is heavily affected by Android version, vendor ROM, SIM status, location switch, and permissions.
- In 5G NSA scenarios, the system may expose only the LTE anchor and cannot guarantee complete NR cell information.
- DNS latency represents only the current network's one-time performance to the test domain and DNS server. It does not represent long-term quality.
- The app network whitelist occupies the system VPN and cannot normally be used together with another VPN.
- Usage access permission must be manually enabled by the user. The app cannot grant it by itself.
- Root advanced mode only provides fixed allowlisted commands and does not support arbitrary command input.

## Contribution And Security Boundaries

Issues and pull requests around diagnostics accuracy, permission prompts, compatibility, UI experience, and documentation are welcome. Changes involving the following are not recommended for merge:

- Proxying, forwarding, relaying, bypassing network limits, or hiding VPN behavior.
- Arbitrary command execution, silent root, hidden permission requests, or background persistence.
- Uploading cell information, app lists, traffic statistics, locations, device identifiers, or other sensitive data.
- Embedding unauthorized real base station point databases or other unclear-source datasets.

When submitting issues or logs, do not include phone numbers, precise locations, real base station coordinates, account tokens, certificates, keys, or other personal sensitive information.

## License

This project is licensed under the Apache License 2.0. You may use, modify, and distribute this project in compliance with the license terms.

See [LICENSE](./LICENSE).
