import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers/app_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OnboardingScreen
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  final _apiCtrl  = TextEditingController();
  int  _page      = 0;
  bool _saving    = false;
  static const _total = 4;

  // Per-page accent colours — original colour-changing palette
  static const _accents = [
    Color(0xFF7C4DFF), // violet  – welcome
    Color(0xFF2979FF), // blue    – voice
    Color(0xFF00BFA5), // teal    – budget
    Color(0xFFFFA726), // amber   – API key
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _apiCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _total - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final key = _apiCtrl.text.trim();
    if (key.isNotEmpty) {
      await ref.read(geminiServiceProvider).setApiKey(key);
      ref.read(apiKeyProvider.notifier).state = key;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) ref.read(onboardingDoneProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accents[_page];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF04040F),
        body: Stack(
          children: [
            // Ambient glow that shifts colour with each page
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.1,
                  colors: [accent.withAlpha(45), Colors.transparent],
                ),
              ),
            ),
            PageView(
              controller: _pageCtrl,
              physics: _page == _total - 1
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _WelcomePage(accent: _accents[0]),
                _VoicePage(accent: _accents[1]),
                _BudgetPage(accent: _accents[2]),
                _ApiKeyPage(accent: _accents[3], ctrl: _apiCtrl, saving: _saving),
              ],
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomBar(
                page: _page,
                total: _total,
                accent: accent,
                saving: _saving,
                onNext: _next,
                onFinish: _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page 1 — Welcome: BugMe LOGO floating with pulsing accent rings
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  final Color accent;
  const _WelcomePage({required this.accent});
  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 160),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── BugMe logo with pulsing rings ──────────────────────────
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) {
                final v = _pulse.value;
                return SizedBox(
                  width: 260, height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      Container(
                        width: 220 + 20 * v,
                        height: 220 + 20 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withAlpha((8 * (1 - v)).round()),
                          border: Border.all(
                            color: accent.withAlpha((28 * (1 - v)).round()),
                            width: 1,
                          ),
                        ),
                      ),
                      // Mid ring
                      Container(
                        width: 178,
                        height: 178,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withAlpha(18),
                          border: Border.all(
                              color: accent.withAlpha(48), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha((40 + 30 * v).round()),
                              blurRadius: 28 + 14 * v,
                            ),
                          ],
                        ),
                      ),
                      // Logo circle (white bg so logo is visible on dark screen)
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha((60 + 50 * v).round()),
                              blurRadius: 38,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Orbiting dot — top right
                      Transform.translate(
                        offset: Offset(
                          86 * math.cos(-0.4 + v * 0.4),
                          -86 * math.sin(-0.4 + v * 0.4),
                        ),
                        child: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withAlpha(190),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withAlpha(120), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      // Orbiting dot — bottom left
                      Transform.translate(
                        offset: Offset(
                          -72 * math.cos(1.2 - v * 0.3),
                          72 * math.sin(1.2 - v * 0.3),
                        ),
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withAlpha(130),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Spacer(flex: 2),

            const Text(
              'Meet BugMe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                height: 1.1,
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 500.ms)
                .slideY(begin: 0.15, curve: Curves.easeOut),

            const SizedBox(height: 16),

            const Text(
              'Your AI-powered budget tracker.\nAll hands-free, voice-first.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                height: 1.6,
              ),
            )
                .animate()
                .fadeIn(delay: 380.ms, duration: 500.ms)
                .slideY(begin: 0.1),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page 2 — Voice AI
// ─────────────────────────────────────────────────────────────────────────────

class _VoicePage extends StatelessWidget {
  final Color accent;
  const _VoicePage({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            Center(
              child: Column(
                children: [
                  // Speech bubble
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withAlpha(20), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_rounded, color: accent, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          '"Spent ₹150 on coffee"',
                          style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 14,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: -0.1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: accent.withAlpha(140), size: 28),
                  ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
                  // Parsed result card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(22),
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: accent.withAlpha(80), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withAlpha(30),
                            blurRadius: 20,
                            spreadRadius: 1),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: accent.withAlpha(35),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                              child: Text('☕',
                                  style: TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Coffee',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            Text('Food · Today',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(120),
                                    fontSize: 11)),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('−₹150',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('AI parsed',
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 480.ms, duration: 400.ms)
                      .slideY(begin: 0.1),
                ],
              ),
            ),
            const Spacer(flex: 2),
            const Text(
              'Just say it.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            )
                .animate()
                .fadeIn(delay: 150.ms, duration: 400.ms)
                .slideY(begin: 0.1),
            const SizedBox(height: 12),
            Text(
              'Speak naturally. BugMe uses Gemini AI to understand your '
              'words and log the transaction in seconds — amount, '
              'category, and date included.',
              style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 15,
                  height: 1.65),
            ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _Chip(label: '🎤  Voice-first', accent: accent),
                _Chip(label: '🤖  Gemini AI',   accent: accent),
                _Chip(label: '⚡  Instant',      accent: accent),
              ],
            ).animate().fadeIn(delay: 420.ms, duration: 400.ms),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page 3 — Budget & Goals
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetPage extends StatelessWidget {
  final Color accent;
  const _BudgetPage({required this.accent});

  @override
  Widget build(BuildContext context) {
    const bars = [
      ('🍕', 'Food',      0.65, '₹3,250 / ₹5,000'),
      ('🚗', 'Travel',    0.82, '₹4,100 / ₹5,000'),
      ('🛍️', 'Shopping', 0.30, '₹900 / ₹3,000'),
      ('🎯', 'SIP Goal',  0.55, '₹5,500 / ₹10,000'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withAlpha(15), width: 1),
              ),
              child: Column(
                children: bars.asMap().entries.map((e) {
                  final i     = e.key;
                  final b     = e.value;
                  final ratio = b.$3;
                  final isOver = ratio > 0.80;
                  final barColor = isOver
                      ? const Color(0xFFFF6B6B)
                      : accent;

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i < bars.length - 1 ? 18 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(b.$1,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(b.$2,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(b.$4,
                                style: TextStyle(
                                    color: Colors.white.withAlpha(100),
                                    fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(
                                  height: 6,
                                  color: Colors.white.withAlpha(12)),
                              FractionallySizedBox(
                                widthFactor: ratio,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: barColor.withAlpha(120),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(
                          delay: Duration(milliseconds: 100 + i * 120),
                          duration: 400.ms)
                      .slideX(begin: 0.05);
                }).toList(),
              ),
            ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
            const Spacer(flex: 2),
            const Text(
              'Know where\nit goes.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
                height: 1.15,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Text(
              'Set monthly budgets per category. Add savings goals with '
              'auto SIPs. Recurring bills run on autopilot — nothing '
              'slips through.',
              style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 15,
                  height: 1.65),
            ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _Chip(label: '📊  Budgets',    accent: accent),
                _Chip(label: '🎯  Goals & SIP', accent: accent),
                _Chip(label: '🔄  Recurring',   accent: accent),
              ],
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page 4 — API Key: BugMe logo replaces the robot emoji
// ─────────────────────────────────────────────────────────────────────────────

class _ApiKeyPage extends StatelessWidget {
  final Color accent;
  final TextEditingController ctrl;
  final bool saving;

  const _ApiKeyPage({
    required this.accent,
    required this.ctrl,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Logo with accent glow badge
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 124, height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                          color: accent.withAlpha(80), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withAlpha(60),
                            blurRadius: 40,
                            spreadRadius: 2),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: accent.withAlpha(100), blurRadius: 8),
                        ],
                      ),
                      child: const Text('AI',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 80.ms, duration: 500.ms)
                .scale(
                    begin: const Offset(0.85, 0.85),
                    duration: 500.ms,
                    curve: Curves.easeOut),
            const SizedBox(height: 28),
            const Text(
              'One last thing.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Text(
              'BugMe uses Google Gemini AI to parse your voice entries. '
              'Paste your free API key below to unlock it.',
              style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 15,
                  height: 1.65),
            ).animate().fadeIn(delay: 260.ms, duration: 400.ms),
            const SizedBox(height: 24),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'AIza...',
                hintStyle:
                    TextStyle(color: Colors.white.withAlpha(60)),
                labelText: 'Gemini API Key',
                labelStyle:
                    TextStyle(color: Colors.white.withAlpha(120)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: Colors.white.withAlpha(30), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white.withAlpha(8),
                prefixIcon: Icon(Icons.key_outlined,
                    size: 18, color: Colors.white.withAlpha(100)),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: ctrl,
                  builder: (_, v, _) => v.text.isNotEmpty
                      ? Icon(Icons.check_circle_rounded,
                          color: accent, size: 18)
                      : const SizedBox.shrink(),
                ),
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(
                    text: 'https://aistudio.google.com/app/apikey'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Link copied to clipboard!'),
                    backgroundColor: accent,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 14, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'Get a free key at aistudio.google.com  (tap to copy)',
                    style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 430.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom bar — dots + CTA
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int page;
  final int total;
  final Color accent;
  final bool saving;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _BottomBar({
    required this.page,
    required this.total,
    required this.accent,
    required this.saving,
    required this.onNext,
    required this.onFinish,
  });

  bool get _isLast => page == total - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF04040F).withAlpha(210),
            const Color(0xFF04040F),
          ],
          stops: const [0, 0.3, 0.6],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot indicators — active dot uses page accent
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (i) {
                final isActive = i == page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isActive ? accent : Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                                color: accent.withAlpha(100), blurRadius: 8),
                          ]
                        : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // CTA button
            SizedBox(
              width: double.infinity, height: 56,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [accent, accent.withAlpha(200)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withAlpha(80),
                        blurRadius: 20,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: saving ? null : (_isLast ? onFinish : onNext),
                    child: Center(
                      child: saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isLast ? "Let's go! 🚀" : 'Next',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2),
                                ),
                                if (!_isLast) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_isLast)
              TextButton(
                onPressed: saving ? null : onFinish,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                      color: Colors.white.withAlpha(80),
                      fontSize: 13),
                ),
              )
            else
              const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Chip
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color accent;
  const _Chip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(70), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}
