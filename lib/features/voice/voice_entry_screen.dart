import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/models/parsed_entry.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/gemini_service.dart';

class VoiceEntryScreen extends ConsumerStatefulWidget {
  const VoiceEntryScreen({super.key});

  @override
  ConsumerState<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends ConsumerState<VoiceEntryScreen>
    with WidgetsBindingObserver {
  final SpeechToText _speech = SpeechToText();
  bool _isListening      = false;
  bool _speechAvailable  = false;
  bool _isParsing        = false;
  String _transcribed    = '';
  List<ParsedEntry> _parsedList = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isListening) {
      // Stop listening when the app is backgrounded so the mic is released.
      _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } else if (state == AppLifecycleState.resumed) {
      // On iOS the speech recognizer is invalidated after backgrounding.
      // Re-initialize so the next tap works without a restart.
      _initSpeech();
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (s) {
        // 'doneNoResult' is iOS-specific: fires when the recognizer stops
        // with no speech detected (equivalent to Android's 'done').
        if (s == 'done' || s == 'notListening' || s == 'doneNoResult') {
          if (mounted) setState(() => _isListening = false);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _transcribed.isNotEmpty && !_isParsing &&
                !_speech.isListening) {
              _callGemini();
            }
          });
        }
      },
      onError: (e) {
        const silentErrors = {
          // Android
          'error_speech_timeout',
          'error_no_match',
          'error_speech_recognizer_busy',
          // iOS — these fire when the recognizer is briefly unavailable,
          // backgrounded, or interrupted; not meaningful to show to the user.
          'error_audio',
          'error_client',
          'error_recognition_blocked',
          'error_recognition_connection',
        };
        if (silentErrors.contains(e.errorMsg)) {
          if (mounted) setState(() => _isListening = false);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _transcribed.isNotEmpty && !_isParsing &&
                !_speech.isListening) {
              _callGemini();
            }
          });
          return;
        }
        if (mounted) setState(() { _isListening = false; _error = e.errorMsg; });
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Microphone access is required. Enable it in Settings.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }
    // If the engine is still active from a previous session, stop it first.
    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 150));
    }
    HapticFeedback.mediumImpact();
    // Set isListening BEFORE listen() so onStatus:'done' can't race ahead and
    // leave the UI stuck in a "listening" state after the engine has stopped.
    setState(() { _isListening = true; _transcribed = ''; _parsedList = []; _error = null; });
    await _speech.listen(
      onResult: (r) => setState(() => _transcribed = r.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    HapticFeedback.lightImpact();
    await _speech.stop();
    setState(() => _isListening = false);
    if (_transcribed.isNotEmpty && !_isParsing) _callGemini();
  }

  Future<void> _callGemini() async {
    setState(() => _isParsing = true);
    try {
      final results = await ref.read(geminiServiceProvider).parseExpenses(_transcribed);
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() {
          _error = "Couldn't detect any expenses. Try again — e.g. \"spent 200 on lunch\"";
          _isParsing = false;
        });
        return;
      }
      setState(() { _parsedList = results; _isParsing = false; });
    } on GeminiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isParsing = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isParsing = false; });
    }
  }

  Future<void> _saveAll() async {
    if (_parsedList.isEmpty) return;
    const uuid    = Uuid();
    final accountId = ref.read(selectedAccountProvider);
    for (final entry in _parsedList) {
      await ref.read(databaseProvider).insertTransaction(
        TransactionsCompanion.insert(
          uuid: uuid.v4(),
          amount: entry.amount,
          category: entry.category,
          description: entry.description,
          date: entry.date,
          accountId: Value(accountId),
          rawInput: Value(_transcribed),
        ),
      );
    }
    if (mounted) {
      final savedCount = _parsedList.length;
      setState(() { _parsedList = []; _transcribed = ''; });
      SystemSound.play(SystemSoundType.click);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$savedCount ${savedCount == 1 ? "entry" : "entries"} added'),
        backgroundColor: AppTheme.positive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _addManually(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ManualEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt       = Theme.of(context).textTheme;
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final bgColor  = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);

    // Auto-start recording when triggered by long-pressing the mic nav button.
    ref.listen<bool>(autoStartRecordingProvider, (_, shouldStart) {
      if (shouldStart) {
        ref.read(autoStartRecordingProvider.notifier).state = false;
        if (!_isListening && _speechAvailable) _startListening();
      }
    });

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            toolbarHeight: 64,
            backgroundColor: bgColor,
            title: Text('Add Entry', style: tt.headlineMedium),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  // ── Centre mic orb ──────────────────────────────────────
                  _MicOrb(
                    isListening: _isListening,
                    speechAvailable: _speechAvailable,
                    transcribed: _transcribed,
                    isParsing: _isParsing,
                    cs: cs,
                    tt: tt,
                    isDark: isDark,
                    onTap: _isListening ? _stopListening : _startListening,
                  ).animate().fadeIn(duration: 300.ms),

                  // ── Manual add link ────────────────────────────────────
                  TextButton.icon(
                    onPressed: () => _addManually(context),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('Add manually'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(error: _error!, cs: cs, tt: tt)
                        .animate().fadeIn(duration: 250.ms).slideY(begin: 0.1),
                  ],

                  if (_parsedList.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    // Multi-entry header
                    if (_parsedList.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Text(
                              '${_parsedList.length} ENTRIES FOUND',
                              style: tt.labelLarge?.copyWith(letterSpacing: 1.0),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setState(() {
                                _parsedList = [];
                                _transcribed = '';
                              }),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.negative),
                              child: const Text('Discard All'),
                            ),
                          ],
                        ),
                      ),

                    // One confirm card per entry
                    ...List.generate(_parsedList.length, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ConfirmCard(
                        parsed: _parsedList[i],
                        currency: currency,
                        cs: cs,
                        tt: tt,
                        isDark: isDark,
                        onAmountChange: (a) => setState(() =>
                            _parsedList[i] = _parsedList[i].copyWith(amount: a)),
                        onDescriptionChange: (d) => setState(() =>
                            _parsedList[i] = _parsedList[i].copyWith(description: d)),
                        onCategoryChange: (c) => setState(() =>
                            _parsedList[i] = _parsedList[i].copyWith(category: c)),
                        onDateChange: (d) => setState(() =>
                            _parsedList[i] = _parsedList[i].copyWith(date: d)),
                        onSave: _parsedList.length == 1 ? _saveAll : null,
                        onDiscard: () => setState(() => _parsedList.removeAt(i)),
                      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),
                    )),

                    // "Save All" button for multiple entries
                    if (_parsedList.length > 1)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveAll,
                          child: Text('Save ${_parsedList.length} Entries'),
                        ),
                      ),
                  ],

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mic orb — the core CTA of the voice screen ─────────────────────────────

