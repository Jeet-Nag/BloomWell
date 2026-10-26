import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/models/app_update_info.dart';
import '../../services/app_update_service.dart';

enum _DialogPhase {
  checking,
  upToDate,
  updateAvailable,
  downloading,
  verifying,
  readyToInstall,
  error,
}

class UpdateDialog extends StatefulWidget {
  final AppUpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.updateService,
  });

  static Future<void> show(BuildContext context, {AppUpdateService? service}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(
        updateService: service ?? AppUpdateService(),
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _DialogPhase _phase = _DialogPhase.checking;
  AppUpdateInfo? _releaseInfo;
  String _currentVersion = '1.0.0';
  String? _statusMessage;
  String? _errorMessage;

  double _downloadPercent = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedFilePath;
  bool _canInstall = false;

  CancelToken? _cancelToken;
  StreamSubscription<DownloadProgress>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _startCheck();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _startCheck() async {
    setState(() {
      _phase = _DialogPhase.checking;
      _errorMessage = null;
      _statusMessage = 'Checking for updates...';
    });

    final result = await widget.updateService.checkForUpdates();
    if (!mounted) return;

    setState(() {
      _currentVersion = result.currentVersion;
      if (result.status == UpdateStatus.updateAvailable && result.releaseInfo != null) {
        _phase = _DialogPhase.updateAvailable;
        _releaseInfo = result.releaseInfo;
      } else if (result.status == UpdateStatus.upToDate) {
        _phase = _DialogPhase.upToDate;
        _statusMessage = result.message ?? 'You are using the latest version of BloomWell (v$_currentVersion).';
      } else {
        _phase = _DialogPhase.error;
        _errorMessage = result.message ?? 'Failed to check for updates.';
      }
    });
  }

  void _startDownload() {
    final info = _releaseInfo;
    if (info == null) return;

    setState(() {
      _phase = _DialogPhase.downloading;
      _downloadPercent = 0.0;
      _downloadedBytes = 0;
      _totalBytes = info.apkSizeBytes;
      _cancelToken = CancelToken();
      _errorMessage = null;
    });

    _downloadSub?.cancel();
    _downloadSub = widget.updateService
        .downloadAndVerifyApk(info, cancelToken: _cancelToken)
        .listen(
      (progress) async {
        if (!mounted) return;

        if (progress.isCancelled) {
          setState(() {
            _phase = _DialogPhase.updateAvailable;
            _statusMessage = 'Download cancelled.';
          });
          return;
        }

        if (progress.error != null) {
          setState(() {
            _phase = _DialogPhase.error;
            _errorMessage = progress.error;
          });
          return;
        }

        if (progress.isDone && progress.filePath != null) {
          _downloadedFilePath = progress.filePath;
          final canInstall = await widget.updateService.canRequestPackageInstalls();
          if (!mounted) return;
          setState(() {
            _canInstall = canInstall;
            _phase = _DialogPhase.readyToInstall;
          });
        } else {
          setState(() {
            _downloadPercent = progress.progress;
            _downloadedBytes = progress.receivedBytes;
            _totalBytes = progress.totalBytes;
          });
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _phase = _DialogPhase.error;
          _errorMessage = 'Download error: $err';
        });
      },
    );
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
  }

  Future<void> _checkPermissionAndInstall() async {
    final path = _downloadedFilePath;
    if (path == null) return;

    final canInstall = await widget.updateService.canRequestPackageInstalls();
    if (!canInstall) {
      await widget.updateService.openInstallPermissionSettings();
      // Wait for user to return and re-check permission
      if (mounted) {
        final recheck = await widget.updateService.canRequestPackageInstalls();
        setState(() {
          _canInstall = recheck;
        });
      }
      return;
    }

    final success = await widget.updateService.installApk(path);
    if (!success && mounted) {
      setState(() {
        _errorMessage = 'Could not launch package installer. Please check app permissions.';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: _buildTitle(),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildTitle() {
    switch (_phase) {
      case _DialogPhase.checking:
        return const Row(
          children: [
            Icon(Icons.sync, color: AppColors.sagePrimary),
            SizedBox(width: 10),
            Text('Check for Updates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        );
      case _DialogPhase.upToDate:
        return const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.sagePrimary),
            SizedBox(width: 10),
            Text('Latest Version', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        );
      case _DialogPhase.updateAvailable:
        return Row(
          children: [
            const Icon(Icons.system_update, color: AppColors.sagePrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Update Available (v${_releaseInfo?.versionName ?? ''})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      case _DialogPhase.downloading:
        return const Row(
          children: [
            Icon(Icons.downloading, color: AppColors.sagePrimary),
            SizedBox(width: 10),
            Text('Downloading Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        );
      case _DialogPhase.verifying:
        return const Row(
          children: [
            Icon(Icons.verified_outlined, color: AppColors.sagePrimary),
            SizedBox(width: 10),
            Text('Verifying Integrity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        );
      case _DialogPhase.readyToInstall:
        return const Row(
          children: [
            Icon(Icons.install_mobile, color: AppColors.sagePrimary),
            SizedBox(width: 10),
            Text('Ready to Install', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        );
      case _DialogPhase.error:
        return const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.gentleCoral),
            SizedBox(width: 10),
            Text('Update Check', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        );
    }
  }

  Widget _buildContent() {
    switch (_phase) {
      case _DialogPhase.checking:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.sagePrimary),
              const SizedBox(height: 16),
              Text(
                _statusMessage ?? 'Checking for updates...',
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        );

      case _DialogPhase.upToDate:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusMessage ?? 'You are using the latest version of BloomWell.',
                style: const TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Installed: v$_currentVersion',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                ),
              ),
            ],
          ),
        );

      case _DialogPhase.updateAvailable:
        final info = _releaseInfo!;
        return SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sageLight.withAlpha(80),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v$_currentVersion → v${info.versionName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                      ),
                    ),
                    const Spacer(),
                    if (info.apkSizeBytes > 0)
                      Text(
                        _formatBytes(info.apkSizeBytes),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (info.releaseNotes.isNotEmpty) ...[
                  const Text(
                    'What\'s New:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Text(
                        info.releaseNotes,
                        style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (info.sha256Checksum != null)
                  Text(
                    'SHA-256 Checksum: ${info.sha256Checksum!.substring(0, 16)}...',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        );

      case _DialogPhase.downloading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: _downloadPercent > 0 ? _downloadPercent : null,
                backgroundColor: AppColors.surfaceCardMuted,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sagePrimary),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_downloadPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.sageDark),
                  ),
                  Text(
                    '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        );

      case _DialogPhase.verifying:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.sagePrimary),
              SizedBox(height: 16),
              Text(
                'Verifying package integrity (SHA-256)...',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        );

      case _DialogPhase.readyToInstall:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Package verified and ready to install!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              _canInstall
                  ? 'Tap "Install Now" to proceed. Android Package Installer will open and preserve all your health and water data.'
                  : 'Android requires one-time permission to allow app updates from BloomWell. Tap "Grant Permission" below, enable the switch, and return.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        );

      case _DialogPhase.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _errorMessage ?? 'An error occurred.',
                style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4),
              ),
              const SizedBox(height: 10),
              const Text(
                'You can also check for releases manually at:\ngithub.com/Jeet-Nag/BloomWell/releases',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        );
    }
  }

  List<Widget> _buildActions() {
    switch (_phase) {
      case _DialogPhase.checking:
      case _DialogPhase.verifying:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ];

      case _DialogPhase.upToDate:
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sagePrimary),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ];

      case _DialogPhase.updateAvailable:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sagePrimary),
            onPressed: _startDownload,
            child: const Text('Update Now', style: TextStyle(color: Colors.white)),
          ),
        ];

      case _DialogPhase.downloading:
        return [
          TextButton(
            onPressed: _cancelDownload,
            child: const Text('Cancel', style: TextStyle(color: AppColors.gentleCoral)),
          ),
        ];

      case _DialogPhase.readyToInstall:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sagePrimary),
            onPressed: _checkPermissionAndInstall,
            child: Text(
              _canInstall ? 'Install Now' : 'Grant Permission',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ];

      case _DialogPhase.error:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sagePrimary),
            onPressed: _startCheck,
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ];
    }
  }
}
