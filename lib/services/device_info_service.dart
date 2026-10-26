import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BatteryGuidance {
  final String manufacturerKey;
  final String manufacturerDisplayName;
  final bool isIdentified;
  final List<String> steps;
  final bool isBatteryOptimizationIgnored;
  final String statusLabel;
  final String caveat;
  final bool hasAction;

  const BatteryGuidance({
    required this.manufacturerKey,
    required this.manufacturerDisplayName,
    required this.isIdentified,
    required this.steps,
    required this.isBatteryOptimizationIgnored,
    required this.statusLabel,
    required this.caveat,
    required this.hasAction,
  });
}

class DeviceInfoService {
  static final DeviceInfoService instance = DeviceInfoService._internal();
  DeviceInfoService._internal();

  static const MethodChannel _channel = MethodChannel('com.bloomwell.bloomwell/step_counter');

  String? _cachedManufacturer;
  String? _cachedModel;
  int? _cachedSdkInt;
  bool? _cachedIsOptimizationIgnored;

  /// Allows injecting test mock values in unit tests
  @visibleForTesting
  void setMockDeviceDetails({
    String? manufacturer,
    String? model,
    int? sdkInt,
    bool? isBatteryOptimizationIgnored,
  }) {
    _cachedManufacturer = manufacturer;
    _cachedModel = model;
    _cachedSdkInt = sdkInt;
    _cachedIsOptimizationIgnored = isBatteryOptimizationIgnored;
  }

  Future<void> loadDeviceDetails() async {
    try {
      final res = await _channel.invokeMethod<Map>('getDeviceInfo');
      if (res != null) {
        _cachedManufacturer = res['manufacturer']?.toString();
        _cachedModel = res['model']?.toString();
        _cachedSdkInt = res['sdkInt'] as int?;
        _cachedIsOptimizationIgnored = res['isBatteryOptimizationIgnored'] as bool?;
      }
    } catch (e) {
      if (kDebugMode) print('Failed to get native device info: $e');
    }
  }

  String get manufacturer => _cachedManufacturer ?? 'unknown';
  String get model => _cachedModel ?? 'unknown';
  int get sdkInt => _cachedSdkInt ?? 0;
  bool get isBatteryOptimizationIgnored => _cachedIsOptimizationIgnored ?? false;

  BatteryGuidance getBatteryGuidance({required String language}) {
    final m = manufacturer.toLowerCase();
    final isHindi = language == 'hi';
    final isIgnored = isBatteryOptimizationIgnored;

    final statusText = isIgnored
        ? (isHindi
            ? 'बैटरी अनुकूलन: अप्रतिबंधित (उत्कृष्ट ट्रैकिंग)'
            : 'Battery optimization: Unrestricted (Optimal for tracking)')
        : (isHindi
            ? 'बैटरी अनुकूलन: अनुकूलित/सीमित (स्क्रीन बंद होने पर ट्रैकिंग रुक सकती है)'
            : 'Battery optimization: Restricted (Steps may pause when screen is off)');

    final caveat = isHindi
        ? 'ध्यान दें: यदि आप ऐप को ज़बरदस्ती बंद (Force Stop) करते हैं या अत्यधिक बैटरी सेवर चालू है, तो बैकग्राउंड ट्रैकिंग रुक सकती है।'
        : 'Note: If the app is force-stopped or aggressive power saving is active, Android may pause background tracking.';

    // 1. Xiaomi / Redmi / POCO
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return BatteryGuidance(
        manufacturerKey: 'xiaomi',
        manufacturerDisplayName: 'Xiaomi / POCO / HyperOS',
        isIdentified: true,
        steps: isHindi
            ? [
                'ऐप जानकारी (App Info) में बैटरी सेवर को "कोई प्रतिबंध नहीं" (No Restrictions) पर सेट करें।',
                'ऐप जानकारी में "ऑटोस्टार्ट" (Autostart) चालू करें।',
                'हाल के ऐप्स (Recent Apps) स्क्रीन में BloomWell को लॉक करें।',
              ]
            : [
                'In App Info, set Battery Saver to "No Restrictions".',
                'In App Info, enable "Autostart".',
                'Lock BloomWell in the Recent Apps overview tray so it is not cleared by RAM cleanup.',
              ],
        isBatteryOptimizationIgnored: isIgnored,
        statusLabel: statusText,
        caveat: caveat,
        hasAction: true,
      );
    }

