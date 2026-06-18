import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cell_signal.dart';
import '../providers/network_provider.dart';

class SignalFinderScreen extends StatefulWidget {
  const SignalFinderScreen({super.key});

  @override
  State<SignalFinderScreen> createState() => _SignalFinderScreenState();
}

class _SignalFinderScreenState extends State<SignalFinderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkProvider>().refreshCellSignals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final isLoading =
            provider.cellSignalState == MeasurementState.measuring;
        final signals = provider.cellSignals;
        final best = signals.isEmpty ? null : signals.first;
        final hasFallbackOnly =
            signals.isNotEmpty && signals.every((signal) => signal.fallback);

        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('找信号'),
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
                    icon: const Icon(Icons.refresh),
                    onPressed: provider.refreshCellSignals,
                    tooltip: '刷新',
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _FinderSummary(
                    best: best,
                    count: signals.length,
                    isLoading: isLoading,
                    remainingSeconds:
                        provider.cellSignalRefreshRemainingSeconds,
                    hasFallbackOnly: hasFallbackOnly,
                    refreshMessage: provider.cellSignalRefreshMessage,
                  ),
                  const SizedBox(height: 16),
                  const _GlossaryCard(),
                  const SizedBox(height: 16),
                  if (signals.isEmpty && !isLoading)
                    const _EmptyCellState()
                  else
                    ...signals.map(
                      (signal) => _CellSignalCard(
                        signal: signal,
                        isLocked: provider.lockedCellSignalId == signal.lockId,
                        onToggleLock: () =>
                            provider.toggleCellSignalLock(signal),
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

class _FinderSummary extends StatelessWidget {
  final CellSignal? best;
  final int count;
  final bool isLoading;
  final int remainingSeconds;
  final bool hasFallbackOnly;
  final String refreshMessage;

  const _FinderSummary({
    required this.best,
    required this.count,
    required this.isLoading,
    required this.remainingSeconds,
    required this.hasFallbackOnly,
    required this.refreshMessage,
  });

  Color _levelColor(int level) {
    if (level >= 4) return const Color(0xFF00C853);
    if (level == 3) return const Color(0xFF64DD17);
    if (level == 2) return const Color(0xFFFFD600);
    if (level == 1) return const Color(0xFFFF6D00);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(best?.level ?? 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore, color: color, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoading
                            ? '正在刷新信号'
                            : best == null
                                ? '等待小区信息'
                                : hasFallbackOnly
                                    ? '当前信号概览 · ${best!.strengthLabel}'
                                    : '${best!.radio} · ${best!.strengthLabel}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLoading
                            ? '最多等待 $remainingSeconds 秒；超时会自动显示缓存或当前信号'
                            : best == null
                                ? '刷新后会显示具体原因，不会一直无反馈'
                                : hasFallbackOnly
                                    ? '系统未开放小区列表，已回退显示当前信号强度'
                                    : '当前可见 $count 个小区，优先看 dBm 更接近 0 的位置',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              )
            else
              LinearProgressIndicator(
                value: (best?.level ?? 0) / 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            const SizedBox(height: 12),
            Text(
              refreshMessage.isEmpty
                  ? '在车厢里缓慢移动、靠近车门或窗边后刷新，对比 dBm 和 level。这个功能是帮你找相对更好的位置，不会增强信号。'
                  : refreshMessage,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _CellSignalCard extends StatelessWidget {
  final CellSignal signal;
  final bool isLocked;
  final VoidCallback onToggleLock;

  const _CellSignalCard({
    required this.signal,
    required this.isLocked,
    required this.onToggleLock,
  });

  Color _levelColor(int level) {
    if (level >= 4) return const Color(0xFF00C853);
    if (level == 3) return const Color(0xFF64DD17);
    if (level == 2) return const Color(0xFFFFD600);
    if (level == 1) return const Color(0xFFFF6D00);
    return Colors.grey;
  }

  String _formatValue(Object? value) => value == null ? '--' : '$value';

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(signal.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: isLocked
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color, width: 1.2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cell_tower, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    signal.fallback
                        ? '当前信号概览 · ${signal.radio}'
                        : '${signal.displayName} · ${signal.radio}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    signal.strengthLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleLock,
                  icon: Icon(
                    isLocked ? Icons.push_pin : Icons.push_pin_outlined,
                    color: isLocked ? color : Colors.white54,
                  ),
                  tooltip: isLocked ? '取消锁定观测' : '锁定观测',
                ),
              ],
            ),
            if (isLocked) ...[
              const SizedBox(height: 8),
              Text(
                '已锁定观测：刷新后会优先帮你跟踪这个小区/信号对象。普通 App 不能强制手机连接指定基站。',
                style: TextStyle(color: color, fontSize: 12, height: 1.4),
              ),
            ],
            if (signal.fallback) ...[
              const SizedBox(height: 8),
              const Text(
                '系统没有开放小区 ID/频点等详细数据，这里显示的是当前信号强度兜底信息。',
                style:
                    TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ],
            if (signal.distanceMethod == '加权最小二乘') ...[
              const SizedBox(height: 8),
              Text(
                'WLS 估计位置：置信半径约 ${signal.estimationConfidenceMeters ?? 0} m。距离是基于 RSRP 和已知基站点位估算，不是运营商精确定位。',
                style: TextStyle(color: color, fontSize: 12, height: 1.4),
              ),
            ] else if (signal.distanceMethod == '信号模型估算') ...[
              const SizedBox(height: 8),
              Text(
                '当前为基于 dBm/RSRP 的路径损耗粗估；缺少3个以上基站点位时不能做多点定位。',
                style: TextStyle(color: color, fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SignalMetric(
                    label: 'dBm',
                    value: _formatValue(signal.dbm),
                    color: color,
                  ),
                ),
                Expanded(
                  child: _SignalMetric(
                    label: 'ASU',
                    value: _formatValue(signal.asu),
                    color: color,
                  ),
                ),
                Expanded(
                  child: _SignalMetric(
                    label: 'Level',
                    value: '${signal.level}/4',
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ChipText(label: '运营商', value: signal.operatorName),
                _ChipText(label: 'PCI', value: _formatValue(signal.pci)),
                _ChipText(label: 'TAC/LAC', value: _formatValue(signal.tac)),
                _ChipText(label: 'CI/NCI', value: _formatValue(signal.ci)),
                _ChipText(label: '频点', value: _formatValue(signal.arfcn)),
                _ChipText(label: '基站距离', value: signal.distanceLabel),
                _ChipText(label: '距离算法', value: signal.distanceMethod),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SignalMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white38),
        ),
      ],
    );
  }
}

class _ChipText extends StatelessWidget {
  final String label;
  final String value;

  const _ChipText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(Icons.help_outline),
        title: Text('术语解释'),
        children: [
          _GlossaryItem(
            term: 'dBm',
            detail: '信号功率，通常是负数，越接近 0 越强。例如 -75 dBm 通常比 -105 dBm 好。',
          ),
          _GlossaryItem(
            term: 'ASU',
            detail: 'Android 的信号单位，不同制式换算不同。一般数值越大越好。',
          ),
          _GlossaryItem(
            term: 'Level',
            detail: '系统归一化信号等级，0 到 4。适合快速判断，但不如 dBm 精细。',
          ),
          _GlossaryItem(
            term: 'PCI',
            detail: '物理小区标识，可理解为同一区域内区分小区的编号，不等于基站位置。',
          ),
          _GlossaryItem(
            term: 'TAC/LAC',
            detail: '跟踪区/位置区编号，用于运营商网络管理，不代表距离。',
          ),
          _GlossaryItem(
            term: 'CI/NCI',
            detail: '小区身份标识。4G 常见 CI，5G 常见 NCI，可用于识别是否切换到了另一个小区。',
          ),
          _GlossaryItem(
            term: '频点',
            detail: '无线频率编号，如 EARFCN/NRARFCN。不同频段覆盖和穿透能力不同。',
          ),
          _GlossaryItem(
            term: '5G NSA',
            detail:
                '非独立组网 5G，手机可能显示 5G，但系统小区列表只暴露 4G LTE 锚点。本应用会标成“5G NSA · LTE锚点”。',
          ),
          _GlossaryItem(
            term: '基站距离',
            detail: '有3个以上基站点位时采用基于 RSRP 和经纬度的加权最小二乘估计；点位不足时用信号强度路径损耗模型给出粗略距离。',
          ),
          _GlossaryItem(
            term: '信号模型估算',
            detail: '根据 dBm/RSRP 和常见路径损耗指数粗略换算距离。室内遮挡、反射、基站功率和频段都会造成明显偏差。',
          ),
          _GlossaryItem(
            term: 'WLS',
            detail: '加权最小二乘估计。信号更强、测距更稳定的小区权重更高，用多个小区共同估计手机位置，再反推到各基站的距离。',
          ),
        ],
      ),
    );
  }
}

class _GlossaryItem extends StatelessWidget {
  final String term;
  final String detail;

  const _GlossaryItem({required this.term, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              term,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCellState extends StatelessWidget {
  const _EmptyCellState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          '没有读到小区信息。请确认已允许“电话”和“位置”权限，系统位置信息开关已打开，并正在使用移动网络；部分系统会限制邻近小区数据。',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
      ),
    );
  }
}
