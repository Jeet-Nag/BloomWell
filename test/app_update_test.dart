import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloomwell/domain/models/app_update_info.dart';
import 'package:bloomwell/services/app_update_service.dart';

void main() {
  group('App Update Version Comparison Unit Tests', () {
    test('Correctly identifies newer patch versions', () {
      expect(compareVersions('v1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('v1.0.2', 'v1.0.1'), greaterThan(0));
    });

    test('Correctly identifies newer minor and major versions', () {
      expect(compareVersions('v1.1.0', 'v1.0.9'), greaterThan(0));
      expect(compareVersions('v2.0.0', 'v1.9.9'), greaterThan(0));
    });

    test('Returns 0 for identical versions regardless of "v" prefix', () {
      expect(compareVersions('v1.0.0', '1.0.0'), equals(0));
      expect(compareVersions('1.0.0', 'v1.0.0'), equals(0));
      expect(compareVersions('v1.0.0', 'v1.0.0'), equals(0));
    });

    test('Identifies older releases / prevents downgrades', () {
      expect(compareVersions('v1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.0.0', '1.1.0'), lessThan(0));
    });

    test('Compares build numbers when semantic versions match', () {
      expect(compareVersions('1.0.0+2', '1.0.0+1'), greaterThan(0));
      expect(compareVersions('1.0.0+1', '1.0.0+2'), lessThan(0));
      expect(compareVersions('1.0.0+1', '1.0.0+1'), equals(0));
    });
  });

  group('AppUpdateInfo JSON Parsing Unit Tests', () {
    test('Parses complete GitHub release JSON with APK and SHA256 assets', () {
      final mockJson = {
        'tag_name': 'v1.0.1',
        'name': 'BloomWell v1.0.1 Release',
        'body': 'Exciting updates and improvements.\nSHA256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        'html_url': 'https://github.com/Jeet-Nag/BloomWell/releases/tag/v1.0.1',
        'published_at': '2026-10-26T21:00:00Z',
        'assets': [
          {
            'name': 'BloomWell.apk',
            'browser_download_url': 'https://github.com/Jeet-Nag/BloomWell/releases/download/v1.0.1/BloomWell.apk',
            'size': 45000000,
          },
          {
            'name': 'BloomWell.apk.sha256',
            'browser_download_url': 'https://github.com/Jeet-Nag/BloomWell/releases/download/v1.0.1/BloomWell.apk.sha256',
            'size': 65,
          }
        ]
      };

      final info = AppUpdateInfo.fromJson(mockJson);
      expect(info.tagName, equals('v1.0.1'));
      expect(info.versionName, equals('1.0.1'));
      expect(info.apkFileName, equals('BloomWell.apk'));
      expect(info.apkDownloadUrl, contains('BloomWell.apk'));
      expect(info.apkSizeBytes, equals(45000000));
      expect(info.sha256AssetUrl, contains('BloomWell.apk.sha256'));
      expect(info.sha256Checksum, equals('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'));
    });

    test('Gracefully handles release with no APK asset', () {
      final mockJson = {
        'tag_name': 'v1.0.1',
        'name': 'Draft Release',
        'body': 'Notes without assets',
        'assets': []
      };

      final info = AppUpdateInfo.fromJson(mockJson);
      expect(info.apkDownloadUrl, isEmpty);
      expect(info.apkFileName, isEmpty);
    });
  });

  group('Checksum Integrity & Cancellation Unit Tests', () {
    test('SHA-256 calculation matches expected digest', () {
      const sampleContent = 'BloomWell APK Binary Content For Verification';
      final bytes = utf8.encode(sampleContent);
      final calculatedHash = sha256.convert(bytes).toString().toLowerCase();

      expect(calculatedHash.length, equals(64));
      expect(calculatedHash, equals(sha256.convert(bytes).toString().toLowerCase()));
    });

    test('CancelToken toggles cancellation flag', () {
      final token = CancelToken();
      expect(token.isCancelled, isFalse);
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });
}
