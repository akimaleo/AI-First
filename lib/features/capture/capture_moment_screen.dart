import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/camera_provider.dart';

class CaptureMomentScreen extends ConsumerStatefulWidget {
  const CaptureMomentScreen({super.key, required this.prompt});

  final String prompt;

  @override
  ConsumerState<CaptureMomentScreen> createState() =>
      _CaptureMomentScreenState();
}

class _CaptureMomentScreenState extends ConsumerState<CaptureMomentScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  bool _startedCapture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref
          .read(captureMomentProvider.notifier)
          .beginCapture(widget.prompt);
      final phase = ref.read(captureMomentProvider).phase;
      if (phase == CapturePhase.ready) {
        await _initializeCamera();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final service = ref.read(cameraServiceProvider);
    try {
      final camera = await service.preferredFrontCamera();
      if (camera == null) {
        ref.read(captureMomentProvider.notifier).setError(
              'No camera available on this device.',
            );
        return;
      }
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      _initializeFuture = controller.initialize();
      await _initializeFuture;
      if (mounted) setState(() {});
    } catch (e) {
      ref.read(captureMomentProvider.notifier).setError(
            'Could not start camera: $e',
          );
    }
  }

  Future<void> _takeSelfie() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _startedCapture) {
      return;
    }
    _startedCapture = true;
    ref.read(captureMomentProvider.notifier).markCapturing();
    try {
      final picture = await controller.takePicture();
      await ref
          .read(captureMomentProvider.notifier)
          .onPhotoCaptured(picture.path);
    } catch (e) {
      _startedCapture = false;
      ref.read(captureMomentProvider.notifier).setError(
            'Failed to capture selfie: $e',
          );
    }
  }

  void _cancel() {
    ref.read(captureMomentProvider.notifier).reset();
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureMomentProvider);

    ref.listen<CaptureMomentState>(captureMomentProvider, (prev, next) {
      if (next.phase == CapturePhase.completed &&
          prev?.phase != CapturePhase.completed) {
        context.pushReplacementNamed('capture-result');
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody(state)),
    );
  }

  Widget _buildBody(CaptureMomentState state) {
    switch (state.phase) {
      case CapturePhase.idle:
      case CapturePhase.requestingPermission:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );

      case CapturePhase.permissionDenied:
        return _PermissionView(
          title: 'Camera needed',
          message:
              'We need camera access to capture your selfie for this moment.',
          primaryAction: 'Try again',
          onPrimary: () async {
            await ref
                .read(captureMomentProvider.notifier)
                .beginCapture(widget.prompt);
            if (ref.read(captureMomentProvider).phase == CapturePhase.ready) {
              await _initializeCamera();
            }
          },
          onCancel: _cancel,
        );

      case CapturePhase.permissionPermanentlyDenied:
        return _PermissionView(
          title: 'Camera blocked',
          message:
              'Camera access is disabled. Open settings to allow Sync or Sink to use the camera.',
          primaryAction: 'Open settings',
          onPrimary: () async {
            await ref.read(cameraServiceProvider).openAppSettingsPage();
          },
          onCancel: _cancel,
        );

      case CapturePhase.ready:
      case CapturePhase.capturing:
        return _buildCameraPreview(state);

      case CapturePhase.processing:
        return _ProcessingView(
          prompt: state.prompt ?? '',
          capturedImagePath: state.capturedImagePath,
        );

      case CapturePhase.error:
        return _ErrorView(
          message: state.error ?? 'Something went wrong.',
          onRetry: () async {
            _startedCapture = false;
            await ref
                .read(captureMomentProvider.notifier)
                .beginCapture(widget.prompt);
            if (ref.read(captureMomentProvider).phase == CapturePhase.ready) {
              await _initializeCamera();
            }
          },
          onCancel: _cancel,
        );

      case CapturePhase.completed:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
    }
  }

  Widget _buildCameraPreview(CaptureMomentState state) {
    final controller = _controller;
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 720,
              height: controller.value.previewSize?.width ?? 1280,
              child: CameraPreview(controller),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(
          top: 12,
          left: 12,
          child: IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _cancel,
          ),
        ),
        Positioned(
          top: 32,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'Capture the Moment',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.prompt ?? '',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: _ShutterButton(
              busy: state.phase == CapturePhase.capturing,
              onPressed: _takeSelfie,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPressed,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.white.withValues(alpha: 0.25),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.title,
    required this.message,
    required this.primaryAction,
    required this.onPrimary,
    required this.onCancel,
  });

  final String title;
  final String message;
  final String primaryAction;
  final VoidCallback onPrimary;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined,
              color: Colors.white, size: 72),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onPrimary, child: Text(primaryAction)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            child: const Text('Skip for now',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.prompt, required this.capturedImagePath});

  final String prompt;
  final String? capturedImagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (capturedImagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(capturedImagePath!),
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 20),
          const Text(
            'Working our magic…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt.isEmpty ? 'Transforming your selfie' : prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 72),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
