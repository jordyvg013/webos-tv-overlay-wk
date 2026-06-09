import 'dart:async';
import 'dart:js_interop'; // Noodzakelijk voor de .toJS conversie
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web; 

// Schone extension interop zonder de overbodige @JS() op klasseniveau
extension WebOSBroadcastExtension on web.HTMLObjectElement {
  external void channelUp();
  external void channelDown();
}

// Global reference naar onze coax-tuner
web.HTMLObjectElement? _broadcastElement;

void main() {
  ui_web.platformViewRegistry.registerViewFactory(
    'webos-coax-tuner',
    (int viewId) {
      final obj = web.document.createElement('object') as web.HTMLObjectElement;
      obj.type = 'video/broadcast';
      obj.style.width = '100%';
      obj.style.height = '100%';
      obj.style.position = 'absolute';
      obj.id = 'coax-broadcast';
      
      _broadcastElement = obj;
      return obj;
    },
  );

  runApp(const TvOverlayTestApp());
}

enum NotificationType { goal, yellowCard, redCard }

class TvOverlayTestApp extends StatelessWidget {
  const TvOverlayTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'webOS Match Overlay Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: const MatchScreen(),
    );
  }
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with TickerProviderStateMixin {
  late VideoPlayerController _lionController;
  late AnimationController _progressController;
  
  bool _isVisible = false;
  NotificationType _currentType = NotificationType.goal;
  String _titleText = "DOELPUNT!";
  String _subText = "NED 1 - 0 BRA";
  
  final Duration _displayDuration = const Duration(seconds: 15);

  @override
  void initState() {
    super.initState();

    // Jouw geoptimaliseerde webOS keyhandler via document.onkeydown
    web.document.onkeydown = ((web.KeyboardEvent event) {
      switch (event.keyCode) {
        case 427: // webOS ChannelUp
        case 33:  // PageUp fallback voor testen in browser
          _broadcastElement?.channelUp();
          break;

        case 428: // webOS ChannelDown
        case 34:  // PageDown fallback voor testen in browser
          _broadcastElement?.channelDown();
          break;
      }
    }).toJS;

    _lionController = VideoPlayerController.asset(
      'assets/videos/kling_20260609_作品_A_highly_d_4419_0.mp4',
    )..initialize().then((_) {
        _lionController.setLooping(false);
        setState(() {});
      }).catchError((error) {
        debugPrint("Video laadstatus: Wachten op bestand.");
      });

    _progressController = AnimationController(
      vsync: this,
      duration: _displayDuration,
    );
  }

  @override
  void dispose() {
    _lionController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void triggerNotification({
    required NotificationType type,
    required String title,
    required String subtitle,
  }) async {
    _progressController.reset();
    if (_lionController.value.isInitialized) {
      await _lionController.seekTo(Duration.zero);
    }

    setState(() {
      _currentType = type;
      _titleText = title;
      _subText = subtitle;
      _isVisible = true;
    });

    _progressController.forward();

    if (type == NotificationType.goal && _lionController.value.isInitialized) {
      _lionController.play();
    }

    Timer(_displayDuration, () {
      if (!mounted) return;
      setState(() {
        _isVisible = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // LAAG 1: COAX TV SIGNAAL
          const Positioned.fill(
            child: HtmlElementView(viewType: 'webos-coax-tuner'),
          ),

          // LAAG 2: BEDIENINGSKNOPPEN
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 15,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6A00)),
                      onPressed: () => triggerNotification(
                        type: NotificationType.goal,
                        title: "DOELPUNT!",
                        subtitle: "NEDERLAND 1 - 0 BRAZILIË",
                      ),
                      child: const Text("🦁 Doelpunt", style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade700),
                      onPressed: () => triggerNotification(
                        type: NotificationType.yellowCard,
                        title: "GELE KAART",
                        subtitle: "Virgil van Dijk (NED) - 42'",
                      ),
                      child: const Text("🟨 Geel", style: TextStyle(color: Colors.black)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => triggerNotification(
                        type: NotificationType.redCard,
                        title: "RODE KAART",
                        subtitle: "Denzel Dumfries (NED) - 89'",
                      ),
                      child: const Text("🟥 Rood", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                
                // ZAP KNOPPEN
                Wrap(
                  spacing: 15,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade900),
                      onPressed: () => _broadcastElement?.channelDown(),
                      icon: const Icon(Icons.arrow_downward, color: Colors.white),
                      label: const Text("Vorige Zender", style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade900),
                      onPressed: () => _broadcastElement?.channelUp(),
                      icon: const Icon(Icons.arrow_upward, color: Colors.white),
                      label: const Text("Volgende Zender", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // LAAG 3: DE BANNER OVERLAY
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            bottom: _isVisible ? 40 : -160,
            left: 80,
            right: 80,
            child: _buildBannerUI(),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerUI() {
    return Container(
      height: 120,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF001A4B).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor(), width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 25, offset: const Offset(0, 10))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: 1.0 - _progressController.value,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(_getBorderColor()),
                  minHeight: 4,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 110,
                  child: _buildLeftAsset(),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_titleText, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(_subText, style: TextStyle(fontSize: 20, color: _getSubtextColor(), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftAsset() {
    switch (_currentType) {
      case NotificationType.yellowCard:
        return Image.asset('assets/images/Copilot_20260609_112605-removebg-preview.png', fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.style, color: Colors.yellow, size: 60));
      case NotificationType.redCard:
        return Image.asset('assets/images/0VCil-removebg-preview.png', fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.style, color: Colors.red, size: 60));
      case NotificationType.goal:
      default:
        return _lionController.value.isInitialized
            ? AspectRatio(aspectRatio: _lionController.value.aspectRatio, child: VideoPlayer(_lionController))
            : const Icon(Icons.sports_soccer, color: Color(0xFFFF6A00), size: 60);
    }
  }

  Color _getBorderColor() {
    switch (_currentType) {
      case NotificationType.yellowCard: return Colors.yellow.shade600;
      case NotificationType.redCard: return Colors.red;
      default: return const Color(0xFFFF6A00);
    }
  }

  Color _getSubtextColor() {
    switch (_currentType) {
      case NotificationType.yellowCard: return Colors.yellow.shade300;
      case NotificationType.redCard: return Colors.red.shade300;
      default: return const Color(0xFFFF9E54);
    }
  }
}