class _MicOrb extends StatelessWidget {
  final bool isListening;
  final bool speechAvailable;
  final String transcribed;
  final bool isParsing;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onTap;

  const _MicOrb({
    required this.isListening,
    required this.speechAvailable,
    required this.transcribed,
    required this.isParsing,
    required this.cs,
    required this.tt,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),

        // ── Orb + pulse rings ──────────────────────────────────────────
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring 1 (shown while listening)
              if (isListening)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: cs.onSurface.withAlpha(40), width: 1.5),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15),
                        duration: 800.ms, curve: Curves.easeInOut),

              // Pulse ring 2 (offset phase)
              if (isListening)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: cs.onSurface.withAlpha(55), width: 1.5),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1),
                        duration: 700.ms,
                        delay: 150.ms,
                        curve: Curves.easeInOut),

              // Main orb button
              GestureDetector(
                onTap: speechAvailable ? onTap : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  width: isListening ? 108 : 96,
                  height: isListening ? 108 : 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isListening
                          ? isDark
                              ? [Colors.white, const Color(0xFFE0E0E0)]
                              : [const Color(0xFF0A0A0A), const Color(0xFF1A1A1A)]
                          : isDark
                              ? [const Color(0xFF1C1C1C), const Color(0xFF0F0F0F)]
                              : [const Color(0xFFF5F5F5), Colors.white],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.onSurface
                          .withAlpha(isListening ? 100 : 60),
                      width: isListening ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.onSurface
                            .withAlpha(isListening ? 110 : 45),
                        blurRadius: isListening ? 36 : 16,
                        spreadRadius: isListening ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    isParsing
                        ? Icons.auto_awesome_rounded
                        : isListening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                    color: isListening
                        ? (isDark ? Colors.black : Colors.white)
                        : cs.onSurface,
                    size: isListening ? 46 : 40,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Status text ────────────────────────────────────────────────
        if (!speechAvailable)
          _StatusChip(
            label: 'Speech not available',
            color: cs.error,
            icon: Icons.error_outline_rounded,
          )
        else if (isParsing)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.onSurface)),
            const SizedBox(width: 10),
            Text('Analysing...', style: tt.bodyMedium?.copyWith(
                color: cs.onSurface, fontWeight: FontWeight.w600)),
          ])
        else if (isListening)
          _StatusChip(
            label: 'Listening  •  tap to stop',
            color: AppTheme.positive,
            icon: Icons.fiber_manual_record_rounded,
          )
        else
          Text('Tap the mic and speak your expense',
              style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),

        // ── Transcribed text bubble ────────────────────────────────────
        if (transcribed.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: cs.onSurface.withAlpha(isDark ? 12 : 8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cs.onSurface.withAlpha(40), width: 1),
            ),
            child: Text(
              '"$transcribed"',
              style: tt.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cs.onSurface.withAlpha(200),
                  height: 1.55),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Small status chip ──────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(60), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Shared date formatter ────────────────────────────────────────────────

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// ── Confirm card ───────────────────────────────────────────────────────────

