# BloomWell — Release & In-App Update Guide

This document outlines the standard, secure release publishing process for the BloomWell Android application (`com.bloomwell.bloomwell`).

---

## 1. Release Specification

BloomWell's built-in updater checks the official GitHub repository releases:
- **Repository:** `https://github.com/Jeet-Nag/BloomWell.git`
- **Releases API:** `https://api.github.com/repos/Jeet-Nag/BloomWell/releases/latest`
- **Release Tag Format:** `v<major>.<minor>.<patch>` (e.g. `v1.0.1`, `v1.0.2`, `v1.1.0`)
- **Primary Asset Name:** `BloomWell.apk`
- **Integrity Checksum Asset:** `BloomWell.apk.sha256` (or SHA-256 string included in the Release Notes)

---

## 2. Step-by-Step Publishing Procedure

### Step 1: Increment Version in `pubspec.yaml`
Open `mobile_app/pubspec.yaml` and update the version and build number:
```yaml
# Format: <versionName>+<versionCode>
version: 1.0.1+2
```
- `versionName` (e.g. `1.0.1`): Shown to users in Settings and update dialogs.
- `versionCode` (e.g. `2`): An integer that must increment with every release to allow Android in-place updates.

### Step 2: Build the Release APK
From the `mobile_app` directory, run:
```powershell
flutter build apk --release
```
The compiled APK will be created at:
`mobile_app/build/app/outputs/flutter-apk/app-release.apk`

Copy/rename the file to `BloomWell.apk`:
```powershell
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "build\BloomWell.apk"
```

### Step 3: Calculate the SHA-256 Checksum
BloomWell verifies the SHA-256 checksum before allowing any package installation to protect against corrupted or tampered downloads.

**In PowerShell (Windows):**
```powershell
$hash = (Get-FileHash -Algorithm SHA256 "build\BloomWell.apk").Hash.ToLower()
Set-Content -Path "build\BloomWell.apk.sha256" -Value "$hash  BloomWell.apk"
Write-Host "Release SHA-256 Checksum: $hash"
```

**In Bash (macOS/Linux):**
```bash
sha256sum build/BloomWell.apk > build/BloomWell.apk.sha256
cat build/BloomWell.apk.sha256
```

### Step 4: Create and Publish GitHub Release
1. Go to the BloomWell GitHub repository:
   `https://github.com/Jeet-Nag/BloomWell/releases/new`
2. **Choose a tag:** Type the tag name matching your release, e.g. `v1.0.1`, and select **Create new tag on publish**.
3. **Release title:** e.g., `BloomWell v1.0.1`
4. **Release description / Notes:** Add a short summary of changes, for example:
   ```markdown
   ## What's New in v1.0.1
   - Added new lotus meditation launcher icon.
   - Enhanced in-app update checking and integrity verification.
   - Minor performance optimizations and stability improvements.

   ### Package Integrity
   SHA-256: <paste your 64-character SHA-256 hash here>
   ```
5. **Attach Binaries:** Drag and drop both files into the release assets:
   - `BloomWell.apk`
   - `BloomWell.apk.sha256`
6. Click **Publish release**.

---

## 3. How Clients Check & Install the Update

1. The user navigates to **Settings & Privacy** in BloomWell.
2. Under the data tools section, they tap **Check for Updates**.
3. BloomWell queries GitHub's latest release:
   - Compares the remote version (`v1.0.1`) against the installed version (`v1.0.0`).
   - If an update is detected, the dialog displays the new version tag, file size, and release notes.
4. When the user taps **Update Now**:
   - The APK streams directly from the official GitHub Release asset into the app's secure temporary cache.
   - Real-time download progress and percentage are displayed. The user can cancel at any time.
5. Once downloaded, BloomWell computes the file's SHA-256 hash and verifies it against the published release hash.
6. The app checks Android's `REQUEST_INSTALL_PACKAGES` permission:
   - If granted, it invokes the native Android PackageInstaller.
   - If permission is needed (first update), the app guides the user to Android's "Allow from this source" screen.
7. The Android system PackageInstaller confirms:
   > *"Do you want to update this app? Existing data will not be lost."*
8. When confirmed, Android performs a safe, in-place update:
   - All SQLite database tables (weight logs, water logs, exercise history, streak counts) remain intact.
   - User preferences, morning alarms, and college schedules are completely preserved.
