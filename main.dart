import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void main() {
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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
      ),
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
  
  // De overlay blijft exact 15 seconden in beeld
  final Duration _displayDuration = const Duration(seconds: 15);

  @override
  void initState() {
    super.initState();

    // Initialiseer de specifieke Kling video die je hebt geüpload
    _lionController = VideoPlayerController.asset(
      'assets/videos/kling_20260609_作品_A_highly_d_4419_0.mp4',
    )..initialize().then((_) {
        _lionController.setLooping(false); // Video speelt eenmalig af (7 seconden)
        setState(() {});
      }).catchError((error) {
        debugPrint("Video laadstatus: Nog niet aanwezig of klaar.");
      });

    // Controller voor de aftellende oranje balk bovenin
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

  // Functie die wordt aangeroepen door de testknoppen (en later de API)
  void triggerNotification({
    required NotificationType type,
    required String title,
    required String subtitle,
  }) async {
    // Reset lopende animaties en video naar het begin
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

    // Start de voortgangsbalk (loopt leeg in 15 seconden)
    _progressController.forward();

    // Speel de video alleen af bij een doelpunt
    if (type == NotificationType.goal && _lionController.value.isInitialized) {
      _lionController.play();
    }

    // Sluit de overlay automatisch na 15 seconden
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
      backgroundColor: const Color(0xFF141414), // Simuleert een donker TV scherm
      body: Stack(
        children: [
          // ── TEST KNOPPEN IN HET MIDDEN VAN HET SCHERM ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "webOS Overlay Test-Dashboard",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6A00),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () => triggerNotification(
                        type: NotificationType.goal,
                        title: "DOELPUNT!",
                        subtitle: "NEDERLAND 1 - 0 BRAZILIË",
                      ),
                      icon: const Icon(Icons.sports_soccer, color: Colors.white),
                      label: const Text("🦁 Melding: Doelpunt", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () => triggerNotification(
                        type: NotificationType.yellowCard,
                        title: "GELE KAART",
                        subtitle: "Virgil van Dijk (NED) - 42'",
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.black),
                      label: const Text("🟨 Melding: Geel", style: TextStyle(color: Colors.black, fontSize: 16)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () => triggerNotification(
                        type: NotificationType.redCard,
                        title: "RODE KAART",
                        subtitle: "Denzel Dumfries (NED) - 89'",
                      ),
                      icon: const Icon(Icons.gavel, color: Colors.white),
                      label: const Text("🟥 Melding: Rood", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── GEANIMEERDE OVERLAY BANNER (SCHUIFT VAN ONDEREN IN) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            bottom: _isVisible ? 40 : -160, // Verbergt zich onder het scherm wanneer _isVisible false is
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
      height: 120, // Platte sportieve banner hoogte
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF001A4B).withOpacity(0.96), // Premium diepblauw
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 25,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          // Aftellende indicator (balk loopt van rechts naar links leeg)
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

          // Inhoud van de melding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Links: De visuele asset (Video of PNG)
                SizedBox(
                  width: 140,
                  height: 110,
                  child: _buildLeftAsset(),
                ),

                // Midden: Gecentreerde Score / Tekst
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _titleText,
                        style: const TextStyle(
                          fontSize: 34,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subText,
                        style: TextStyle(
                          fontSize: 20,
                          color: _getSubtextColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rechterkant spacing voor perfecte visuele balans van de gecentreerde tekst
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
        return Image.asset(
          'assets/images/Copilot_20260609_112605-removebg-preview.png',
          fit: Alignment.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.style, color: Colors.yellow, size: 60),
        );
      case NotificationType.redCard:
        return Image.asset(
          'assets/images/0VCil-removebg-preview.png',
          fit: Alignment.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.style, color: Colors.red, size: 60),
        );
      case NotificationType.goal:
      default:
        return _lionController.value.isInitialized
            ? AspectRatio(
                aspectRatio: _lionController.value.aspectRatio,
                child: VideoPlayer(_lionController),
              )
            : const Icon(Icons.sports_soccer, color: Color(0xFFFF6A00), size: 60);
    }
  }

  Color _getBorderColor() {
    switch (_currentType) {
      case NotificationType.yellowCard: return Colors.yellow.shade600;
      case NotificationType.redCard: return Colors.red;
      default: return const Color(0xFFFF6A00); // Oranje
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