    // 2. Samsung
    if (m.contains('samsung')) {
      return BatteryGuidance(
        manufacturerKey: 'samsung',
        manufacturerDisplayName: 'Samsung / One UI',
        isIdentified: true,
        steps: isHindi
            ? [
                'सेटिंग्स > ऐप्स > BloomWell > बैटरी में जाएं और "अप्रतिबंधित" (Unrestricted) चुनें।',
                'डिवाइस केयर > बैटरी > बैकग्राउंड उपयोग सीमा में BloomWell को "कभी न सोने वाले ऐप्स" में जोड़ें।',
                '"अप्रयुक्त ऐप्स को सुप्त करें" विकल्प से BloomWell को बाहर रखें।',
              ]
            : [
                'Go to Settings > Apps > BloomWell > Battery and select "Unrestricted".',
                'In Device Care > Battery > Background usage limits, add BloomWell to "Never sleeping apps".',
                'Turn off "Put unused apps to sleep" for BloomWell.',
              ],
        isBatteryOptimizationIgnored: isIgnored,
        statusLabel: statusText,
        caveat: caveat,
        hasAction: true,
      );
    }

    // 3. OnePlus / OPPO / Realme
    if (m.contains('oneplus') || m.contains('oppo') || m.contains('realme')) {
      return BatteryGuidance(
        manufacturerKey: 'bbk',
        manufacturerDisplayName: 'OnePlus / OPPO / Realme',
        isIdentified: true,
        steps: isHindi
            ? [
                'ऐप जानकारी > बैटरी उपयोग में "बैकग्राउंड गतिविधि की अनुमति दें" चालू करें।',
                '"ऑटो-लॉन्च" (Auto-launch) सक्षम करें।',
                'सेटिंग्स > बैटरी > उन्नत सेटिंग्स > बैटरी अनुकूलन में "अनुकूलित न करें" चुनें।',
              ]
            : [
                'In App Info > Battery usage, enable "Allow background activity".',
                'Enable "Allow auto-launch".',
                'In Settings > Battery > Optimize battery use, select "Don\'t optimize" for BloomWell.',
              ],
        isBatteryOptimizationIgnored: isIgnored,
        statusLabel: statusText,
        caveat: caveat,
        hasAction: true,
      );
    }

    // 4. Vivo / iQOO
    if (m.contains('vivo') || m.contains('iqoo')) {
      return BatteryGuidance(
        manufacturerKey: 'vivo',
        manufacturerDisplayName: 'Vivo / iQOO / Funtouch OS',
        isIdentified: true,
        steps: isHindi
            ? [
                'सेटिंग्स > बैटरी > बैकग्राउंड बिजली खपत में BloomWell के लिए "उच्च बैकग्राउंड बिजली खपत" चुनें।',
                'सेटिंग्स > एप्लिकेशन > ऑटोस्टार्ट में BloomWell को अनुमति दें।',
              ]
            : [
                'Go to Settings > Battery > Background power consumption management, and select "High background power consumption".',
                'Go to Settings > Applications > Autostart and enable BloomWell.',
              ],
        isBatteryOptimizationIgnored: isIgnored,
        statusLabel: statusText,
        caveat: caveat,
        hasAction: true,
      );
    }

    // 5. Google Pixel / Motorola / Stock Android
    if (m.contains('google') || m.contains('motorola')) {
      return BatteryGuidance(
        manufacturerKey: 'stock',
        manufacturerDisplayName: 'Google Pixel / Stock Android',
        isIdentified: true,
        steps: isHindi
            ? [
                'सेटिंग्स > ऐप्स > BloomWell > ऐप बैटरी उपयोग में जाएं।',
                'सेटिंग को "अनुकूलित" से बदलकर "अप्रतिबंधित" (Unrestricted) करें।',
              ]
            : [
                'Go to Settings > Apps > BloomWell > App battery usage.',
                'Change setting from "Optimized" to "Unrestricted".',
              ],
        isBatteryOptimizationIgnored: isIgnored,
        statusLabel: statusText,
        caveat: caveat,
        hasAction: true,
      );
    }

    // 6. Generic Android Fallback
    return BatteryGuidance(
      manufacturerKey: 'generic',
      manufacturerDisplayName: isHindi ? 'एंड्रॉयड सिस्टम अनुकूलन' : 'Android System Battery Guidance',
      isIdentified: false,
      steps: isHindi
          ? [
              'सेटिंग्स > ऐप्स > BloomWell > बैटरी में जाएं।',
              '"अप्रतिबंधित" (Unrestricted) या "अनुकूलित न करें" (Don\'t optimize) चुनें।',
              'जांचें कि बैकग्राउंड गतिविधि की अनुमति दी गई है।',
            ]
          : [
              'Open Settings > Apps > BloomWell > Battery.',
              'Choose "Unrestricted" or "Don\'t optimize" to allow continuous sensor collection.',
              'Verify that background activity is permitted.',
            ],
      isBatteryOptimizationIgnored: isIgnored,
      statusLabel: statusText,
      caveat: caveat,
      hasAction: true,
    );
  }

  Future<bool> openBatterySettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openBatterySettings');
      return res ?? false;
    } catch (e) {
      if (kDebugMode) print('Failed to open battery settings: $e');
      return false;
    }
  }
}
