import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';
import '../services/diagnosis_service.dart';
import 'network_tuning_screen.dart';

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, provider, _) {
        final isDiagnosing =
            provider.diagnosisState == MeasurementState.measuring;
        final result = provider.diagnosisResult;

        return CustomScrollView(
          slivers: [
            const SliverAppBar.large(
              title: Text('网络诊断'),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StartButton(isDiagnosing: isDiagnosing, provider: provider),
                  const SizedBox(height: 20),
                  if (isDiagnosing) const _DiagnosingAnimation(),
                  if (result != null && !isDiagnosing) ...[
                    _ScoreCard(score: result.score, summary: result.summary),
                    const SizedBox(height: 16),
                    _TipsList(tips: result.tips),
                  ],
                  if (result == null && !isDiagnosing) const _EmptyState(),
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

class _StartButton extends StatelessWidget {
  final bool isDiagnosing;
  final NetworkProvider provider;

  const _StartButton({required this.isDiagnosing, required this.provider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isDiagnosing ? null : () => provider.runDiagnosis(),
        icon: isDiagnosing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.medical_services_outlined),
        label: Text(isDiagnosing ? '诊断中，请稍候...' : '开始一键诊断'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class _DiagnosingAnimation extends StatelessWidget {
  const _DiagnosingAnimation();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在检测网络质量，约需 20 秒...'),
          SizedBox(height: 8),
          Text(
            '测量延迟、丢包率和下载速度',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  final String summary;

  const _ScoreCard({required this.score, required this.summary});

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF00C853);
    if (s >= 60) return const Color(0xFFFFD600);
    if (s >= 40) return const Color(0xFFFF6D00);
    return Colors.redAccent;
  }

  String _scoreLabel(int s) {
    if (s >= 80) return '良好';
    if (s >= 60) return '一般';
    if (s >= 40) return '较差';
    return '很差';
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeWidth: 6,
                  ),
                  Icon(
                    Icons.done_rounded,
                    color: color,
                    size: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$score 分',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '网络评分：${_scoreLabel(score)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
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

class _TipsList extends StatelessWidget {
  final List<DiagnosisTip> tips;
  const _TipsList({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '优化建议',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...tips.map((tip) => _TipCard(tip: tip)),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  final DiagnosisTip tip;
  const _TipCard({required this.tip});

  Color _priorityColor(TipPriority p) {
    switch (p) {
      case TipPriority.high:
        return const Color(0xFFFF6D00);
      case TipPriority.medium:
        return const Color(0xFFFFD600);
      case TipPriority.low:
        return Colors.blueAccent;
    }
  }

  String _priorityLabel(TipPriority p) {
    switch (p) {
      case TipPriority.high:
        return '重要';
      case TipPriority.medium:
        return '建议';
      case TipPriority.low:
        return '可选';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(tip.priority);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tip.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tip.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _priorityLabel(tip.priority),
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.detail,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                  if (tip.action ==
                      DiagnosisTipAction.temporaryBackgroundRefreshPause) ...[
                    const SizedBox(height: 12),
                    const _TemporaryPauseControls(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemporaryPauseControls extends StatelessWidget {
  const _TemporaryPauseControls();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NetworkTuningScreen(),
            ),
          );
        },
        icon: const Icon(Icons.vpn_lock),
        label: const Text('打开网络调优'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            const Icon(
              Icons.network_check,
              size: 64,
              color: Colors.white12,
            ),
            const SizedBox(height: 16),
            Text(
              '点击上方按钮开始诊断',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.white38),
            ),
            const SizedBox(height: 8),
            Text(
              '将自动检测延迟、丢包率和下载速度\n并给出具体的优化建议',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}
