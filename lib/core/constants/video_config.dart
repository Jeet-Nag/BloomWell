import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for the daily two-video guided session (Exercise and Yoga).
///
/// Video files should NOT be committed to git or embedded directly in the APK.
/// The recommended zero-cost hosting setup is uploading videos to YouTube
/// with 'Unlisted' visibility (meaning anyone with the link can watch) and
/// pasting their URLs here. Direct MP4/HLS streaming URLs are also supported.
class VideoConfig {
  static const String _prefKeyExercise = 'bloomwell_exercise_video_source';
  static const String _prefKeyYoga = 'bloomwell_yoga_video_source';

  /// Default unlisted YouTube video for Exercise session.
  static const String defaultExerciseUrl = 'https://youtu.be/B8w09Rb5e54';

  /// Default unlisted YouTube video for Yoga session.
  static const String defaultYogaUrl = 'https://youtu.be/IOLnvYMy8_o';

  /// Replaceable video source for the daily Exercise session.
  /// Defaults to [defaultExerciseUrl].
  static String exerciseVideoSource = defaultExerciseUrl;

  /// Replaceable video source for the daily Yoga session.
  /// Defaults to [defaultYogaUrl].
  static String yogaVideoSource = defaultYogaUrl;

  /// Loads runtime overrides from SharedPreferences if configured by the user/tester.
  /// Falls back to default URLs if not yet saved or empty, and persists them.
  static Future<void> loadSavedSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedExercise = prefs.getString(_prefKeyExercise);
      final savedYoga = prefs.getString(_prefKeyYoga);

      if (savedExercise != null && savedExercise.trim().isNotEmpty) {
        exerciseVideoSource = savedExercise.trim();
      } else {
        exerciseVideoSource = defaultExerciseUrl;
        await prefs.setString(_prefKeyExercise, defaultExerciseUrl);
      }
      if (savedYoga != null && savedYoga.trim().isNotEmpty) {
        yogaVideoSource = savedYoga.trim();
      } else {
        yogaVideoSource = defaultYogaUrl;
        await prefs.setString(_prefKeyYoga, defaultYogaUrl);
      }
    } catch (_) {}
  }

  /// Saves runtime video URLs to SharedPreferences for testing or configuration.
  static Future<void> saveSources({
    String? exerciseUrl,
    String? yogaUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (exerciseUrl != null) {
        exerciseVideoSource = exerciseUrl.trim();
        await prefs.setString(_prefKeyExercise, exerciseVideoSource);
      }
      if (yogaUrl != null) {
        yogaVideoSource = yogaUrl.trim();
        await prefs.setString(_prefKeyYoga, yogaVideoSource);
      }
    } catch (_) {}
  }
}
