import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../database/app_database.dart';
import '../services/gemini_service.dart';

// ── SharedPreferences ──────────────────────────────────────────────────────

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

// ── Database ───────────────────────────────────────────────────────────────

/// Singleton AppDatabase provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── Gemini ─────────────────────────────────────────────────────────────────

/// Singleton GeminiService provider.
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService.instance;
});

// ── Theme mode ─────────────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark; // default until prefs load

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(AppConstants.prefKeyThemeMode);
    state = stored == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefKeyThemeMode,
      next == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ── Currency ───────────────────────────────────────────────────────────────

class CurrencyNotifier extends Notifier<AppCurrency> {
  @override
  AppCurrency build() => supportedCurrencies.first; // USD default

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code =
        prefs.getString(AppConstants.prefKeyCurrency) ?? 'USD';
    state = currencyByCode(code);
  }

  Future<void> setCurrency(AppCurrency currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyCurrency, currency.code);
  }
}

final currencyProvider =
    NotifierProvider<CurrencyNotifier, AppCurrency>(CurrencyNotifier.new);

// ── Current month ──────────────────────────────────────────────────────────

/// The currently viewed month in YYYY-MM format.
final selectedMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

/// Set to true to auto-start voice recording (e.g. from long-press mic).
/// VoiceEntryScreen resets this after consuming it.
final autoStartRecordingProvider = StateProvider<bool>((ref) => false);

// ── Selected Account ────────────────────────────────────────

class SelectedAccountNotifier extends Notifier<int> {
  @override
  int build() => 1; // default account id

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(AppConstants.prefKeySelectedAccount) ?? 1;
  }

  Future<void> switchAccount(int accountId) async {
    state = accountId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefKeySelectedAccount, accountId);
  }
}

final selectedAccountProvider =
    NotifierProvider<SelectedAccountNotifier, int>(SelectedAccountNotifier.new);

// ── Accounts ───────────────────────────────────────────────────

final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(databaseProvider).watchAccounts();
});
// ── Transactions ───────────────────────────────────────────────────────────

/// Stream of transactions for the selected month and account.
final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db        = ref.watch(databaseProvider);
  final month     = ref.watch(selectedMonthProvider);
  final accountId = ref.watch(selectedAccountProvider);
  return db.watchTransactionsForMonth(month, accountId);
});

/// Spend-per-category map — **expense transactions only** — for budget tracking.
/// Investment and recurring transactions are excluded so they don't eat into
/// the user's discretionary category budgets.
final spendPerCategoryProvider = Provider<Map<String, double>>((ref) {
  final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
  final map = <String, double>{};
  for (final t in txns.where((t) => t.txnType == 'expense')) {
    map[t.category] = (map[t.category] ?? 0.0) + t.amount;
  }
  return map;
});

/// Total money spent out of the account for the selected month —
/// **expense + recurring only** (investment/SIP contributions excluded because
/// they are savings transfers, not actual spending).
final totalMonthlyOutflowProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
  return txns
      .where((t) => t.txnType != 'investment')
      .fold(0.0, (sum, t) => sum + t.amount);
});

// ── Budget Allocations ─────────────────────────────────────────────────────

/// Stream of budget allocations for the selected month and account.
final budgetAllocationsProvider =
    StreamProvider<List<BudgetAllocation>>((ref) {
  final db        = ref.watch(databaseProvider);
  final month     = ref.watch(selectedMonthProvider);
  final accountId = ref.watch(selectedAccountProvider);
  return db.watchAllocationsForMonth(month, accountId);
});

// ── Goals ──────────────────────────────────────────────────────────────────

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final accountId = ref.watch(selectedAccountProvider);
  return ref.watch(databaseProvider).watchGoals(accountId);
});

// ── Budget Cap ─────────────────────────────────────────────────────────────

/// Maps '${month}_$accountId' → cap amount (null = not set).
class BudgetCapNotifier extends Notifier<Map<String, double?>> {
  @override
  Map<String, double?> build() => {};

  static String _k(String month, int accountId) =>
      'budget_cap_${month}_$accountId';

  Future<double?> load(String month, int accountId) async {
    final key = _k(month, accountId);
    if (state.containsKey(key)) return state[key];
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getDouble(key);
    state = {...state, key: val};
    return val;
  }

  Future<void> set(double? cap, String month, int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _k(month, accountId);
    if (cap == null) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, cap);
    }
    state = {...state, key: cap};
  }
}

final budgetCapProvider =
    NotifierProvider<BudgetCapNotifier, Map<String, double?>>(
        BudgetCapNotifier.new);

// ── Recurring Payments ─────────────────────────────────────────────────────

final recurringPaymentsProvider = StreamProvider<List<RecurringPayment>>((ref) {
  final accountId = ref.watch(selectedAccountProvider);
  return ref.watch(databaseProvider).watchRecurringPayments(accountId);
});

// ── Daily spend ────────────────────────────────────────────────────────────

/// Stream of {day → amount} for the currently selected month and account.
final dailySpendProvider = StreamProvider<Map<int, double>>((ref) {
  final db        = ref.watch(databaseProvider);
  final month     = ref.watch(selectedMonthProvider);
  final accountId = ref.watch(selectedAccountProvider);
  return db.watchDailySpendForMonth(month, accountId);
});

// ── API Key ────────────────────────────────────────────────────────────────

/// Gemini API key (in-memory + shared prefs via main.dart init).
final apiKeyProvider = StateProvider<String?>((ref) => null);

// ── User Profile ──────────────────────────────────────────────────────────

typedef UserProfile = ({String name, String avatar});

class UserProfileNotifier extends Notifier<UserProfile> {
  static const _keyName   = 'user_profile_name';
  static const _keyAvatar = 'user_profile_avatar';

  @override
  UserProfile build() => (name: 'You', avatar: '__logo__');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (
      name:   prefs.getString(_keyName)   ?? 'You',
      avatar: prefs.getString(_keyAvatar) ?? '__logo__',
    );
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    state = (name: name, avatar: state.avatar);
  }

  Future<void> setAvatar(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatar, emoji);
    state = (name: state.name, avatar: emoji);
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfile>(UserProfileNotifier.new);

// ── Monthly Income ────────────────────────────────────────────────────────

/// Persists monthly income per account in SharedPreferences.
/// Key format: `monthly_income_<accountId>`.
class MonthlyIncomeNotifier extends Notifier<Map<int, double>> {
  @override
  Map<int, double> build() => {};

  static String _k(int accountId) => 'monthly_income_$accountId';

  Future<double> load(int accountId) async {
    if (state.containsKey(accountId)) return state[accountId]!;
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getDouble(_k(accountId)) ?? 0.0;
    state = {...state, accountId: val};
    return val;
  }

  Future<void> set(int accountId, double income) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_k(accountId), income);
    state = {...state, accountId: income};
  }

  double get(int accountId) => state[accountId] ?? 0.0;
}

final monthlyIncomeProvider =
    NotifierProvider<MonthlyIncomeNotifier, Map<int, double>>(
        MonthlyIncomeNotifier.new);

// ── Onboarding ────────────────────────────────────────────────────────────

/// null = loading, false = show onboarding, true = already done
final onboardingDoneProvider = StateProvider<bool?>((ref) => null);

// ── Goal completion celebration ───────────────────────────────────────────

/// Holds a list of goals that were just completed (via SIP or manual
/// contribution) and are waiting for their celebration UI to fire.
/// Consumers clear this list after showing the dialog.
typedef GoalCompletion = ({String name, String emoji});
final pendingGoalCelebrationProvider =
    StateProvider<List<GoalCompletion>>((ref) => []);