class _ConfirmCard extends StatefulWidget {
  final ParsedEntry parsed;
  final AppCurrency currency;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final ValueChanged<String> onCategoryChange;
  final ValueChanged<double> onAmountChange;
  final ValueChanged<String> onDescriptionChange;
  final ValueChanged<DateTime> onDateChange;
  final VoidCallback? onSave;
  final VoidCallback onDiscard;

  const _ConfirmCard({
    required this.parsed,
    required this.currency,
    required this.cs,
    required this.tt,
    required this.isDark,
    required this.onCategoryChange,
    required this.onAmountChange,
    required this.onDescriptionChange,
    required this.onDateChange,
    this.onSave,
    required this.onDiscard,
  });

  @override
  State<_ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends State<_ConfirmCard> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  bool _isExiting = false;

  Future<void> _animateAndCall(VoidCallback cb) async {
    setState(() => _isExiting = true);
    await Future.delayed(const Duration(milliseconds: 240));
    if (mounted) cb();
  }

  @override
  void initState() {
    super.initState();
    final a = widget.parsed.amount;
    _amountCtrl = TextEditingController(
      text: a % 1 == 0 ? a.toStringAsFixed(0) : a.toStringAsFixed(2),
    );
    _descCtrl = TextEditingController(text: widget.parsed.description);
  }

