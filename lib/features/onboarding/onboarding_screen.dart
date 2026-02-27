import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers/app_providers.dart';

// ── Brand palette (extracted from BugMe logo) ─────────────────────────────
const _kBg        = Color(0xFF060D03);
const _kLime      = Color(0xFFA2DC48);
const _kGold      = Color(0xFFFEC522);
const _kDeepGreen = Color(0xFF2A4812);
const _kMidGreen  = Color(0xFF3E7010);

// ─────────────────────────────────────────────────────────────────────────────
//  OnboardingScreen
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _apiCtrl  = TextEditingController();
  int  _page      = 0;
  bool _saving    = false;
  static const _total = 4;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _apiCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _total - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 460),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _kBg,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            // Ambient forest-green glow top-left
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.65),
                  radius: 1.0,
                  colors: [_kDeepGreen.withAlpha(100), Colors.transparent],
                ),
              ),
            ),
            // Lime glow bottom-right
            Align(
              alignment: const Alignment(1.3, 1.3),
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_kLime.withAlpha(18), Colors.transparent],
                  ),
                ),
              ),
            ),
            PageView(
              controller: _pageCtrl,
              physics: _page == _total - 1
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                const _WelcomePage(),
                const _VoicePage(),
                const _BudgetPage(),
                _ApiKeyPage(ctrl: _apiCtrl, saving: _saving),
              ],
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomBar(
                page: _page,
                total: _total,
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
//  Page 1 — Welcome (logo hero)
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  const _WelcomePage();
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
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 160),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Logo with pulsing lime rings + orbiting dots ──────────
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) {
                final v = _pulse.value;
                return SizedBox(
                  width: 260, height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outermost pulse ring
                      Container(
                        width: 230 + 22 * v,
                        height: 230 + 22 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _kLime.withAlpha((16 + 10 * (1 - v)).round()),
                            width: 1,
                          ),
                        ),
                      ),
                      // Mid ring
                      Container(
                        width: 186,
                        height: 186,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kDeepGreen.withAlpha(55),
                          border: Border.all(
                              color: _kLime.withAlpha(38), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _kLime.withAlpha((28 + 28 * v).round()),
                              blurRadius: 28 + 18 * v,
                            ),
                          ],
                        ),
                      ),
                      // Logo circle
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: _kLime.withAlpha((55 + 45 * v).round()),
                              blurRadius: 40,
                              spreadRadius: 4,
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
                      // Orbiting lime dot
                      Transform.translate(
                        offset: Offset(
                          94 * math.cos(math.pi * 0.22 + v * math.pi * 0.28),
                          -94 * math.sin(math.pi * 0.22 + v * math.pi * 0.28),
                        ),
                        child: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kLime,
                            boxShadow: [
                              BoxShadow(
                                  color: _kLime.withAlpha(160), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      // Orbiting gold dot
                      Transform.translate(
                        offset: Offset(
                          -82 * math.cos(math.pi * 0.68 - v * math.pi * 0.22),
                          82 * math.sin(math.pi * 0.68 - v * math.pi * 0.22),
                        ),
                        child: Container(
                          width: 9, height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kGold.withAlpha(210),
                            boxShadow: [
                              BoxShadow(
                                  color: _kGold.withAlpha(110), blurRadius: 7),
                            ],
                          ),
                        ),
                      ),
                      // Small secondary lime dot
                      Transform.translate(
                        offset: Offset(
                          78 * math.cos(math.pi * 1.4 + v * math.pi * 0.18),
                          78 * math.sin(math.pi * 1.4 + v * math.pi * 0.18),
                        ),
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kLime.withAlpha(180),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Spacer(flex: 2),

            // Wordmark with lime→gold gradient
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_kLime, _kGold],
              ).createShader(bounds),
              child: const Text(
                'BugMe',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.0,
                  height: 1.0,
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 180.ms, duration: 500.ms)
                .slideY(begin: 0.12, duration: 500.ms, curve: Curves.easeOut),

            const SizedBox(height: 10),

            Text(
              'Your voice-powered\nbudget companion.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(145),
                fontSize: 17,
                height: 1.55,
              ),
            )
                .animate()
                .fadeIn(delay: 320.ms, duration: 500.ms)
                .slideY(begin: 0.08),

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
  const _VoicePage();

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
                  // Mic pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: _kDeepGreen.withAlpha(120),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kLime.withAlpha(60), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kLime.withAlpha(28),
                            border: Border.all(
                                color: _kLime.withAlpha(90)),
                          ),
                          child: const Icon(Icons.mic_rounded,
                              color: _kLime, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '"Paid ₹240 for groceries"',
                          style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 14,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 400.ms)
                      .slideY(begin: -0.1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 1, height: 20,
                            color: _kLime.withAlpha(60)),
                        const SizedBox(width: 8),
                        Icon(Icons.auto_awesome_rounded,
                            color: _kGold.withAlpha(180), size: 16),
                        const SizedBox(width: 8),
                        Container(
                            width: 1, height: 20,
                            color: _kGold.withAlpha(60)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 260.ms),
                  // Parsed result card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kDeepGreen.withAlpha(80),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kLime.withAlpha(70), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: _kLime.withAlpha(22),
                            blurRadius: 24,
                            spreadRadius: 1),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: _kLime.withAlpha(22),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _kLime.withAlpha(55), width: 1),
                          ),
                          child: const Center(
                              child: Text('🛒',
                                  style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Groceries',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            Text('Food · Today',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(110),
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 28),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('−₹240',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kLime.withAlpha(28),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _kLime.withAlpha(75),
                                    width: 0.7),
                              ),
                              child: const Text('AI',
                                  style: TextStyle(
                                      color: _kLime,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 440.ms, duration: 420.ms)
                      .slideY(begin: 0.1),
                ],
              ),
            ),
            const Spacer(flex: 2),
            const Text(
              'Just say it.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Text(
              'BugMe listens to natural speech and uses Gemini AI to '
              'extract amount, category, and date — all in one shot.',
              style: TextStyle(
                  color: Colors.white.withAlpha(145),
                  fontSize: 15,
                  height: 1.65),
            ).animate().fadeIn(delay: 240.ms, duration: 400.ms),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: const [
                _BrandChip(label: '🎤  Voice-first'),
                _BrandChip(label: '🤖  Gemini AI'),
                _BrandChip(label: '⚡  Instant log'),
              ],
            ).animate().fadeIn(delay: 380.ms, duration: 400.ms),
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
  const _BudgetPage();

  @override
  Widget build(BuildContext context) {
    const bars = [
      ('🍕', 'Food',       0.62, '₹3,100 / ₹5,000', false),
      ('🚗', 'Travel',     0.84, '₹4,200 / ₹5,000', true),
      ('🛍️', 'Shopping',  0.28, '₹840 / ₹3,000',   false),
      ('📈', 'SIP Goal',   0.55, '₹5,500 / ₹10,000', false),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 20),
              decoration: BoxDecoration(
                color: _kDeepGreen.withAlpha(55),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: _kLime.withAlpha(28), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: _kLime.withAlpha(10),
                      blurRadius: 30,
                      spreadRadius: 1),
                ],
              ),
              child: Column(
                children: bars.asMap().entries.map((e) {
                  final i      = e.key;
                  final b      = e.value;
                  final emoji  = b.$1;
                  final label  = b.$2;
                  final ratio  = b.$3;
                  final text   = b.$4;
                  final isOver = b.$5;
                  final barCol = isOver
                      ? const Color(0xFFFF6B6B)
                      : _kLime;

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i < bars.length - 1 ? 18 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(emoji,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(label,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(text,
                                style: TextStyle(
                                    color: Colors.white.withAlpha(90),
                                    fontSize: 10)),
                            if (isOver)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B6B)
                                        .withAlpha(22),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: const Text('Over',
                                      style: TextStyle(
                                          color: Color(0xFFFF6B6B),
                                          fontSize: 8,
                                          fontWeight:
                                              FontWeight.w800)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(
                            children: [
                              Container(
                                  height: 6,
                                  color: Colors.white.withAlpha(10)),
                              FractionallySizedBox(
                                widthFactor: ratio.clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isOver
                                          ? [
                                              const Color(0xFFFF6B6B),
                                              const Color(0xFFFF9B9B),
                                            ]
                                          : [_kMidGreen, barCol],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(5),
                                    boxShadow: [
                                      BoxShadow(
                                          color: barCol.withAlpha(100),
                                          blurRadius: 5),
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
                          delay: Duration(milliseconds: 80 + i * 100),
                          duration: 380.ms)
                      .slideX(begin: 0.04);
                }).toList(),
              ),
            ).animate().fadeIn(delay: 60.ms, duration: 380.ms),
            const Spacer(flex: 2),
            const Text(
              'Know where\nit goes.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                height: 1.15,
              ),
            ).animate().fadeIn(delay: 140.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Text(
              'Set per-category budgets, hit savings goals with auto SIPs, '
              'and let recurring bills run on autopilot.',
              style: TextStyle(
                  color: Colors.white.withAlpha(145),
                  fontSize: 15,
                  height: 1.65),
            ).animate().fadeIn(delay: 260.ms, duration: 400.ms),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: const [
                _BrandChip(label: '📊  Budgets'),
                _BrandChip(label: '🎯  Goals & SIP', gold: true),
                _BrandChip(label: '🔄  Auto-pay'),
              ],
            ).animate().fadeIn(delay: 390.ms, duration: 400.ms),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page 4 — API Key
// ─────────────────────────────────────────────────────────────────────────────

class _ApiKeyPage extends StatelessWidget {
  final TextEditingController ctrl;
  final bool saving;
  const _ApiKeyPage({required this.ctrl, required this.saving});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 210),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo with gold AI badge
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 128, height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                          color: _kGold.withAlpha(80), width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: _kGold.withAlpha(65),
                            blurRadius: 50,
                            spreadRadius: 4),
                        BoxShadow(
                            color: _kLime.withAlpha(35),
                            blurRadius: 30),
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
                    top: 10, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kGold, Color(0xFFFED44A)]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: _kGold.withAlpha(100),
                              blurRadius: 8),
                        ],
                      ),
                      child: const Text('AI',
                          style: TextStyle(
                              color: _kBg,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 60.ms, duration: 500.ms)
                .scale(
                    begin: const Offset(0.85, 0.85),
                    duration: 500.ms,
                    curve: Curves.easeOut),

            const SizedBox(height: 28),
            const Text(
              'Power it with AI.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ).animate().fadeIn(delay: 140.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Text(
              'BugMe uses Google Gemini to understand your voice. '
              'Get a free API key and paste it below.',
              style: TextStyle(
                  color: Colors.white.withAlpha(145),
                  fontSize: 15,
                  height: 1.65),
            ).animate().fadeIn(delay: 240.ms, duration: 400.ms),
            const SizedBox(height: 24),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'AIza...',
                hintStyle:
                    TextStyle(color: Colors.white.withAlpha(55)),
                labelText: 'Gemini API Key',
                labelStyle:
                    TextStyle(color: Colors.white.withAlpha(110)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: _kDeepGreen.withAlpha(180), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: _kLime, width: 1.5),
                ),
                filled: true,
                fillColor: _kDeepGreen.withAlpha(50),
                prefixIcon: Icon(Icons.key_outlined,
                    size: 18, color: Colors.white.withAlpha(90)),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: ctrl,
                  builder: (_, v, _) => v.text.isNotEmpty
                      ? const Icon(Icons.check_circle_rounded,
                          color: _kLime, size: 18)
                      : const SizedBox.shrink(),
                ),
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ).animate().fadeIn(delay: 330.ms, duration: 400.ms),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(
                    text: 'https://aistudio.google.com/app/apikey'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Link copied!'),
                    backgroundColor: _kLime,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.open_in_new_rounded,
                      size: 14, color: _kGold),
                  const SizedBox(width: 7),
                  Text(
                    'aistudio.google.com  ·  tap to copy',
                    style: TextStyle(
                        color: _kGold.withAlpha(220),
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
//  Bottom bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int page;
  final int total;
  final bool saving;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _BottomBar({
    required this.page,
    required this.total,
    required this.saving,
    required this.onNext,
    required this.onFinish,
  });

  bool get _isLast => page == total - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, _kBg.withAlpha(200), _kBg],
          stops: const [0, 0.25, 0.55],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot indicators — lime→gold active pill
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (i) {
                final active = i == page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [_kLime, _kGold])
                        : null,
                    color: active ? null : Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: _kLime.withAlpha(100),
                                blurRadius: 10),
                          ]
                        : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // CTA button — always lime→gold gradient
            SizedBox(
              width: double.infinity, height: 58,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kLime, _kGold],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: _kLime.withAlpha(70),
                        blurRadius: 24,
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
                                  color: _kBg))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isLast ? "Let's go  🚀" : 'Continue',
                                  style: const TextStyle(
                                      color: _kBg,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.1),
                                ),
                                if (!_isLast) ...[
                                  const SizedBox(width: 7),
                                  const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: _kBg, size: 18),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_isLast)
              TextButton(
                onPressed: saving ? null : onFinish,
                child: Text('Skip for now',
                    style: TextStyle(
                        color: Colors.white.withAlpha(70),
                        fontSize: 13)),
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
//  Brand chip
// ─────────────────────────────────────────────────────────────────────────────

class _BrandChip extends StatelessWidget {
  final String label;
  final bool   gold;
  const _BrandChip({required this.label, this.gold = false});

  @override
  Widget build(BuildContext context) {
    final color = gold ? _kGold : _kLime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(65), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}
