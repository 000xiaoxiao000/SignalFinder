import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContactQrScreen extends StatefulWidget {
  const ContactQrScreen({super.key});

  @override
  State<ContactQrScreen> createState() => _ContactQrScreenState();
}

class _ContactQrScreenState extends State<ContactQrScreen> {
  final List<_LogEntry> _logs = [];
  final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');

  @override
  void initState() {
    super.initState();
    _addLog('二维码页面已打开');
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, _LogEntry(DateTime.now(), message));
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  void _showQrPreview(_QrContact contact) {
    _addLog('查看${contact.title}二维码');
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(contact.assetPath, fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                Text(
                  contact.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogs() {
    _addLog('打开运行日志');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F24),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void clearLogs() {
              setState(() => _logs.clear());
              setSheetState(() {});
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '运行日志',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: clearLogs,
                            child: const Text('清空'),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: '关闭',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _logs.isEmpty
                              ? Center(
                                  child: Text(
                                    '暂无日志',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white54),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  reverse: true,
                                  itemCount: _logs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final entry = _logs[index];
                                    return Text(
                                      '[${_timeFormat.format(entry.time)}] ${entry.message}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white70,
                                            fontFamily: 'monospace',
                                          ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('二维码'),
          actions: [
            IconButton(
              onPressed: _showLogs,
              icon: const Icon(Icons.article_outlined),
              tooltip: '查看运行日志',
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.separated(
            itemCount: _contacts.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == _contacts.length) {
                return FilledButton.icon(
                  onPressed: _showLogs,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('查看运行日志'),
                );
              }

              final contact = _contacts[index];
              return _QrCard(
                contact: contact,
                onTap: () => _showQrPreview(contact),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QrCard extends StatelessWidget {
  final _QrContact contact;
  final VoidCallback onTap;

  const _QrCard({
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(contact.icon, color: contact.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contact.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                contact.description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            contact.assetPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrContact {
  final String title;
  final String description;
  final String assetPath;
  final IconData icon;
  final Color color;

  const _QrContact({
    required this.title,
    required this.description,
    required this.assetPath,
    required this.icon,
    required this.color,
  });
}

class _LogEntry {
  final DateTime time;
  final String message;

  const _LogEntry(this.time, this.message);
}

const _contacts = [
  _QrContact(
    title: '个人微信',
    description: '扫码添加个人微信。',
    assetPath: 'assets/qr/personal_wechat.png',
    icon: Icons.person_add_alt_1,
    color: Color(0xFF00C853),
  ),
  _QrContact(
    title: '公众号',
    description: '扫码关注公众号。',
    assetPath: 'assets/qr/public_account.jpg',
    icon: Icons.campaign_outlined,
    color: Color(0xFF40C4FF),
  ),
  _QrContact(
    title: '视频号',
    description: '扫码关注视频号。',
    assetPath: 'assets/qr/video_channel.jpg',
    icon: Icons.smart_display_outlined,
    color: Color(0xFFFFAB40),
  ),
];
