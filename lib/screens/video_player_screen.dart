import 'dart:io';
import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/video_model.dart';
import '../models/user_model.dart';
import '../services/video_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;
  final User user;

  const VideoPlayerScreen({Key? key, required this.video, required this.user}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _isBuffering = false;
  String? _errorMessage;
  String? _finalVideoUrl;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWakelock();
    _enableSecureMode();
    _startRecordingCheck();
    _initializePlayer();
  }

  Future<void> _initWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock on init: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRecoverPlayer();
    }
  }

  Future<void> _checkAndRecoverPlayer() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }
    _enableSecureMode();
    if (_videoPlayerController.value.hasError) {
       _initializePlayer();
    }
  }

  void _startRecordingCheck() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final isRecording = await ScreenProtector.isRecording();
        if (isRecording) {
          if (_videoPlayerController.value.isPlaying) {
            _videoPlayerController.pause();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Screen recording detected. Playback paused.'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Screen recording check failed: $e');
      }
    });
  }

  Future<void> _enableSecureMode() async {
    // Enable screen recording protection for Android and iOS
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageOn();
  }

  Future<void> _disableSecureMode() async {
    // Disable screen recording protection
    await ScreenProtector.preventScreenshotOff();
    await ScreenProtector.protectDataLeakageOff();
  }

  void _videoListener() {
    if (_videoPlayerController.value.isBuffering != _isBuffering) {
      if (mounted) {
        setState(() {
          _isBuffering = _videoPlayerController.value.isBuffering;
        });
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      // 1. Get the robust HLS URL from Jellyfin
      final videoService = VideoService();
      _finalVideoUrl = await videoService.getPlaybackUrl(
        widget.user.serverUrl,
        widget.video.id,
        widget.user.accessToken,
        widget.user.id,
      );

      debugPrint('Initializing video with URL: $_finalVideoUrl');

      // 2. Initialize Video Player
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_finalVideoUrl!),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _videoPlayerController.initialize();
      _videoPlayerController.addListener(_videoListener);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        allowedScreenSleep: false, // Ensure screen stays on
        showControls: true,
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Video Unavailable',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _initializePlayer();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        // Remove Share/Download if any (Chewie defaults don't have them)
        // Add Title Overlay
        overlay: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ],
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Video Initialization Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Video Unavailable';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _recordingTimer?.cancel();
    _disableSecureMode();
    _videoPlayerController.removeListener(_videoListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _errorMessage = null;
                                  });
                                  _initializePlayer();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B6DCC),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Chewie(controller: _chewieController!),
                            if (_isBuffering)
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B6DCC)),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
