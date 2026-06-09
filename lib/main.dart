import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

extension WebOSBroadcastExtension on web.HTMLObjectElement {
  external void channelUp();
  external void channelDown();
}

web.HTMLObjectElement? _broadcastElement;

void main() {
  ui_web.platformViewRegistry.registerViewFactory(
    'webos-coax-tuner',
    (int viewId) {
      final obj =
          web.document.createElement('object') as web.HTMLObjectElement;
      obj.type = 'video/broadcast';
      obj.style.width = '100%';
      obj.style.height = '100%';
      obj.style.position = 'absolute';
      obj.id = 'coax-broadcast';
      _broadcastElement = obj;
      return obj;
    },
  );

  runApp(const TvOverlayApp());
}

enum NotificationType { goal, yellowCard, redCard }

class TvOverlayApp extends StatelessWidget {
  const TvOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match Overlay WK',
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

class _MatchScreenState extends State<MatchScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _lionController;
  late AnimationController _progressController;
  late AnimationController _hintFade;

  bool _overlayVisible = false;
  bool _hintVisible = true;
  NotificationType _currentType = NotificationType.goal;
  String _titleText = '';
  String _subText = '';

  final Duration _displayDuration = const Duration(seconds: 15);

  // Simpele demo-teller voor herhaald triggeren van hetzelfde event
  int _goalCount = 0;
  int _yellowCount = 0;
  int _redCount = 0;

  @override
  void initState() {
    super.initState();

    // ── Toetsenbord / remote handler ───────────────────────────────────────
    web.document.onkeydown = ((web.KeyboardEvent e) {
      switch (e.keyCode) {
        // webOS gekleurde knoppen ─ afstandsbediening
        case 404: // Groen
        case 49: // '1' (browser testfallback)
          _goalCount++;
          triggerNotification(
            type: NotificationType.goal,
            title: 'DOELPUNT!',
            subtitle: 'NEDERLAND $_goalCount - 0 BRAZILIË',
          );
          break;

        case 405: // Geel
        case 50: // '2'
          _yellowCount++;
          final names = [
            'Virgil van Dijk (NED)',
            'Memphis Depay (NED)',
            'L. Martínez (BRA)',
          ];
          triggerNotification(
            type: NotificationType.yellowCard,
            title: 'GELE KAART',
            subtitle:
                '${names[(_yellowCount - 1) % names.length]} • ${40 + _yellowCount * 7}\'',
          );
          break;

        case 403: // Rood
        case 51: // '3'
          _redCount++;
          triggerNotification(
            type: NotificationType.redCard,
            title: 'RODE KAART',
            subtitle: 'Denzel Dumfries (NED) • ${80 + _redCount * 3}\'',
          );
          break;

        // Zappen
        case 427: // Channel Up
        case 33:
          _broadcastElement?.channelUp();
          break;
        case 428: // Channel Down
        case 34:
          _broadcastElement?.channelDown();
          break;
      }
    }).toJS;

    // ── Video initialisatie ────────────────────────────────────────────────
    _lionController = VideoPlayerController.asset(
      'assets/videos/kling_20260609_作品_A_highly_d_4419_0.mp4',
    )
      ..initialize().then((_) {
        _lionController.setLooping(false);
        setState(() {});
      }).catchError((e) => debugPrint('Video init: $e'));

    // ── Voortgangsbalk animatie ────────────────────────────────────────────
    _progressController = AnimationController(
      vsync: this,
      duration: _displayDuration,
    );

    // ── Hint fade-out na 6 seconden ───────────────────────────────────────
    _hintFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
    Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      _hintFade.reverse().then((_) {
        if (mounted) setState(() => _hintVisible = false);
      });
    });
  }

  @override
  void dispose() {
    _lionController.dispose();
    _progressController.dispose();
    _hintFade.dispose();
    super.dispose();
  }

  // ── Trigger een notificatie ──────────────────────────────────────────────
  Future<void> triggerNotification({
    required NotificationType type,
    required String title,
    required String subtitle,
  }) async {
    _progressController.reset();

    if (_lionController.value.isInitialized) {
      await _lionController.seekTo(Duration.zero);
      _lionController.pause();
    }

    setState(() {
      _currentType = type;
      _titleText = title;
      _subText = subtitle;
      _overlayVisible = true;
    });

    _progressController.forward();

    if (type == NotificationType.goal &&
        _lionController.value.isInitialized) {
      _lionController.play();
    }

    Timer(_displayDuration, () {
      if (!mounted) return;
      setState(() => _overlayVisible = false);
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // LAAG 1 – TV BROADCAST (coax object)
          const Positioned.fill(
            child: HtmlElementView(viewType: 'webos-coax-tuner'),
          ),

          // LAAG 2 – OPSTARTTIP (verdwijnt na 6 s)
          if (_hintVisible)
            Positioned(
              top: 28,
              right: 36,
              child: FadeTransition(
                opacity: _hintFade,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                  child: const Text(
                    '🟢 Doelpunt    🟡 Gele kaart    🔴 Rode kaart',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),

          // LAAG 3 – BANNER OVERLAY (schuift omhoog)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 580),
            curve: Curves.easeOutCubic,
            bottom: _overlayVisible ? 50 : -160,
            left: 70,
            right: 70,
            child: _buildBanner(),
          ),
        ],
      ),
    );
  }

  // ── Banner widget ────────────────────────────────────────────────────────
  Widget _buildBanner() {
    final borderColor = _getBorderColor();

    return Container(
      height: 120,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF001A4B).withOpacity(0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.35),
            blurRadius: 32,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.75),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Oranje voortgangsbalk bovenin ──────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (_, __) => LinearProgressIndicator(
                value: 1.0 - _progressController.value,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                minHeight: 5,
              ),
            ),
          ),

          // ── Banner inhoud ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Links: leeuwvideo of kaartafbeelding
                SizedBox(
                  width: 128,
                  height: 104,
                  child: _buildLeftAsset(),
                ),
                const SizedBox(width: 18),

                // Midden: titel + ondertitel
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _titleText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 33,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: borderColor.withOpacity(0.9),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _subText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: _getSubtextColor(),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
        return Image.asset(
          'assets/images/Copilot_20260609_112605-removebg-preview.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.style, color: Colors.yellow, size: 64),
        );
      case NotificationType.redCard:
        return Image.asset(
          'assets/images/0VCil-removebg-preview.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.style, color: Colors.red, size: 64),
        );
      case NotificationType.goal:
      default:
        if (_lionController.value.isInitialized) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: _lionController.value.aspectRatio,
              child: VideoPlayer(_lionController),
            ),
          );
        }
        return const Icon(Icons.sports_soccer,
            color: Color(0xFFFF6A00), size: 64);
    }
  }

  Color _getBorderColor() {
    switch (_currentType) {
      case NotificationType.yellowCard:
        return Colors.yellow.shade600;
      case NotificationType.redCard:
        return Colors.red;
      default:
        return const Color(0xFFFF6A00);
    }
  }

  Color _getSubtextColor() {
    switch (_currentType) {
      case NotificationType.yellowCard:
        return Colors.yellow.shade300;
      case NotificationType.redCard:
        return Colors.red.shade300;
      default:
        return const Color(0xFFFF9E54);
    }
  }
}
