import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import 'advanced_mode_screen.dart';

class NetworkTuningScreen extends StatefulWidget {
  const NetworkTuningScreen({super.key});

  @override
  State<NetworkTuningScreen> createState() => _NetworkTuningScreenState();
}

class _NetworkTuningScreenState extends State<NetworkTuningScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkProvider>().refreshNetworkTuningStatus();
      context.read<NetworkProvider>().refreshAppWhitelistVpn();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final status = provider.tuningStatus;
        final isLoading = provider.tuningState == MeasurementState.measuring;

        return Scaffold(
          appBar: AppBar(
            title: const Text('网络调优'),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdvancedModeScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: '高级模式',
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: provider.refreshNetworkTuningStatus,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(
                icon: Icons.wifi,
                title: 'Wi-Fi 调优',
                subtitle: status.wifiFrequencyMhz > 0
                    ? '${status.wifiBand} · ${status.wifiFrequencyMhz} MHz'
                    : '未读取到当前 Wi-Fi 频段',
              ),
              _TuningCard(
                title: '优先使用 5GHz/6GHz',
                capability:
                    status.wifiBand == '5GHz' || status.wifiBand == '6GHz'
                        ? '当前已在高频段'
                        : '建议切换',
                detail:
                    '2.4GHz 更容易被蓝牙、微波炉和邻居路由干扰。当前 SSID：${status.wifiSsid.isEmpty ? '--' : status.wifiSsid}。',
                actionLabel: '打开 Wi-Fi',
                onAction: provider.openWifiSettings,
              ),
              _TuningCard(
                title: 'Wi-Fi 高性能锁',
                capability: status.highPerfWifiLockHeld ? '已开启' : '可直接开启',
                detail:
                    '关键传输时保持 Wi-Fi 高吞吐模式，减少系统休眠或省电影响。会增加耗电，建议只在测速、下载、视频会议时开启。',
                trailing: Switch(
                  value: status.highPerfWifiLockHeld,
                  onChanged: provider.setHighPerfWifiLock,
                ),
              ),
              _TuningCard(
                title: '随机 MAC',
                capability: '需手动设置',
                detail:
                    '部分路由器会对随机 MAC 设备限速或重置策略。可在 Wi-Fi 详情里把隐私/MAC 地址类型改为“设备 MAC”。普通 App 不能直接修改该项。',
                actionLabel: '打开 Wi-Fi',
                onAction: provider.openWifiSettings,
              ),
              const _TuningCard(
                title: 'IPv6 兼容性',
                capability: '需路由器/系统配置',
                detail:
                    '部分网络 IPv6 路由质量差会造成首包慢或连接卡顿。普通 App 不能全局禁用 IPv6，可在路由器侧关闭 IPv6，或在问题网络中优先使用 IPv4 服务。',
              ),
              const SizedBox(height: 18),
              const _SectionHeader(
                icon: Icons.signal_cellular_alt,
                title: '移动网络调优',
                subtitle: '普通应用以检测和引导为主',
              ),
              _TuningCard(
                title: '省流量模式',
                capability: status.dataSaverLabel,
                detail: status.isDataSaverEnabled
                    ? '系统省流量模式已开启，后台联网会受限，部分前台体验也可能受影响。'
                    : '当前未检测到系统省流量模式限制。',
                actionLabel: '打开省流量设置',
                onAction: provider.openDataSaverSettings,
              ),
              const _AppWhitelistVpnCard(),
              _TuningCard(
                title: '5G SA / 首选网络类型',
                capability: '需系统/厂商权限',
                detail:
                    '强制 SA 或修改首选网络类型属于系统级能力，普通 App 不能直接调用。可进入移动网络设置，选择 5G/4G 偏好；不同厂商菜单名称不同。',
                actionLabel: '打开移动网络',
                onAction: provider.openMobileNetworkSettings,
              ),
              _TuningCard(
                title: 'APN 重置/优选',
                capability: '需用户确认',
                detail:
                    'APN 配置错误会导致限速、无法 IPv4/IPv6 双栈。普通 App 不能静默修改 APN，建议在系统 APN 页面恢复默认或选择运营商默认 APN。',
                actionLabel: '打开移动网络',
                onAction: provider.openMobileNetworkSettings,
              ),
              const _TuningCard(
                title: '信号重连',
                capability: '需系统权限',
                detail:
                    '飞行模式切换、RIL 原始命令、强制重选小区都属于系统或工程权限。普通 App 可做的是提示你移动位置、切换 4G/5G 偏好或手动开关飞行模式。',
              ),
              const SizedBox(height: 18),
              const _SectionHeader(
                icon: Icons.rocket_launch,
                title: '系统级调优',
                subtitle: '高风险能力仅说明，不在普通版本中执行',
              ),
              const _TuningCard(
                title: 'DNS 优化',
                capability: 'App 内可测速',
                detail:
                    '优先使用本应用 DNS 优选页测试解析延迟。全局私有 DNS 需要用户在系统设置中配置；写系统 resolver 文件需要 Root。',
              ),
              const _TuningCard(
                title: 'TCP 拥塞控制 / 缓冲区',
                capability: '需 Root',
                detail:
                    'BBR、rmem/wmem、队列策略等属于内核参数，普通 App 不应直接修改。Root 环境可调，但需要按设备和网络验证，错误配置会降低稳定性。',
              ),
              const _TuningCard(
                title: '网络优先级策略',
                capability: '系统受限',
                detail:
                    'Android 已移除或限制多数全局网络偏好 API。普通 App 可以监测 Wi-Fi 弱网并提醒切换移动网络，但不能强行替用户切流量。',
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _AppWhitelistVpnCard extends StatelessWidget {
  const _AppWhitelistVpnCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final status = provider.appWhitelistVpnStatus;
        final isLoading =
            provider.appWhitelistState == MeasurementState.measuring;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'App 联网白名单',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _CapabilityBadge(label: status.running ? '已开启' : '未开启'),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '开启后仅放行勾选的 App，其它 App 会被本地 VPN 拦截。该模式不需要 Root，但会占用系统 VPN。',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const _AppWhitelistVpnScreen(),
                                ),
                              );
                            },
                      child: const Text('配置白名单'),
                    ),
                    FilledButton.tonal(
                      onPressed: isLoading || !status.running
                          ? null
                          : provider.stopAppWhitelistVpn,
                      child: const Text('关闭白名单'),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : provider.openVpnSettings,
                      child: const Text('系统 VPN 设置'),
                    ),
                  ],
                ),
                if (status.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    status.message,
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppWhitelistVpnScreen extends StatefulWidget {
  const _AppWhitelistVpnScreen();

  @override
  State<_AppWhitelistVpnScreen> createState() => _AppWhitelistVpnScreenState();
}

class _AppWhitelistVpnScreenState extends State<_AppWhitelistVpnScreen> {
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkProvider>().refreshAppWhitelistVpn();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final status = provider.appWhitelistVpnStatus;
        final selected = provider.selectedWhitelistPackages;
        final isLoading =
            provider.appWhitelistState == MeasurementState.measuring;
        final normalizedQuery = _query.trim().toLowerCase();
        final apps = normalizedQuery.isEmpty
            ? provider.installedApps
            : provider.installedApps
                .where((app) =>
                    app.label.toLowerCase().contains(normalizedQuery) ||
                    app.packageName.toLowerCase().contains(normalizedQuery))
                .toList();
        final selectedApps = provider.installedApps
            .where((app) => selected.contains(app.packageName))
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('App 联网白名单'),
            actions: [
              IconButton(
                onPressed: isLoading ? null : provider.refreshAppWhitelistVpn,
                icon: const Icon(Icons.refresh),
                tooltip: '刷新列表',
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  enabled: !status.running,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty || status.running
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                            tooltip: '清空搜索',
                          ),
                    hintText: '搜索 App 或包名',
                    isDense: true,
                  ),
                ),
              ),
              if (!status.running)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '已选 ${selected.length} 个',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: apps.isEmpty
                            ? null
                            : () => provider.selectWhitelistPackages(
                                  apps.map((app) => app.packageName),
                                ),
                        child: const Text('全选当前'),
                      ),
                      TextButton(
                        onPressed: apps.isEmpty
                            ? null
                            : () => provider.unselectWhitelistPackages(
                                  apps.map((app) => app.packageName),
                                ),
                        child: const Text('取消当前'),
                      ),
                      TextButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => provider.unselectWhitelistPackages(
                                  selected,
                                ),
                        child: const Text('取消已选'),
                      ),
                    ],
                  ),
                ),
              if (!status.running && selectedApps.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedApps.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final app = selectedApps[index];
                      return InputChip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.label.isEmpty ? app.packageName : app.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                app.packageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        onDeleted: () =>
                            provider.toggleWhitelistPackage(app.packageName),
                      );
                    },
                  ),
                ),
              if (status.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      status.message,
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: isLoading && provider.installedApps.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : apps.isEmpty
                        ? const Center(
                            child: Text(
                              '未读取到可启动 App',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.separated(
                            itemCount: apps.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final app = apps[index];
                              return CheckboxListTile(
                                value: selected.contains(app.packageName),
                                onChanged: status.running
                                    ? null
                                    : (_) => provider.toggleWhitelistPackage(
                                          app.packageName,
                                        ),
                                title: Text(
                                  app.label.isEmpty
                                      ? app.packageName
                                      : app.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${app.packageName} · ${app.trafficLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                secondary: Text(
                                  app.trafficLabel,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          isLoading || (!status.running && selected.isEmpty)
                              ? null
                              : status.running
                                  ? provider.stopAppWhitelistVpn
                                  : provider.startAppWhitelistVpn,
                      child: Text(status.running ? '关闭白名单' : '开启白名单'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: isLoading ? null : provider.openVpnSettings,
                    child: const Text('系统 VPN 设置'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TuningCard extends StatelessWidget {
  final String title;
  final String capability;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const _TuningCard({
    required this.title,
    required this.capability,
    required this.detail,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else
                  _CapabilityBadge(label: capability),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapabilityBadge extends StatelessWidget {
  final String label;

  const _CapabilityBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }
}
