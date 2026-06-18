import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../models/dns_result.dart';

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
                  _DnsInfoBanner(),
                  const SizedBox(height: 16),
                  if (isTesting) _TestingProgress(provider: provider),
                  ...provider.dnsServers.asMap().entries.map(
                        (e) => _DnsServerTile(
                          server: e.value,
                          rank: e.key,
                          isBest: e.key == 0 &&
                              provider.dnsState == MeasurementState.done &&
                              e.value.isReachable,
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
  @override
  Widget build(BuildContext context) {
    return Card(
      color:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '更快的 DNS 可以减少网页打开时间。点击右上角按钮测速，测完后手动在系统设置中更换。',
                style: TextStyle(fontSize: 13),
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

  const _DnsServerTile({
    required this.server,
    required this.rank,
    required this.isBest,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: isBest
          ? RoundedRectangleBorder(
              side: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
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
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
        ),
        title: Row(
          children: [
            Text(
              server.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isBest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (server.address != 'auto')
              Text(
                server.address,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            Text(
              server.description,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        trailing: server.isTested
            ? Text(
                server.latencyLabel,
                style: TextStyle(
                  color: server.isReachable
                      ? _speedColor(server.speedLevel)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            : const Text(
                '未测试',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
      ),
    );
  }
}
