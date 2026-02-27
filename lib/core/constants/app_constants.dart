/// App-wide constants for BugMe.
library;

class AppConstants {
  AppConstants._();

  // SharedPreferences keys
  static const String prefKeyApiKey         = 'gemini_api_key';
  static const String prefKeyThemeMode      = 'theme_mode';
  static const String prefKeyCurrency       = 'currency_code';
  static const String prefKeySelectedAccount = 'selected_account_id';

  static String geminiPrompt(String input) => '''
You are a personal finance assistant. Parse the following expense entry and return ONLY valid JSON (no markdown, no extra text).

Input: "$input"

Return exactly this JSON structure:
{
  "amount": <positive number, extract numeric value only>,
  "category": <string, one of: ${categories.join(', ')}>,
  "description": <the merchant, restaurant, shop or item name only — e.g. "Starbucks", "Zomato", "Netflix", "Uber", "Amazon" — max 30 chars, NO generic words like "expense" or "purchase">,
  "date": <ISO 8601 date string, e.g. "2026-02-27">
}

Rules:
- amount is always a positive number
- Use today's date (${DateTime.now().toIso8601String().split('T')[0]}) if no date is mentioned
- Pick the closest matching category from the list
- description must be the specific place/item name, never generic
''';

  /// Parse multiple expenses from a single voice/text input.
  static String geminiMultiPrompt(String input) => '''
You are a personal finance assistant. Parse ALL expenses from the following input and return ONLY a valid JSON array (no markdown, no extra text).

Input: "$input"

Return a JSON array — even if there is only one expense:
[
  {
    "amount": <positive number>,
    "category": <string, one of: ${categories.join(', ')}>,
    "description": <merchant/item name, max 30 chars, specific — e.g. "Pizza Hut", "Uber", "Amazon">,
    "date": <ISO 8601 date, e.g. "2026-02-27">
  }
]

Rules:
- Extract EVERY expense mentioned, even if multiple in one sentence
- amount is always a positive number
- Use today's date (${DateTime.now().toIso8601String().split('T')[0]}) if no date is mentioned
- description must be a specific name, never generic like "expense" or "purchase"
''';
}

/// Expense categories.
const List<String> categories = [
  'Groceries',
  'Restaurants',
  'Coffee & Drinks',
  'Transport',
  'Entertainment',
  'Shopping',
  'Travel',
  'Health & Fitness',
  'Utilities & Bills',
  'Subscriptions',
  'Education',
  'Personal Care',
  'Rent & Housing',
  'Investments',
  'Other',
];

/// Emoji for each category (same order as [categories]).
const List<String> categoryEmojis = [
  '🛒', // Groceries
  '🍽️', // Restaurants
  '☕', // Coffee & Drinks
  '🚗', // Transport
  '🎬', // Entertainment
  '🛍️', // Shopping
  '✈️', // Travel
  '💪', // Health & Fitness
  '⚡', // Utilities & Bills
  '📺', // Subscriptions
  '📚', // Education
  '💅', // Personal Care
  '🏠', // Rent & Housing
  '📈', // Investments
  '💰', // Other
];

/// Returns the index of [category] in [categories], or last index if not found.
int categoryIndex(String category) {
  final idx = categories.indexOf(category);
  return idx < 0 ? categories.length - 1 : idx;
}

/// Returns the emoji for a category.
String categoryEmoji(String category) =>
    categoryEmojis[categoryIndex(category)];

// ── Currency ───────────────────────────────────────────────────────────────

class AppCurrency {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
  });
}

const List<AppCurrency> supportedCurrencies = [
  AppCurrency(code: 'INR', symbol: '₹',  name: 'Indian Rupee',  decimalDigits: 0),
  AppCurrency(code: 'JPY', symbol: '¥',  name: 'Japanese Yen',  decimalDigits: 0),
];

AppCurrency currencyByCode(String code) => supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first,
    );

String formatAmount(double amount, AppCurrency currency) {
  final abs = amount.abs();
  final String digits;
  if (currency.decimalDigits == 0) {
    digits = abs.toStringAsFixed(0);
  } else {
    digits = abs.toStringAsFixed(currency.decimalDigits);
    // Add thousands separator
  }
  // Insert thousands separators
  final parts = digits.split('.');
  final intPart = parts[0];
  final decPart = parts.length > 1 ? '.${parts[1]}' : '';
  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intPart[i]);
  }
  return '${currency.symbol}$buffer$decPart';
}
