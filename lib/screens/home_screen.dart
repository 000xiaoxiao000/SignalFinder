import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../models/network_status.dart';
import 'dns_screen.dart';
import 'diagnosis_screen.dart';
import 'network_tuning_screen.dart';
import 'signal_finder_screen.dart';
import 'contact_qr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late NetworkProvider _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<NetworkProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.startAutoRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _MonitorTab(),
          SignalFinderScreen(),
          DnsScreen(),
          DiagnosisScreen(),
          ContactQrScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.network_check), label: '实时监测'),
          NavigationDestination(icon: Icon(Icons.explore), label: '找信号'),
          NavigationDestination(icon: Icon(Icons.dns), label: 'DNS 优选'),
          NavigationDestination(
              icon: Icon(Icons.medical_services_outlined), label: '网络诊断'),
          NavigationDestination(
              icon: Icon(Icons.article_outlined), label: '日志'),
        ],
      ),
    );
  }
}

class _MonitorTab extends StatelessWidget {
  const _MonitorTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final status = provider.currentStatus;
        final isMeasuring = provider.networkState == MeasurementState.measuring;
        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('SignalFinder'),
              actions: [
                IconButton(
                  icon: Icon(
                    provider.isAutoRefreshing
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  onPressed: provider.toggleAutoRefresh,
                  tooltip: provider.isAutoRefreshing ? '暂停监测' : '启动监测',
                ),
                if (isMeasuring)
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
                    icon: const Icon(Icons.refresh),
                    onPressed: () => provider.refreshQuick(),
                    tooltip: '刷新',
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SignalCard(
                    status: status,
                    isAutoRefreshing: provider.isAutoRefreshing,
                  ),
                  const SizedBox(height: 16),
                  _StabilityCard(status: status),
                  const SizedBox(height: 16),
                  _MetricsRow(status: status),
                  const SizedBox(height: 16),
                  _HistoryCard(history: provider.history),
                  const SizedBox(height: 16),
                  _QuickActionsCard(status: status),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SignalCard extends StatelessWidget {
  final NetworkStatus status;
  final bool isAutoRefreshing;
  const _SignalCard({
    required this.status,
    required this.isAutoRefreshing,
  });

  Color _signalColor(SignalStrength s) {
    switch (s) {
      case SignalStrength.excellent:
        return const Color(0xFF00C853);
      case SignalStrength.good:
        return const Color(0xFF64DD17);
      case SignalStrength.fair:
        return const Color(0xFFFFD600);
      case SignalStrength.poor:
        return const Color(0xFFFF6D00);
      case SignalStrength.none:
        return Colors.grey;
    }
  }

  double _signalValue(SignalStrength s) {
    switch (s) {
      case SignalStrength.excellent:
        return 1.0;
      case SignalStrength.good:
        return 0.75;
      case SignalStrength.fair:
        return 0.5;
      case SignalStrength.poor:
        return 0.25;
      case SignalStrength.none:
        return 0.0;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt).inSeconds;
    if (diff < 5) return '刚刚';
    if (diff < 60) return '$diff秒前';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _signalColor(status.signal);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status.isConnected
                      ? Icons.signal_cellular_alt
                      : Icons.signal_cellular_off,
                  size: 48,
                  color: color,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.networkTypeName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      status.signalLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ),
            if (status.isConnected) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _signalValue(status.signal),
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(
                isAutoRefreshing
                    ? '自动监测中，每 30 秒更新 · 上次更新：${_formatTime(status.timestamp)}'
                    : '自动监测已暂停 · 上次更新：${_formatTime(status.timestamp)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white38),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StabilityCard extends StatelessWidget {
  final NetworkStatus status;

  const _StabilityCard({required this.status});

  Color _color(NetworkStatus status) {
    if (!status.isConnected) return Colors.grey;
    switch (status.stabilityState) {
      case NetworkStabilityState.stable:
        return const Color(0xFF00C853);
      case NetworkStabilityState.slightJitter:
      case NetworkStabilityState.recovering:
        return const Color(0xFFFFD600);
      case NetworkStabilityState.congested:
      case NetworkStabilityState.highLoss:
        return const Color(0xFFFF6D00);
      case NetworkStabilityState.likelyDrop:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '平稳状态：${status.stabilityLabel}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ),
                Text(
                  '${status.stabilityScore} 分',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status.stabilityAdvice,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CompactMetric(
                  label: '抖动',
                  value: status.isConnected ? '${status.jitterMs}ms' : '--',
                ),
                _CompactMetric(
                  label: '连续失败',
                  value: status.isConnected
                      ? '${status.consecutiveFailures} 次'
                      : '--',
                ),
                _CompactMetric(
                  label: '丢包',
                  value: status.isConnected
                      ? '${status.packetLossPercent.toStringAsFixed(0)}%'
                      : '--',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CompactMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final NetworkStatus status;
  const _MetricsRow({required this.status});

  Color _latencyColor(int ms) {
    if (ms <= 0) return Colors.grey;
    if (ms < 50) return const Color(0xFF00C853);
    if (ms < 100) return const Color(0xFF64DD17);
    if (ms < 200) return const Color(0xFFFFD600);
    return const Color(0xFFFF6D00);
  }

  Color _lossColor(double loss) {
    if (loss < 5) return const Color(0xFF00C853);
    if (loss < 15) return const Color(0xFFFFD600);
    return const Color(0xFFFF6D00);
  }

  String _packetLossLabel(double loss) {
    if (loss < 5) return '无丢包';
    if (loss < 15) return '轻微丢包';
    if (loss < 30) return '丢包明显';
    return '严重丢包';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.speed,
            label: '延迟',
            value: status.pingMs > 0 ? '${status.pingMs}ms' : '--',
            subLabel: status.pingLabel,
            color: _latencyColor(status.pingMs),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.network_cell,
            label: '丢包率',
            value: status.isConnected
                ? '${status.packetLossPercent.toStringAsFixed(0)}%'
                : '--',
            subLabel: _packetLossLabel(status.packetLossPercent),
            color: _lossColor(status.packetLossPercent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Icons.download,
            label: '下载',
            value: status.downloadSpeedMbps > 0
                ? status.downloadSpeedMbps.toStringAsFixed(1)
                : '--',
            subLabel: status.downloadSpeedMbps > 0 ? 'Mbps' : '点击测速',
            color: Colors.blueAccent,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subLabel;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white54),
            ),
            Text(
              subLabel,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<NetworkStatus> history;
  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近检测记录',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...history.take(5).map((s) => _HistoryItem(status: s)),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final NetworkStatus status;
  const _HistoryItem({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = status.timestamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white38),
          ),
          const SizedBox(width: 12),
          Text(
            status.networkTypeName,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
          const Spacer(),
          Text(
            status.pingMs > 0 ? '${status.pingMs}ms' : '--',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: status.pingMs < 100
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
          ),
          const SizedBox(width: 12),
          Text(
            '丢包 ${status.packetLossPercent.toStringAsFixed(0)}%',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final NetworkStatus status;

  const _QuickActionsCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快速操作',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ActionButton(
                      width: itemWidth,
                      icon: Icons.medical_services_outlined,
                      label: '一键诊断',
                      onTap: () =>
                          context.read<NetworkProvider>().runDiagnosis(),
                    ),
                    _ActionButton(
                      width: itemWidth,
                      icon: Icons.download,
                      label: '测试速度',
                      onTap: () =>
                          context.read<NetworkProvider>().runFullMeasurement(),
                    ),
                    _ActionButton(
                      width: itemWidth,
                      icon: status.type == NetworkType.wifi
                          ? Icons.wifi
                          : Icons.signal_cellular_alt,
                      label:
                          status.type == NetworkType.wifi ? 'Wi-Fi 设置' : '移动网络',
                      onTap: () {
                        final provider = context.read<NetworkProvider>();
                        if (status.type == NetworkType.wifi) {
                          provider.openWifiSettings();
                        } else {
                          provider.openMobileNetworkSettings();
                        }
                      },
                    ),
                    _ActionButton(
                      width: itemWidth,
                      icon: Icons.data_saver_on,
                      label: '省流量',
                      onTap: () => context
                          .read<NetworkProvider>()
                          .openDataSaverSettings(),
                    ),
                    _ActionButton(
                      width: itemWidth,
                      icon: Icons.tune,
                      label: '网络调优',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NetworkTuningScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: FilledButton.tonal(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