  @override
  void didUpdateWidget(_ConfirmCard old) {
    super.didUpdateWidget(old);
    // Only sync controller if parent pushed a new amount (e.g. re-parse)
    // and the field isn't currently focused.
    if (old.parsed.amount != widget.parsed.amount &&
        !_amountCtrl.selection.isValid) {
      final a = widget.parsed.amount;
      _amountCtrl.text =
          a % 1 == 0 ? a.toStringAsFixed(0) : a.toStringAsFixed(2);
    }
    if (old.parsed.description != widget.parsed.description &&
        !_descCtrl.selection.isValid) {
      _descCtrl.text = widget.parsed.description;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColors[categoryIndex(widget.parsed.category)];
    final emoji = categoryEmoji(widget.parsed.category);

    return AnimatedScale(
      scale: _isExiting ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInCubic,
      child: AnimatedOpacity(
        opacity: _isExiting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInCubic,
        child: Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: widget.isDark
                ? const Color(0xFF1E1E3C)
                : const Color(0xFFE5E4F0),
            width: 1),
        boxShadow: widget.isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with label + dismiss
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.positive.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.positive.withAlpha(70)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded,
                        color: AppTheme.positive, size: 12),
                    const SizedBox(width: 4),
                    Text('PARSED',
                        style: TextStyle(
                            color: AppTheme.positive,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ]),
                ),
                GestureDetector(
                  onTap: () => _animateAndCall(widget.onDiscard),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.cs.onSurface.withAlpha(8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: widget.cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Amount + description row
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withAlpha(50), width: 1),
                ),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Editable amount field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.currency.symbol,
                        style: widget.tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: widget.cs.onSurface.withAlpha(120)),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'))
                          ],
                          style: widget.tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) {
                            final d = double.tryParse(v);
                            if (d != null && d > 0) {
                              widget.onAmountChange(d);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _descCtrl,
                    style: widget.tt.bodySmall?.copyWith(
                        color: widget.cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Description',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    onChanged: widget.onDescriptionChange,
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 18),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: categories.contains(widget.parsed.category)
                  ? widget.parsed.category
                  : 'Other',
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text('${categoryEmoji(c)}  $c')))
                  .toList(),
              onChanged: (v) {
                if (v != null) widget.onCategoryChange(v);
              },
            ),
            const SizedBox(height: 10),

            // Date picker row
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.parsed.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) widget.onDateChange(
                    DateTime(picked.year, picked.month, picked.day, 12));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.cs.onSurface.withAlpha(7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.cs.outline, width: 1),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 14, color: widget.cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(widget.parsed.date),
                    style: widget.tt.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_rounded,
                      size: 12, color: widget.cs.onSurfaceVariant),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => _animateAndCall(widget.onDiscard),
                    child: const Text('Discard')),
              ),
              if (widget.onSave != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                      onPressed: () => _animateAndCall(widget.onSave!),
                      child: const Text('Save Entry')),
                ),
              ],
            ]),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

// ── Manual entry bottom-sheet ──────────────────────────────────────────────

class _ManualEntrySheet extends ConsumerStatefulWidget {
  const _ManualEntrySheet();

  @override
  ConsumerState<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<_ManualEntrySheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  String   _category = categories.first;
  DateTime _date     = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    // Capture navigation/messenger before any async gap so they remain valid
    // after the widget is popped off the tree.
    final messenger = ScaffoldMessenger.of(context);
    final nav       = Navigator.of(context);
    const uuid      = Uuid();
    final accountId = ref.read(selectedAccountProvider);
    await ref.read(databaseProvider).insertTransaction(
      TransactionsCompanion.insert(
        uuid: uuid.v4(),
        amount: amount,
        category: _category,
        description: _descCtrl.text.trim().isEmpty
            ? _category
            : _descCtrl.text.trim(),
        date: _date,
        accountId: Value(accountId),
      ),
    );
    nav.pop();
    SystemSound.play(SystemSoundType.click);
    messenger.showSnackBar(SnackBar(
      content: const Text('Entry added'),
      backgroundColor: AppTheme.positive,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final tt       = Theme.of(context).textTheme;
    final currency = ref.watch(currencyProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withAlpha(30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Add Entry',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${currency.symbol} ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration:
                const InputDecoration(labelText: 'Description (optional)'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: categories
                .map((c) => DropdownMenuItem(
                    value: c, child: Text('${categoryEmoji(c)}  $c')))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() =>
                  _date = DateTime(picked.year, picked.month, picked.day, 12));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withAlpha(7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline, width: 1),
              ),
              child: Row(children: [
                Icon(Icons.calendar_month_rounded,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(_formatDate(_date),
                    style:
                        tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                const Spacer(),
                Icon(Icons.edit_rounded,
                    size: 12, color: cs.onSurfaceVariant),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Save Entry'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final ColorScheme cs;
  final TextTheme tt;
  const _ErrorBanner(
      {required this.error, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.error.withAlpha(14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.error.withAlpha(50)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
            const SizedBox(width: 10),
            Flexible(
                child: Text(error,
                    style: tt.bodySmall?.copyWith(
                        color: cs.error, height: 1.5))),
          ],
        ),
      );
}
