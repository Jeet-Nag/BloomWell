// Domain models and utility helpers for BloomWell In-App Updates.

enum UpdateStatus {
  upToDate,
  updateAvailable,
  rateLimited,
  networkError,
  noAssetFound,
  error,
}

class AppUpdateInfo {
  final String tagName;
  final String versionName;
  final String name;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String apkFileName;
  final int apkSizeBytes;
  final DateTime? publishedAt;
  final String? sha256Checksum;
  final String? sha256AssetUrl;
  final String htmlUrl;

  const AppUpdateInfo({
    required this.tagName,
    required this.versionName,
    required this.name,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkFileName,
    required this.apkSizeBytes,
    this.publishedAt,
    this.sha256Checksum,
    this.sha256AssetUrl,
    required this.htmlUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final name = json['name'] as String? ?? tagName;
    final body = json['body'] as String? ?? '';
    final htmlUrl = json['html_url'] as String? ?? 'https://github.com/Jeet-Nag/BloomWell/releases';
    final publishedAtStr = json['published_at'] as String?;
    final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    // Normalize version name (e.g. "v1.0.1" -> "1.0.1")
    String versionName = tagName;
    if (versionName.startsWith('v') || versionName.startsWith('V')) {
      versionName = versionName.substring(1);
    }

    // Inspect release assets
    final assets = json['assets'] as List<dynamic>? ?? [];
    String apkDownloadUrl = '';
    String apkFileName = '';
    int apkSizeBytes = 0;
    String? sha256AssetUrl;
    String? sha256FromAsset;

    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final aName = (asset['name'] as String? ?? '').trim();
        final aUrl = asset['browser_download_url'] as String? ?? '';
        final aSize = (asset['size'] as num?)?.toInt() ?? 0;

        // APK asset: Look for BloomWell.apk or any .apk file
        if (aName.toLowerCase().endsWith('.apk')) {
          apkDownloadUrl = aUrl;
          apkFileName = aName;
          apkSizeBytes = aSize;
        }

        // SHA-256 asset
        if (aName.toLowerCase().endsWith('.sha256') || aName.toLowerCase() == 'sha256.txt') {
          sha256AssetUrl = aUrl;
        }
      }
    }

    // Attempt to extract SHA-256 from release body if present
    String? sha256FromBody;
    final sha256Regex = RegExp(r'\b([a-fA-F0-9]{64})\b');
    final match = sha256Regex.firstMatch(body);
    if (match != null) {
      sha256FromBody = match.group(1)?.toLowerCase();
    }

    return AppUpdateInfo(
      tagName: tagName,
      versionName: versionName,
      name: name,
      releaseNotes: body,
      apkDownloadUrl: apkDownloadUrl,
      apkFileName: apkFileName,
      apkSizeBytes: apkSizeBytes,
      publishedAt: publishedAt,
      sha256Checksum: sha256FromAsset ?? sha256FromBody,
      sha256AssetUrl: sha256AssetUrl,
      htmlUrl: htmlUrl,
    );
  }

  AppUpdateInfo copyWith({
    String? sha256Checksum,
  }) {
    return AppUpdateInfo(
      tagName: tagName,
      versionName: versionName,
      name: name,
      releaseNotes: releaseNotes,
      apkDownloadUrl: apkDownloadUrl,
      apkFileName: apkFileName,
      apkSizeBytes: apkSizeBytes,
      publishedAt: publishedAt,
      sha256Checksum: sha256Checksum ?? this.sha256Checksum,
      sha256AssetUrl: sha256AssetUrl,
      htmlUrl: htmlUrl,
    );
  }
}

class UpdateCheckResult {
  final UpdateStatus status;
  final AppUpdateInfo? releaseInfo;
  final String currentVersion;
  final String? message;

  const UpdateCheckResult({
    required this.status,
    this.releaseInfo,
    required this.currentVersion,
    this.message,
  });

  bool get isUpdateAvailable => status == UpdateStatus.updateAvailable && releaseInfo != null;
  bool get isUpToDate => status == UpdateStatus.upToDate;
}

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final bool isDone;
  final bool isCancelled;
  final String? error;
  final String? filePath;

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
    this.isDone = false,
    this.isCancelled = false,
    this.error,
    this.filePath,
  });
}

/// Helper to compare two semantic version strings (e.g. "1.0.1" and "1.0.0").
/// Returns > 0 if v1 > v2, < 0 if v1 < v2, and 0 if equal.
int compareVersions(String v1, String v2) {
  String clean(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    // Separate build number if present (e.g. "1.0.0+1")
    if (s.contains('+')) {
      s = s.split('+').first;
    }
    return s;
  }

  int getBuildNumber(String v) {
    if (v.contains('+')) {
      final parts = v.split('+');
      if (parts.length > 1) {
        return int.tryParse(parts[1]) ?? 0;
      }
    }
    return 0;
  }

  final s1 = clean(v1);
  final s2 = clean(v2);

  final parts1 = s1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final parts2 = s2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

  final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
  for (int i = 0; i < maxLen; i++) {
    final p1 = i < parts1.length ? parts1[i] : 0;
    final p2 = i < parts2.length ? parts2[i] : 0;
    if (p1 > p2) return 1;
    if (p1 < p2) return -1;
  }

  // If semantic versions are identical, compare build numbers if any
  final b1 = getBuildNumber(v1);
  final b2 = getBuildNumber(v2);
  if (b1 > b2) return 1;
  if (b1 < b2) return -1;

  return 0;
}
