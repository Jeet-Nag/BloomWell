import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/models/app_update_info.dart';

class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('com.bloomwell.bloomwell/app_updater');

  static const String defaultApiUrl = 'https://api.github.com/repos/Jeet-Nag/BloomWell/releases/latest';
  static const String repositoryReleasesUrl = 'https://github.com/Jeet-Nag/BloomWell/releases';

  /// Fetch installed app version info from Android package manager.
  Future<Map<String, dynamic>> getInstalledVersionInfo() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {
      // Fallback for testing or non-Android runtimes
    }
    return {
      'versionName': '1.0.0',
      'versionCode': 1,
      'applicationId': 'com.bloomwell.bloomwell',
    };
  }

  /// Check whether the app is currently allowed to install unknown apps on Android 8.0+.
  Future<bool> canRequestPackageInstalls() async {
    try {
      final res = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Launch Android settings to allow installing apps from this source.
  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Trigger the official Android system PackageInstaller for a downloaded APK.
  Future<bool> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check the latest published release on GitHub.
  Future<UpdateCheckResult> checkForUpdates({
    String apiUrl = defaultApiUrl,
    HttpClient? customClient,
  }) async {
    final versionInfo = await getInstalledVersionInfo();
    final currentVersion = versionInfo['versionName'] as String? ?? '1.0.0';

    final client = customClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse(apiUrl);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'BloomWell-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();

      if (response.statusCode == 404) {
        // No published releases found yet in repo
        return UpdateCheckResult(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
          message: 'No published releases found. You are on the latest version ($currentVersion).',
        );
      }

      if (response.statusCode == 403) {
        return UpdateCheckResult(
          status: UpdateStatus.rateLimited,
          currentVersion: currentVersion,
          message: 'GitHub API rate limit reached. Please check releases directly at: $repositoryReleasesUrl',
        );
      }

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVersion,
          message: 'Update check failed (HTTP ${response.statusCode}).',
        );
      }

      final bodyString = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(bodyString) as Map<String, dynamic>;
      } catch (e) {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVersion,
          message: 'Failed to parse release information.',
        );
      }

      var releaseInfo = AppUpdateInfo.fromJson(json);

      // Verify that an APK asset was provided in the release
      if (releaseInfo.apkDownloadUrl.isEmpty) {
        return UpdateCheckResult(
          status: UpdateStatus.noAssetFound,
          releaseInfo: releaseInfo,
          currentVersion: currentVersion,
          message: 'A release (${releaseInfo.tagName}) exists, but no BloomWell.apk asset was found.',
        );
      }

      // If SHA-256 was not in release notes but is available as an asset, fetch it
      if ((releaseInfo.sha256Checksum == null || releaseInfo.sha256Checksum!.isEmpty) &&
          releaseInfo.sha256AssetUrl != null) {
        try {
          final shaReq = await client.getUrl(Uri.parse(releaseInfo.sha256AssetUrl!));
          shaReq.headers.set('User-Agent', 'BloomWell-App');
          final shaResp = await shaReq.close();
          if (shaResp.statusCode == 200) {
            final shaBody = await shaResp.transform(utf8.decoder).join();
            final match = RegExp(r'\b([a-fA-F0-9]{64})\b').firstMatch(shaBody);
            if (match != null) {
              releaseInfo = releaseInfo.copyWith(sha256Checksum: match.group(1)?.toLowerCase());
            }
          }
        } catch (_) {
          // Checksum asset fetch error handled gracefully
        }
      }

      // Version comparison: remote vs current installed
      final cmp = compareVersions(releaseInfo.versionName, currentVersion);
      if (cmp > 0) {
        return UpdateCheckResult(
          status: UpdateStatus.updateAvailable,
          releaseInfo: releaseInfo,
          currentVersion: currentVersion,
        );
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.upToDate,
          releaseInfo: releaseInfo,
          currentVersion: currentVersion,
          message: 'You are using the latest version of BloomWell ($currentVersion).',
        );
      }
    } on SocketException {
      return UpdateCheckResult(
        status: UpdateStatus.networkError,
        currentVersion: currentVersion,
        message: 'Could not connect to update server. Please check your internet connection.',
      );
    } on TimeoutException {
      return UpdateCheckResult(
        status: UpdateStatus.networkError,
        currentVersion: currentVersion,
        message: 'Update check timed out. Please try again.',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVersion,
        message: 'An unexpected error occurred: $e',
      );
    } finally {
      if (customClient == null) {
        client.close();
      }
    }
  }

  /// Download the APK from the official release asset URL with streaming progress,
  /// cancellation support, and SHA-256 integrity verification.
  Stream<DownloadProgress> downloadAndVerifyApk(
    AppUpdateInfo releaseInfo, {
    CancelToken? cancelToken,
    HttpClient? customClient,
  }) async* {
    final client = customClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    File? tempFile;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = releaseInfo.apkFileName.isNotEmpty ? releaseInfo.apkFileName : 'BloomWell.apk';
      tempFile = File('${tempDir.path}/$fileName');

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final uri = Uri.parse(releaseInfo.apkDownloadUrl);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'BloomWell-App');
      request.headers.set('Accept', 'application/octet-stream');

      final response = await request.close();
      if (response.statusCode != 200) {
        yield DownloadProgress(
          receivedBytes: 0,
          totalBytes: 0,
          progress: 0.0,
          error: 'Download failed with HTTP ${response.statusCode}',
        );
        return;
      }

      final totalBytes = response.contentLength > 0 ? response.contentLength : releaseInfo.apkSizeBytes;
      var receivedBytes = 0;

      final sink = tempFile.openWrite();

      yield DownloadProgress(
        receivedBytes: 0,
        totalBytes: totalBytes,
        progress: 0.0,
      );

      await for (final chunk in response) {
        if (cancelToken?.isCancelled == true) {
          await sink.close();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          yield DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progress: totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0,
            isCancelled: true,
          );
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final prog = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
        yield DownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          progress: prog.clamp(0.0, 1.0),
        );
      }

      await sink.flush();
      await sink.close();

      // Check for cancellation right at finish
      if (cancelToken?.isCancelled == true) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        yield const DownloadProgress(
          receivedBytes: 0,
          totalBytes: 0,
          progress: 0.0,
          isCancelled: true,
        );
        return;
      }

      // Verify SHA-256 Checksum by streaming the file bytes through sha256
      final digest = await sha256.bind(tempFile.openRead()).first;
      final actualHash = digest.toString().toLowerCase();

      if (releaseInfo.sha256Checksum != null && releaseInfo.sha256Checksum!.isNotEmpty) {
        final expectedHash = releaseInfo.sha256Checksum!.trim().toLowerCase();
        if (actualHash != expectedHash) {
          // Checksum mismatch -> Delete unsafe file
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          yield DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progress: 1.0,
            error: 'Checksum verification failed! The downloaded package may be corrupted or tampered with.\n\n'
                'Expected: $expectedHash\nActual: $actualHash',
          );
          return;
        }
      }

      // Download and verification succeeded
      yield DownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        isDone: true,
        filePath: tempFile.path,
      );
    } catch (e) {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      yield DownloadProgress(
        receivedBytes: 0,
        totalBytes: 0,
        progress: 0.0,
        error: 'Download interrupted: $e',
      );
    } finally {
      if (customClient == null) {
        client.close();
      }
    }
  }
}
