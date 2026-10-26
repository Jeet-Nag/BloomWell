import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../controllers/app_controller.dart';

class SelfieVerificationScreen extends StatefulWidget {
  final AppController controller;

  const SelfieVerificationScreen({super.key, required this.controller});

  @override
  State<SelfieVerificationScreen> createState() => _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _capturedPhotoPath;
  bool _isCapturing = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takeFrontSelfie();
    });
  }

  Future<void> _takeFrontSelfie() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        setState(() {
          _capturedPhotoPath = photo.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _submitSelfie() async {
    if (_capturedPhotoPath == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await widget.controller.verifyAwakeSelfie(_capturedPhotoPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wake-up verified! Alarm stopped.'),
            backgroundColor: AppColors.sagePrimary,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify selfie: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('selfieVerificationTitle', lang: lang)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.get('selfieVerificationPrompt', lang: lang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.get('selfieVerificationSubtitle', lang: lang),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),

              // Preview or placeholder
              Expanded(
                child: Center(
                  child: _capturedPhotoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.sagePrimary, width: 2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.file(
                              File(_capturedPhotoPath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCardMuted,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.face_retouching_natural,
                                size: 72,
                                color: AppColors.softAmber,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.get('noSelfieYet', lang: lang),
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              if (_capturedPhotoPath != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text(AppStrings.get('retakeSelfie', lang: lang)),
                        onPressed: _isSubmitting ? null : _takeFrontSelfie,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle),
                        label: Text(AppStrings.get('submitSelfie', lang: lang)),
                        onPressed: _isSubmitting ? null : _submitSelfie,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(AppStrings.get('openFrontCamera', lang: lang)),
                  onPressed: _isCapturing ? null : _takeFrontSelfie,
                ),
              ],
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  // Do not stop alarm or falsely mark awake
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  AppStrings.get('dismissWithoutVerify', lang: lang),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
