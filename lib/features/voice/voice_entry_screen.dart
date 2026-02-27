import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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

class _VoiceEntryScreenState extends ConsumerState<VoiceEntryScreen> {
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
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _isListening = false);
          // Delay slightly to let the final onResult fire before we read
          // _transcribed — this prevents a race where onStatus arrives first.
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && _transcribed.isNotEmpty && !_isParsing) _callGemini();
          });
        }
      },
      onError: (e) {
        // Treat timeout / no-match as a graceful stop, not a visible error.
        const silentErrors = {
          'error_speech_timeout',
          'error_no_match',
          'error_speech_recognizer_busy',
        };
        if (silentErrors.contains(e.errorMsg)) {
          if (mounted) setState(() => _isListening = false);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && _transcribed.isNotEmpty && !_isParsing) _callGemini();
          });
          return;
        }
        if (mounted) setState(() { _isListening = false; _error = e.errorMsg; });
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() { _transcribed = ''; _parsedList = []; _error = null; });
    await _speech.listen(
      onResult: (r) => setState(() => _transcribed = r.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
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
          _error = "Couldn't detect any expenses. Try speaking more clearly — e.g. \"spent 200 on food\"";
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$savedCount ${savedCount == 1 ? "entry" : "entries"} added'),
        backgroundColor: AppTheme.positive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt       = Theme.of(context).textTheme;
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final bgColor  = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F2);

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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _MicCard(
                    isListening: _isListening,
                    speechAvailable: _speechAvailable,
                    transcribed: _transcribed,
                    isParsing: _isParsing,
                    cs: cs,
                    tt: tt,
                    isDark: isDark,
                    onTap: _isListening ? _stopListening : _startListening,
                  ).animate().fadeIn(duration: 350.ms),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(error: _error!, cs: cs, tt: tt),
                  ],

                  if (_parsedList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Multi-entry header
                    if (_parsedList.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
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

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mic card ───────────────────────────────────────────────────────────────

class _MicCard extends StatelessWidget {
  final bool isListening;
  final bool speechAvailable;
  final String transcribed;
  final bool isParsing;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onTap;

  const _MicCard({
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161616) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline, width: 0.5),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: speechAvailable ? onTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isListening
                      ? cs.onSurface
                      : cs.onSurface.withAlpha(12),
                  shape: BoxShape.circle,
                  boxShadow: isListening
                      ? [BoxShadow(
                          color: cs.onSurface.withAlpha(60),
                          blurRadius: 24,
                          spreadRadius: 2)]
                      : [],
                ),
                child: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: isListening
                      ? (isDark ? Colors.black : Colors.white)
                      : cs.onSurface,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!speechAvailable)
              Text('Speech not available',
                  style: tt.bodySmall?.copyWith(color: cs.error))
            else if (isParsing)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onSurface)),
                const SizedBox(width: 10),
                Text('Processing your request...', style: tt.bodySmall),
              ])
            else if (isListening)
              Text('Listening — tap to stop', style: tt.bodySmall)
            else
              Text('Tap to speak your expense', style: tt.bodySmall),

            if (transcribed.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.onSurface.withAlpha(8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"$transcribed"',
                  style: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
}

// ── Confirm card ───────────────────────────────────────────────────────────

class _ConfirmCard extends StatelessWidget {
  final ParsedEntry parsed;
  final AppCurrency currency;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final ValueChanged<String> onCategoryChange;
  final ValueChanged<DateTime> onDateChange;
  final VoidCallback? onSave;  // null → no save button (shown externally)
  final VoidCallback onDiscard;

  const _ConfirmCard({
    required this.parsed,
    required this.currency,
    required this.cs,
    required this.tt,
    required this.isDark,
    required this.onCategoryChange,
    required this.onDateChange,
    this.onSave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColors[categoryIndex(parsed.category)];
    final emoji = categoryEmoji(parsed.category);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CONFIRM ENTRY', style: tt.labelLarge),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                  onPressed: onDiscard,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(emoji,
                    style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  formatAmount(parsed.amount, currency),
                  style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Text(
                    parsed.description,
                    style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: categories.contains(parsed.category)
                  ? parsed.category
                  : 'Other',
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text('${categoryEmoji(c)}  $c')))
                  .toList(),
              onChanged: (v) { if (v != null) onCategoryChange(v); },
            ),
            const SizedBox(height: 10),
            // Tappable date row
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsed.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) onDateChange(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: cs.onSurface.withAlpha(8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline, width: 0.8),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    parsed.date.toLocal().toString().split(' ')[0],
                    style: tt.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined,
                      size: 11, color: cs.onSurfaceVariant),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: onDiscard, child: const Text('Discard')),
              ),
              if (onSave != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                      onPressed: onSave, child: const Text('Save')),
                ),
              ],
            ]),
          ],
        ),
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
          color: cs.error.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withAlpha(50)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 16),
            const SizedBox(width: 8),
            Flexible(
                child: Text(error,
                    style: tt.bodySmall?.copyWith(color: cs.error))),
          ],
        ),
      );
}
