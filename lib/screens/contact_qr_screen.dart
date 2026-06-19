import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../services/app_log_service.dart';

class ContactQrScreen extends StatefulWidget {
  const ContactQrScreen({super.key});

  @override
  State<ContactQrScreen> createState() => _ContactQrScreenState();
}

class _ContactQrScreenState extends State<ContactQrScreen> {
  final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');
  final AppLogService _logs = AppLogService.instance;
  final Set<String> _savingAssets = {};
  _LogLevelFilter _logLevelFilter = _LogLevelFilter.all;

  @override
  void initState() {
    super.initState();
    _logs.info('日志页面已打开');
  }

  void _showQrPreview(_QrContact contact) {
    _logs.info('查看${contact.title}二维码');
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _saveQrToGallery(contact),
                      icon: const Icon(Icons.download),
                      label: const Text('保存到相册'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveQrToGallery(_QrContact contact) async {
    if (_savingAssets.contains(contact.assetPath)) return;
    setState(() => _savingAssets.add(contact.assetPath));
    _logs.info('开始保存${contact.title}二维码到相册');

    try {
      final hasPermission = await _requestGalleryPermission();
      if (!hasPermission) {
        _logs.warning('保存${contact.title}二维码失败：没有相册权限');
        _showSnackBar('没有相册权限，无法保存二维码');
        return;
      }

      final data = await rootBundle.load(contact.assetPath);
      final bytes = data.buffer.asUint8List();
      final result = await SaverGallery.saveImage(
        bytes,
        quality: 100,
        fileName: contact.fileName,
        androidRelativePath: 'Pictures/SignalFinder',
        skipIfExists: false,
      );

      if (result.isSuccess) {
        _logs.info('${contact.title}二维码已保存到相册');
        _showSnackBar('${contact.title}已保存到相册');
      } else {
        final message = result.errorMessage ?? '未知错误';
        _logs.error('保存${contact.title}二维码失败：$message');
        _showSnackBar('保存失败：$message');
      }
    } catch (e, stack) {
      _logs.error('保存${contact.title}二维码异常', e, stack);
      _showSnackBar('保存失败：$e');
    } finally {
      if (mounted) {
        setState(() => _savingAssets.remove(contact.assetPath));
      }
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    if (Platform.isIOS) {
      return Permission.photosAddOnly.request().isGranted;
    }

    await Permission.storage.request();
    return true;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLogs() {
    _logs.info('打开运行日志');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F24),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AnimatedBuilder(
              animation: _logs,
              builder: (context, _) {
                final entries = _filteredLogEntries();
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
                                onPressed: _logs.clear,
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
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<_LogLevelFilter>(
                              segments: _LogLevelFilter.values
                                  .map(
                                    (filter) => ButtonSegment(
                                      value: filter,
                                      label: Text(filter.label),
                                    ),
                                  )
                                  .toList(),
                              selected: {_logLevelFilter},
                              onSelectionChanged: (selected) {
                                setSheetState(() {
                                  _logLevelFilter = selected.first;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: entries.isEmpty
                                  ? Center(
                                      child: Text(
                                        _logs.entries.isEmpty
                                            ? '暂无日志'
                                            : '当前级别暂无日志',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.white54),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: entries.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        return _LogLine(
                                          entry: entries[index],
                                          timeFormat: _timeFormat,
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
      },
    );
  }

  List<AppLogEntry> _filteredLogEntries() {
    return switch (_logLevelFilter) {
      _LogLevelFilter.all => _logs.entries,
      _LogLevelFilter.info => _logs.entries
          .where((entry) => entry.level == AppLogLevel.info)
          .toList(),
      _LogLevelFilter.warning => _logs.entries
          .where((entry) => entry.level == AppLogLevel.warning)
          .toList(),
      _LogLevelFilter.error => _logs.entries
          .where((entry) => entry.level == AppLogLevel.error)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('日志'),
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
                isSaving: _savingAssets.contains(contact.assetPath),
                onTap: () => _showQrPreview(contact),
                onSave: () => _saveQrToGallery(contact),
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
  final bool isSaving;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _QrCard({
    required this.contact,
    required this.isSaving,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
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
                constraints: const BoxConstraints(maxWidth: 240),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
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
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(isSaving ? '保存中' : '保存到相册'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final AppLogEntry entry;
  final DateFormat timeFormat;

  const _LogLine({
    required this.entry,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      AppLogLevel.error => const Color(0xFFFF8A80),
      AppLogLevel.warning => const Color(0xFFFFD180),
      AppLogLevel.info => Colors.white70,
    };
    final level = switch (entry.level) {
      AppLogLevel.error => 'ERROR',
      AppLogLevel.warning => 'WARN ',
      AppLogLevel.info => 'INFO ',
    };
    final error = entry.error == null ? '' : '\n${entry.error}';
    final stack = entry.stackTrace == null ? '' : '\n${entry.stackTrace}';

    return Text(
      '[${timeFormat.format(entry.time)}] $level ${entry.message}$error$stack',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontFamily: 'monospace',
          ),
    );
  }
}

enum _LogLevelFilter {
  all,
  info,
  warning,
  error;

  String get label => switch (this) {
        _LogLevelFilter.all => '全部',
        _LogLevelFilter.info => 'INFO',
        _LogLevelFilter.warning => 'WARN',
        _LogLevelFilter.error => 'ERROR',
      };
}

class _QrContact {
  final String title;
  final String description;
  final String assetPath;
  final String fileName;
  final IconData icon;
  final Color color;

  const _QrContact({
    required this.title,
    required this.description,
    required this.assetPath,
    required this.fileName,
    required this.icon,
    required this.color,
  });
}

const _contacts = [
  _QrContact(
    title: '个人微信',
    description: '扫码添加个人微信。',
    assetPath: 'assets/qr/personal_wechat.png',
    fileName: 'signal_finder_personal_wechat.png',
    icon: Icons.person_add_alt_1,
    color: Color(0xFF00C853),
  ),
  _QrContact(
    title: '公众号',
    description: '扫码关注公众号。',
    assetPath: 'assets/qr/public_account.jpg',
    fileName: 'signal_finder_public_account.jpg',
    icon: Icons.campaign_outlined,
    color: Color(0xFF40C4FF),
  ),
  _QrContact(
    title: '视频号',
    description: '扫码关注视频号。',
    assetPath: 'assets/qr/video_channel.jpg',
    fileName: 'signal_finder_video_channel.jpg',
    icon: Icons.smart_display_outlined,
    color: Color(0xFFFFAB40),
  ),
];
