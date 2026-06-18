import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import 'network_tuning_screen.dart';

class AdvancedModeScreen extends StatefulWidget {
  const AdvancedModeScreen({super.key});

  @override
  State<AdvancedModeScreen> createState() => _AdvancedModeScreenState();
}

class _AdvancedModeScreenState extends State<AdvancedModeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkProvider>().checkRootStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final root = provider.rootStatus;
        final isLoading = provider.rootState == MeasurementState.measuring;

        return Scaffold(
          appBar: AppBar(
            title: const Text('高级模式'),
            actions: [
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
                  onPressed: provider.checkRootStatus,
                  icon: const Icon(Icons.refresh),
                  tooltip: '重新检测',
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RootStatusCard(
                available: root.available,
                detail: root.detail,
                checked: root.checked,
              ),
              const SizedBox(height: 12),
              _RiskNotice(),
              const SizedBox(height: 12),
              if (!root.available) ...[
                _NormalModeCard(),
              ] else ...[
                const _RootCommandCard(
                  title: '查看 TCP 拥塞控制',
                  commandId: 'show_tcp_congestion',
                  command: 'su -c "sysctl net.ipv4.tcp_congestion_control"',
                  risk: '只读命令，用于确认当前拥塞控制算法。',
                ),
                const _RootCommandCard(
                  title: '查看 TCP 缓冲区',
                  commandId: 'show_tcp_buffers',
                  command: 'su -c "sysctl net.core.rmem_max net.core.wmem_max"',
                  risk: '只读命令，用于判断系统缓冲区上限。',
                ),
                const _RootCommandCard(
                  title: '查看私有 DNS',
                  commandId: 'show_private_dns',
                  command:
                      'su -c "settings get global private_dns_mode; settings get global private_dns_specifier"',
                  risk: '只读命令，用于排查系统私有 DNS 配置。',
                ),
                const _RootCommandCard(
                  title: '刷新系统 DNS 缓存',
                  commandId: 'flush_dns',
                  command:
                      'su -c "ndc resolver flushdefaultif; ndc resolver flushif wlan0; ndc resolver flushif rmnet_data0"',
                  risk: '低风险操作，可能短暂影响当前网络解析；失败不会修改配置。',
                ),
                _RootOutputCard(result: provider.lastRootCommandResult.output),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _RootStatusCard extends StatelessWidget {
  final bool available;
  final bool checked;
  final String detail;

  const _RootStatusCard({
    required this.available,
    required this.checked,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final color = available ? const Color(0xFF00C853) : Colors.orangeAccent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              available ? Icons.verified_user : Icons.security,
              color: color,
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !checked
                        ? 'Root 状态未检测'
                        : available
                            ? 'Root 可用'
                            : 'Root 不可用',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white60, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '高级模式不会帮你开启 Root，也不会静默提权。只有设备已经 Root 且你在 su 管理器中授权后，才会执行白名单命令。修改网络内核参数有风险，本页默认提供只读检查和低风险刷新。',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
      ),
    );
  }
}

class _NormalModeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前仅展示普通模式入口',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              '未检测到可用 su。你仍可以使用 Wi-Fi 高性能锁、省流量检测、DNS 优选、找信号等普通能力。',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NetworkTuningScreen(),
                  ),
                );
              },
              child: const Text('进入普通网络调优'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RootCommandCard extends StatelessWidget {
  final String title;
  final String commandId;
  final String command;
  final String risk;

  const _RootCommandCard({
    required this.title,
    required this.commandId,
    required this.command,
    required this.risk,
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              risk,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 10),
            SelectableText(
              command,
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: command));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('命令已复制')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('复制命令'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirmAndRun(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('授权执行'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认执行 Root 命令'),
        content: Text('$risk\n\n执行时系统 su 管理器可能弹出授权窗口。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('执行'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<NetworkProvider>().runRootCommand(commandId);
  }
}

class _RootOutputCard extends StatelessWidget {
  final String result;

  const _RootOutputCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '执行结果',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              result,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
