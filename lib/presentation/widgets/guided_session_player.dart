import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/constants/app_colors.dart';

enum PlayerEngineType { unconfigured, youtube, directStream }

class GuidedSessionPlayer extends StatefulWidget {
  final String videoSource;
  final String title;
  final bool autoPlay;
  final VoidCallback onCompleted;
  final VoidCallback? onConfigureRequested;
  final Widget Function(BuildContext context, Widget player)? builder;

  const GuidedSessionPlayer({
    super.key,
    required this.videoSource,
    required this.title,
    this.autoPlay = false,
    required this.onCompleted,
    this.onConfigureRequested,
    this.builder,
  });

  /// Checks if a string looks like a YouTube link or an 11-char video ID.
  static bool isYouTubeUrl(String src) {
    final lower = src.toLowerCase().trim();
    if (lower.isEmpty) return false;
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        (lower.length == 11 && RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(lower));
  }

  /// Extracts the 11-character YouTube video ID safely from standard, short, and parameterized URLs.
  static String? extractYouTubeId(String src) {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return null;

    if (RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final standard = YoutubePlayer.convertUrlToId(trimmed);
    if (standard != null && standard.isNotEmpty) {
      return standard;
    }

    try {
      final uri = Uri.parse(trimmed);
      if (uri.queryParameters.containsKey('v')) {
        final v = uri.queryParameters['v'];
        if (v != null && RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(v)) {
          return v;
        }
      }
      if (uri.host.contains('youtu.be')) {
        final segs = uri.pathSegments;
        if (segs.isNotEmpty && RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(segs.first)) {
          return segs.first;
        }
      }
      final match = RegExp(r'(?:v=|\/embed\/|\/shorts\/|youtu\.be\/|\/v\/)([_\-a-zA-Z0-9]{11})').firstMatch(trimmed);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    } catch (_) {}

    return null;
  }

  @override
  State<GuidedSessionPlayer> createState() => _GuidedSessionPlayerState();
}

class _GuidedSessionPlayerState extends State<GuidedSessionPlayer> {
  PlayerEngineType _engineType = PlayerEngineType.unconfigured;

  // YouTube Player Controller
  YoutubePlayerController? _youtubeController;

  // Direct MP4 / HLS Video Player Controller
  VideoPlayerController? _directController;

  Timer? _loadingTimeoutTimer;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isPlaying = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant GuidedSessionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoSource != widget.videoSource) {
      _disposeControllers();
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    final src = widget.videoSource.trim();
    _loadingTimeoutTimer?.cancel();
    _hasError = false;
    _errorMessage = '';
    _isCompleted = false;

    if (src.isEmpty) {
      setState(() => _engineType = PlayerEngineType.unconfigured);
      return;
    }

    // Strictly separate YouTube URLs from normal direct stream files
    if (GuidedSessionPlayer.isYouTubeUrl(src)) {
      final ytId = GuidedSessionPlayer.extractYouTubeId(src);
      if (ytId != null && ytId.isNotEmpty) {
        _engineType = PlayerEngineType.youtube;
        _initYouTube(ytId);
      } else {
        setState(() {
          _engineType = PlayerEngineType.unconfigured;
          _hasError = true;
          _errorMessage = 'Could not extract a valid YouTube video ID from the provided link. Please check the URL format.';
        });
      }
      return;
    }

    // Direct MP4 / HLS streams only (never pass YouTube links to VideoPlayerController)
    if (Uri.tryParse(src)?.hasScheme == true) {
      _engineType = PlayerEngineType.directStream;
      _initDirectStream(src);
    } else {
      setState(() {
        _engineType = PlayerEngineType.unconfigured;
        _hasError = true;
        _errorMessage = 'Invalid video URL. Please provide a valid YouTube link or direct video stream URL.';
      });
    }
  }

  void _initYouTube(String videoId) {
    _loadingTimeoutTimer?.cancel();
    setState(() => _isLoading = true);
    try {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: widget.autoPlay,
          mute: false,
          enableCaption: false,
          isLive: false,
          forceHD: false,
          loop: false,
          hideControls: false,
          useHybridComposition: true,
        ),
      );

