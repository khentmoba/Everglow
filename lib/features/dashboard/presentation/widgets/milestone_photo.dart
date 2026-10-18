import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../../../core/perf/perf_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/app_network_image.dart';

typedef PrivateMilestonePhotoLoader = Future<Uint8List?> Function(String path);

/// Loads legacy private photos through authenticated Storage; demo fixtures
/// remain local assets and never fall back to the private photo bundle.
class MilestonePhoto extends StatefulWidget {
  final String path;
  final PrivateMilestonePhotoLoader? privatePhotoLoader;

  const MilestonePhoto({
    super.key,
    required this.path,
    this.privatePhotoLoader,
  });

  @override
  State<MilestonePhoto> createState() => _MilestonePhotoState();
}

class _MilestonePhotoState extends State<MilestonePhoto> {
  Future<Uint8List?>? _legacyPhoto;

  @override
  void initState() {
    super.initState();
    _loadLegacyPhoto();
  }

  @override
  void didUpdateWidget(covariant MilestonePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.privatePhotoLoader != widget.privatePhotoLoader) {
      _loadLegacyPhoto();
    }
  }

  void _loadLegacyPhoto() {
    _legacyPhoto = widget.path.startsWith('milestones/legacy/')
        ? _readPrivatePhoto(widget.path)
        : null;
  }

  Future<Uint8List?> _readPrivatePhoto(String path) async {
    try {
      return await (widget.privatePhotoLoader ??
          (path) => FirebaseStorage.instance
              .ref(path)
              .getData(10 * 1024 * 1024))(path);
    } catch (error, stack) {
      Logger.e(
        'Private milestone photo could not load',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path.startsWith('assets/images/demo/')) {
      return Image.asset(
        widget.path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _photoFallback(),
      );
    }
    if (_legacyPhoto != null) {
      return FutureBuilder<Uint8List?>(
        future: _legacyPhoto,
        builder: (context, snapshot) {
          if (snapshot.data == null) return _photoFallback();
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            cacheWidth: PerfSettings.sizedDecodeWidth(640),
            errorBuilder: (context, error, stack) => _photoFallback(),
          );
        },
      );
    }
    return AppNetworkImage(
      imageUrl: widget.path,
      fit: BoxFit.cover,
      cacheWidth: 600,
      errorWidget: _photoFallback(),
    );
  }

  Widget _photoFallback() => Container(
    color: AppColors.deepRose.withValues(alpha: 0.08),
    child: Center(
      child: Icon(
        Icons.broken_image_rounded,
        color: AppColors.roseQuartz.withValues(alpha: 0.4),
        size: 28,
      ),
    ),
  );
}
