import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../models/dns_result.dart';
import '../models/network_status.dart';

class DnsScreen extends StatelessWidget {
  const DnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final isTesting = provider.dnsState == MeasurementState.measuring;
        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('DNS 优选'),
              actions: [
                if (isTesting)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: provider.dnsServers.isNotEmpty
                            ? provider.dnsTestProgress /
                                provider.dnsServers.length
                            : null,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: '开始测速',
                    onPressed: () => provider.testAllDns(),
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DnsInfoBanner(networkType: provider.currentStatus.type),
                  const SizedBox(height: 16),
                  if (isTesting) _TestingProgress(provider: provider),
                  ...provider.dnsServers.asMap().entries.map(
                        (e) => _DnsServerTile(
                          server: e.value,
                          rank: e.key,
                          isBest: e.key == 0 &&
                              provider.dnsState == MeasurementState.done &&
                              e.value.isReachable,
                          networkType: provider.currentStatus.type,
                        ),
                      ),
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

class _DnsInfoBanner extends StatelessWidget {
  final NetworkType networkType;

  const _DnsInfoBanner({required this.networkType});

  @override
  Widget build(BuildContext context) {
    final isWifi = networkType == NetworkType.wifi;
    return Card(
      color:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isWifi
                    ? '测速后点“使用”会复制 DNS 并打开设置页。Wi-Fi 可在当前网络详情中改 DNS；普通 App 不能静默写入系统网络配置。'
                    : '测速后点“使用”会复制 DNS 并打开私有 DNS 设置。移动网络通常只能通过私有 DNS 或运营商/APN 设置调整。',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestingProgress extends StatelessWidget {
  final NetworkProvider provider;
  const _TestingProgress({required this.provider});

  @override
  Widget build(BuildContext context) {
    final total = provider.dnsServers.length;
    final done = provider.dnsTestProgress;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正在测速 $done / $total ...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: total > 0 ? done / total : null,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _DnsServerTile extends StatelessWidget {
  final DnsServer server;
  final int rank;
  final bool isBest;
  final NetworkType networkType;

  const _DnsServerTile({
    required this.server,
    required this.rank,
    required this.isBest,
    required this.networkType,
  });

  Color _speedColor(String level) {
    switch (level) {
      case 'excellent':
        return const Color(0xFF00C853);
      case 'good':
        return const Color(0xFF64DD17);
      case 'fair':
        return const Color(0xFFFFD600);
      case 'poor':
        return const Color(0xFFFF6D00);
      default:
        return Colors.grey;
    }
  }

  String? _privateDnsHostname() {
    switch (server.address) {
      case '223.5.5.5':
      case '223.6.6.6':
        return 'dns.alidns.com';
      case '119.29.29.29':
        return 'dot.pub';
      case '1.1.1.1':
      case '1.0.0.1':
        return 'one.one.one.one';
      case '8.8.8.8':
      case '8.8.4.4':
        return 'dns.google';
    }
    return null;
  }

  Future<void> _useDns(BuildContext context) async {
    final provider = context.read<NetworkProvider>();
    final isWifi = networkType == NetworkType.wifi;
    final privateDnsHostname = _privateDnsHostname();
    final copiedValue = isWifi ? server.address : privateDnsHostname;
    if (copiedValue == null) return;

    await Clipboard.setData(ClipboardData(text: copiedValue));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 $copiedValue，请在系统设置中粘贴使用')),
    );
    if (isWifi) {
      await provider.openWifiSettings();
    } else {
      await provider.openPrivateDnsSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWifi = networkType == NetworkType.wifi;
    final canUse = server.address != 'auto' &&
        server.isReachable &&
        (isWifi || _privateDnsHostname() != null);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: isBest
          ? RoundedRectangleBorder(
              side: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: server.isTested && server.isReachable
                  ? _speedColor(server.speedLevel).withValues(alpha: 0.2)
                  : Colors.white10,
              child: server.isTested
                  ? Icon(
                      server.isReachable ? Icons.check : Icons.close,
                      color: server.isReachable
                          ? _speedColor(server.speedLevel)
                          : Colors.grey,
                      size: 20,
                    )
                  : Text(
                      '${rank + 1}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '最快',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (server.address != 'auto')
                    Text(
                      server.address,
                      softWrap: true,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  Text(
                    server.description,
                    softWrap: true,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    server.isTested ? server.latencyLabel : '未测试',
                    style: TextStyle(
                      color: server.isTested && server.isReachable
                          ? _speedColor(server.speedLevel)
                          : Colors.grey,
                      fontWeight:
                          server.isTested ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (canUse) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.settings, size: 18),
                tooltip: '复制并打开 DNS 设置',
                onPressed: () => _useDns(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