      _youtubeController!.addListener(_onYouTubePlayerStateChanged);

      // Loading timeout: If video never reaches ready, playing, or error in 20 seconds, surface error with Retry
      _loadingTimeoutTimer = Timer(const Duration(seconds: 20), () {
        if (!mounted) return;
        final val = _youtubeController?.value;
        final isReady = val?.isReady ?? false;
        final isPlaying = val?.isPlaying ?? false;
        final hasPlayed = val?.hasPlayed ?? false;
        if (!isReady && !isPlaying && !hasPlayed && !_hasError) {
          setState(() {
            _hasError = true;
            _isLoading = false;
            _errorMessage = 'Video loading timed out. Please check your internet connection and tap Retry.';
          });
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      _loadingTimeoutTimer?.cancel();
      setState(() {
        _hasError = true;
        _errorMessage = 'Could not load YouTube player: $e';
        _isLoading = false;
      });
    }
  }

  void _onYouTubePlayerStateChanged() {
    if (!mounted || _youtubeController == null) return;

    final controllerValue = _youtubeController!.value;

    // Detect YouTube errors accurately
    if (controllerValue.hasError && !_hasError) {
      _loadingTimeoutTimer?.cancel();
      final code = controllerValue.errorCode;
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = _getYouTubeErrorMessage(code);
      });
      return;
    }

    if (controllerValue.isReady || controllerValue.isPlaying || controllerValue.hasPlayed) {
      _loadingTimeoutTimer?.cancel();
    }

