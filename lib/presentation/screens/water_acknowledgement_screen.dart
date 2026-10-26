import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../controllers/app_controller.dart';

class WaterAcknowledgementScreen extends StatefulWidget {
  final AppController controller;

  const WaterAcknowledgementScreen({super.key, required this.controller});

  @override
  State<WaterAcknowledgementScreen> createState() => _WaterAcknowledgementScreenState();
}

class _WaterAcknowledgementScreenState extends State<WaterAcknowledgementScreen> {
  final ImagePicker _picker = ImagePicker();
  int _selectedAmount = 250;
  String? _photoPath;
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        setState(() => _photoPath = photo.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access photo: $e')),
        );
      }
    }
  }

  Future<void> _onConfirmDrink() async {
    if (_isProcessing) return;
    if (_photoPath == null || _photoPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bottle photo required: Please take a photo or choose from gallery.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final success = await widget.controller.confirmWaterDrink(
        amountMl: _selectedAmount,
        photoPath: _photoPath,
        isPhotoVerified: true,
        notes: 'Confirmed via full-screen reminder',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Great job! $_selectedAmount ml water logged and reminder resolved.'),
            backgroundColor: AppColors.sagePrimary,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save water log. Please retry.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.controller.language;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppStrings.get('waterAckTitle', lang: lang)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const SizedBox(height: 10),

            // Icon
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sageLight.withValues(alpha: 0.5),
                ),
                child: const Center(
                  child: Icon(Icons.water_drop, size: 48, color: AppColors.sagePrimary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              AppStrings.get('waterAckTitle', lang: lang),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              AppStrings.get('waterAckSubtitle', lang: lang),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Audio Alert Notice
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.get('alarmSoundPlaying', lang: lang),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bottle Photo Section
            if (_photoPath != null) ...[
              Center(
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_photoPath!),
                        height: 140,
                        width: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                      onPressed: () => setState(() => _photoPath = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Change Photo'),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.softAmber.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.camera_alt, color: AppColors.softAmber, size: 28),
                    const SizedBox(height: 6),
                    const Text(
                      'Bottle Photo Required',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please capture or choose a bottle photo to confirm water intake.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Take Photo'),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('Gallery'),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Amount Selection
            const Text(
              'Select Amount Drank:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [100, 150, 250, 500].map((amount) {
                return ChoiceChip(
                  label: Text('$amount ml'),
                  selected: _selectedAmount == amount,
                  onSelected: (_) => setState(() => _selectedAmount = amount),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Primary Action: Submit
            ElevatedButton(
              onPressed: (_photoPath != null && _photoPath!.isNotEmpty && !_isProcessing)
                  ? _onConfirmDrink
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sagePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _photoPath != null ? 'Confirm Water Intake' : 'Bottle Photo Required',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
