import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _showOverlay = false; // Hidden by default as requested
  Timer? _overlayTimer;
  String? _errorMessage;
  String? _finalVideoUrl;
  Timer? _recordingTimer;
  bool _isDirectPlay = false;
  bool _isLandscape = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Allow all orientations in player — user controls rotation via button
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initWakelock();
    _enableSecureMode();
    _startRecordingCheck();
    _initializePlayer();
  }

  void _toggleRotation() async {
    final goLandscape = !_isLandscape;
    setState(() {
      _isLandscape = goLandscape;
    });

    if (goLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
    if (_showOverlay) {
      _resetOverlayTimer();
    }
  }

  void _resetOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  void _disposeControllers() {
    _videoPlayerController.removeListener(_videoListener);
    _chewieController?.dispose();
    _videoPlayerController.dispose();
  }

  void _seekRelative(int seconds) {
    if (!_videoPlayerController.value.isInitialized) return;
    final pos = _videoPlayerController.value.position;
    final dur = _videoPlayerController.value.duration;
    var target = pos + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (dur != Duration.zero && target > dur) target = dur;
    _videoPlayerController.seekTo(target);
  }

  void _goBack() async {
    // 1. Force back to portrait FIRST
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 2. Restore system UI immediately
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

    // 3. Wait for the orientation transition to complete (longer delay)
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.of(context).pop();
    }
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

  @override
  void didChangeMetrics() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
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

    // Update progress and playing state
    if (mounted) {
      setState(() {
        _currentPosition = _videoPlayerController.value.position;
        _totalDuration = _videoPlayerController.value.duration;
      });
    }
  }

  Future<void> _initializePlayer() async {
    try {
      // 1. Get the playback URL
      final videoService = VideoService();
      _finalVideoUrl = await videoService.getPlaybackUrl(
        widget.user.serverUrl,
        widget.video.id,
        widget.user.accessToken,
        widget.user.id,
      );

      debugPrint('Initializing video with URL: $_finalVideoUrl');

      // Determine if it's direct play
      _isDirectPlay = _finalVideoUrl!.contains('static=true');

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
        allowFullScreen: false,
        allowPlaybackSpeedChanging: false,
        allowedScreenSleep: false,
        showControls: false, // Hiding native controls as requested
        fullScreenByDefault: false,
        isLive: false,
        zoomAndPan: false,
        showOptions: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF3B6DCC),
          handleColor: const Color(0xFF3B6DCC),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
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
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _resetOverlayTimer();
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
    _overlayTimer?.cancel();
    _disableSecureMode();
    _disposeControllers();

    // Final reset of system UI and orientation to Portrait
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // OrientationBuilder forces a full widget rebuild whenever orientation changes,
        // so MediaQuery inside always returns the correct new dimensions immediately.
        body: OrientationBuilder(
          builder: (context, orientation) {
            final screenSize = MediaQuery.of(context).size;
            final screenW = screenSize.width;
            final screenH = screenSize.height;

            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_errorMessage != null) {
              return Center(
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
              );
            }

            // Calculate video dimensions fresh from current screen size
            final videoAspectRatio = _videoPlayerController.value.aspectRatio == 0
                ? 16 / 9
                : _videoPlayerController.value.aspectRatio;
            final screenAspectRatio = screenW / screenH;

            double videoWidth, videoHeight;
            if (screenAspectRatio > videoAspectRatio) {
              videoHeight = screenH;
              videoWidth = videoHeight * videoAspectRatio;
            } else {
              videoWidth = screenW;
              videoHeight = videoWidth / videoAspectRatio;
            }

            return SizedBox(
              width: screenW,
              height: screenH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video layer — always sized to current screen dimensions
                  Container(
                    color: Colors.black,
                    width: screenW,
                    height: screenH,
                    child: Center(
                      child: SizedBox(
                        width: videoWidth,
                        height: videoHeight,
                        child: Chewie(controller: _chewieController!),
                      ),
                    ),
                  ),

                  // Tap detector for overlay
                  GestureDetector(
                    onTap: _toggleOverlay,
                    behavior: HitTestBehavior.translucent,
                  ),

                  // Header overlay
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: _showOverlay ? 0 : -150,
                    left: 0,
                    right: 0,
                    child: _buildHeaderContent(),
                  ),

                  // Center controls
                  _buildCenterControlsOverlay(),

                  // Bottom timeline
                  _buildBottomTimelineOverlay(),

                  // Rotation button
                  _buildRotationButtonOverlay(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRotationButtonOverlay() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showOverlay ? 100 : -100, // Move off-screen when hidden
      right: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showOverlay ? 1.0 : 0.0,
        child: _buildHeaderIcon(
          icon: _isLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation,
          onPressed: _toggleRotation,
          tooltip: 'Rotate Screen',
        ),
      ),
    );
  }

  Widget _buildCenterControlsOverlay() {
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: (_showOverlay || _isBuffering) ? 1.0 : 0.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rewind 10s (Always good to have, though not explicitly asked)
            Opacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: _buildCenterIcon(
                  icon: Icons.replay_10,
                  onPressed: () => _seekRelative(-10),
                ),
              ),
            ),
            const SizedBox(width: 40),
            // Play/Pause or Loader
            SizedBox(
              width: 80,
              height: 80,
              child: _isBuffering
                  ? const Padding(
                padding: EdgeInsets.all(10), // Adjust padding to match button size visually
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B6DCC)),
                  strokeWidth: 4,
                ),
              )
                  : Opacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showOverlay,
                  child: _buildCenterIcon(
                    icon: _videoPlayerController.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 80,
                    onPressed: () {
                      setState(() {
                        _videoPlayerController.value.isPlaying
                            ? _videoPlayerController.pause()
                            : _videoPlayerController.play();
                      });
                      _resetOverlayTimer();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
            // Fast Forward 10s
            Opacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: _buildCenterIcon(
                  icon: Icons.forward_10,
                  onPressed: () => _seekRelative(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterIcon({required IconData icon, double size = 50, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: size),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildBottomTimelineOverlay() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showOverlay ? 0 : -150,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showOverlay ? 1.0 : 0.0,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.85),
                Colors.black.withOpacity(0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seek Bar
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: const Color(0xFF3B6DCC),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: const Color(0xFF3B6DCC),
                ),
                child: Slider(
                  value: _currentPosition.inSeconds.toDouble().clamp(0.0, _totalDuration.inSeconds.toDouble()),
                  min: 0.0,
                  max: _totalDuration.inSeconds.toDouble(),
                  onChanged: (value) {
                    _videoPlayerController.seekTo(Duration(seconds: value.toInt()));
                    _resetOverlayTimer();
                  },
                ),
              ),
              // Time Labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_currentPosition),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_totalDuration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _buildHeaderContent() {
    final topPadding = MediaQuery.of(context).padding.top;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showOverlay ? 1.0 : 0.0,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title and Status Pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildPlaybackPill(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Close Button
            _buildHeaderIcon(
              icon: Icons.close_rounded,
              onPressed: _goBack,
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildPlaybackPill() {
    if (_isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _isDirectPlay ? Colors.green : Colors.yellow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _isDirectPlay ? 'DIRECT' : 'CONVERTED',
        style: TextStyle(
          color: _isDirectPlay ? Colors.white : Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}