    final state = controllerValue.playerState;
    final isPlaying = controllerValue.isPlaying;

    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }

    // Genuine playback completion detection: PlayerState.ended OR reached end of duration
    final pos = controllerValue.position;
    final dur = _youtubeController!.metadata.duration;
    final reachedEnd = dur > const Duration(seconds: 5) && pos >= dur && dur > Duration.zero;

    if ((state == PlayerState.ended || reachedEnd) && !_isCompleted) {
      _handlePlaybackFinished();
    }
  }

  void _handlePlaybackFinished() {
    if (_isCompleted) return;
    _isCompleted = true;
    _loadingTimeoutTimer?.cancel();
    if (_youtubeController?.value.isFullScreen == true) {
      _youtubeController?.toggleFullScreenMode();
    }
    _youtubeController?.pause();
    widget.onCompleted();
  }

  String _getYouTubeErrorMessage(int errorCode) {
    switch (errorCode) {
      case 1:
        return 'Invalid YouTube Video ID. Please check the video URL.';
      case 2:
        return 'The request contains an invalid parameter value.';
      case 5:
        return 'The requested video content cannot be played in an embedded player.';
      case 100:
        return 'YouTube video not found. Ensure the video is not Private or deleted (use Unlisted).';
      case 101:
      case 150:
        return 'Playback on external apps disabled by owner. In YouTube Studio, verify "Allow embedding" is enabled in video details.';
      default:
        return 'Could not play YouTube video (error code $errorCode). Please check your internet connection.';
    }
  }

  Future<void> _initDirectStream(String url) async {
    _loadingTimeoutTimer?.cancel();
    setState(() => _isLoading = true);

    _loadingTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      if (!_isPlaying && !_hasError) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Video stream timed out. Please check your internet connection and tap Retry.';
        });
      }
    });

    try {
      _directController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _directController!.initialize();

      _directController!.addListener(_onDirectPlayerStateChanged);
      _loadingTimeoutTimer?.cancel();

      if (widget.autoPlay) {
        await _directController!.play();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _loadingTimeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Could not stream video. Please check your internet connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _onDirectPlayerStateChanged() {
    if (!mounted || _directController == null) return;

    final pos = _directController!.value.position;
    final dur = _directController!.value.duration;
    final isPlaying = _directController!.value.isPlaying;

    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }

    if (dur > Duration.zero && pos >= dur && !_isCompleted) {
      _isCompleted = true;
      _loadingTimeoutTimer?.cancel();
      _directController!.pause();
      widget.onCompleted();
    }
  }

  void _disposeControllers() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
    if (_youtubeController != null) {
      if (_youtubeController!.value.isFullScreen) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      _youtubeController!.removeListener(_onYouTubePlayerStateChanged);
      _youtubeController!.dispose();
      _youtubeController = null;
    }
    if (_directController != null) {
      _directController!.removeListener(_onDirectPlayerStateChanged);
      _directController!.dispose();
      _directController = null;
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _openFullScreenDirectPlayer() {
    if (_directController == null) return;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            body: Center(
              child: AspectRatio(
                aspectRatio: _directController!.value.aspectRatio > 0
                    ? _directController!.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(_directController!),
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_engineType == PlayerEngineType.unconfigured) {
      final card = _buildUnconfiguredCard();
      return widget.builder != null ? widget.builder!(context, card) : card;
    }

    if (_hasError) {
      final card = _buildErrorCard();
      return widget.builder != null ? widget.builder!(context, card) : card;
    }

    if (_isLoading) {
      final card = _buildLoadingCard();
      return widget.builder != null ? widget.builder!(context, card) : card;
    }

    if (_engineType == PlayerEngineType.youtube && _youtubeController != null) {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        // Headless test environment without native Android/iOS WebView platform
        final testPlaceholder = Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_filled, size: 48, color: AppColors.sagePrimary),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'YouTube Player (Embedded)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
        return widget.builder != null ? widget.builder!(context, testPlaceholder) : testPlaceholder;
      }

      return YoutubePlayerBuilder(
        onEnterFullScreen: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        },
        onExitFullScreen: () {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        },
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.sagePrimary,
          onEnded: (_) => _handlePlaybackFinished(),
          topActions: [
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 14.0, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
          bottomActions: [
            CurrentPosition(),
            const SizedBox(width: 8.0),
            ProgressBar(
              isExpanded: true,
              controller: _youtubeController,
              colors: const ProgressBarColors(
                playedColor: AppColors.sagePrimary,
                handleColor: AppColors.sageDark,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(width: 8.0),
            RemainingDuration(),
            FullScreenButton(controller: _youtubeController),
          ],
        ),
        builder: (context, player) {
          final embedded = ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: player,
          );
          return widget.builder != null ? widget.builder!(context, embedded) : embedded;
        },
      );
    }

    if (_engineType == PlayerEngineType.directStream && _directController != null) {
      final directWidget = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AspectRatio(
              aspectRatio: _directController!.value.aspectRatio > 0 ? _directController!.value.aspectRatio : 16 / 9,
              child: VideoPlayer(_directController!),
            ),
            // Custom Play/Pause & Fullscreen overlay controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.black45,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      if (_isPlaying) {
                        _directController!.pause();
                      } else {
                        _directController!.play();
                      }
                    },
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      _directController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.sagePrimary,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white, size: 24),
                    onPressed: _openFullScreenDirectPlayer,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      return widget.builder != null ? widget.builder!(context, directWidget) : directWidget;
    }

    final card = _buildUnconfiguredCard();
    return widget.builder != null ? widget.builder!(context, card) : card;
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.sagePrimary),
          SizedBox(height: 12),
          Text('Loading video stream...', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildUnconfiguredCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.softAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_outlined, color: AppColors.softAmber, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Video not configured yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'BloomWell streams large session videos without increasing the app size. Upload your video as "Unlisted" to YouTube (free, no private API keys required) or host it on cloud storage, and configure the URL.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (widget.onConfigureRequested != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.link, size: 16, color: AppColors.sageDark),
              label: const Text('Configure Video URL', style: TextStyle(color: AppColors.sageDark, fontWeight: FontWeight.bold)),
              onPressed: widget.onConfigureRequested,
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gentleCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gentleCoral.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.gentleCoral, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Video Playback Error',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gentleCoral),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sagePrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('Retry', style: TextStyle(fontSize: 12, color: Colors.white)),
                onPressed: () {
                  _disposeControllers();
                  _initializePlayer();
                },
              ),
              if (widget.onConfigureRequested != null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.settings, size: 16, color: AppColors.sageDark),
                  label: const Text('Edit URL', style: TextStyle(fontSize: 12, color: AppColors.sageDark)),
                  onPressed: widget.onConfigureRequested,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
