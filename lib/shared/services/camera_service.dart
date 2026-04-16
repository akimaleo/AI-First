import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionStatus { granted, denied, permanentlyDenied }

class CameraService {
  List<CameraDescription>? _cachedCameras;

  Future<CameraPermissionStatus> requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      return CameraPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return CameraPermissionStatus.permanentlyDenied;
    }
    return CameraPermissionStatus.denied;
  }

  Future<List<CameraDescription>> availableCameraDescriptions() async {
    return _cachedCameras ??= await availableCameras();
  }

  Future<CameraDescription?> preferredFrontCamera() async {
    final cameras = await availableCameraDescriptions();
    if (cameras.isEmpty) return null;
    return cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  Future<bool> openAppSettingsPage() => openAppSettings();
}
