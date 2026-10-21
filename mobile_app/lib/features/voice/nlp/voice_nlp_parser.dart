import '../../../models/category.dart';
import '../../../models/person.dart';
import '../../../models/transaction_type.dart';
import 'amount_parser.dart';
import 'date_phrase_parser.dart';
import 'nlp_vocabulary.dart';
import 'voice_command.dart';

class VoiceNlpParser {
  const VoiceNlpParser();

  // A person-name token allows letters, dots and apostrophes, and up to three
  // words. Patterns are raw double-quoted strings so the apostrophe stays literal.
  static const String _name = "([a-z][a-z.'-]*(?:\\s+[a-z][a-z.'-]*){0,2})";
  static const String _nameAfterLending =
      "\\b(?:lent|loaned)\\s+(?:to\\s+)?$_name";
  static const String _nameAfterLoanTo =
      "\\bgave\\s+(?:a\\s+)?loan\\s+to\\s+$_name";
  static const String _nameAfterLoanLabel = "\\bloan\\s+to\\s+$_name";
  static const String _nameAfterTo = "\\bto\\s+$_name";
  static const String _nameAfterFrom = "\\bfrom\\s+$_name";
  static const String _nameAfterBorrowedFrom =
      "\\b(?:borrowed|took\\s+(?:a\\s+)?loan)\\b[^.]{0,50}?\\bfrom\\s+$_name";
  static const String _nameAfterReturnVerb =
      "\\b(?:returned|repaid|settled)\\s+(?:me\\s+)?$_name";
  static const String _nameBeforeBack =
      "\\b(?:paid|gave)\\s+$_name\\s+back";
  static const String _repaymentSubject =
      "(?:^|\\b)$_name\\s+(?:has\\s+|had\\s+)?(?:returned|repaid|settled|"
      "paid\\s+me(?:\\s+back)?|gave\\s+me(?:\\s+back)?)";

  ParsedVoiceCommand parse(
    String rawText, {
    List<Person> knownPersons = const [],
    List<Category> knownCategories = const [],
    DateTime? now,
  }) {
    final text = rawText.trim().replaceAll(RegExp(r'\s+'), ' ');
    final today = now ?? DateTime.now();

    if (text.isEmpty) {
      return ParsedVoiceCommand(
        originalText: rawText,
        intent: VoiceIntent.unknown,
        amount: null,
        currency: 'INR',
        transactionDate: DateTime(today.year, today.month, today.day),
        confidence: 0,
        missingFields: const [VoiceField.intent, VoiceField.amount],
        warnings: const ['There is no speech to interpret.'],
      );
    }

    final timeMatch = DatePhraseParser.parseTime(text);
    final dateMatch = DatePhraseParser.parse(text, now: today);
    final interest = _parseInterest(text);

    final masked = _maskAmountNoise(
      text,
      datePhrase: dateMatch.raw,
      timePhrase: timeMatch?.raw,
      interestPhrase: interest?.raw,
    );

    final amountMatch = AmountParser.parse(masked);
    final intent = _detectIntent(text, knownPersons: knownPersons);
    final personName = _extractPerson(
      text,
      intent: intent,
      knownPersons: knownPersons,
    );
    final repaymentDirection = intent == VoiceIntent.createRepayment
        ? _detectRepaymentDirection(text, personName)
        : null;
    final categoryName = _detectCategory(
      text,
      intent: intent,
      knownCategories: knownCategories,
    );

    final description = _buildDescription(
      text: text,
      datePhrase: dateMatch.raw,
      timePhrase: timeMatch?.raw,
      amountPhrase: amountMatch?.raw,
      interestPhrase: interest?.raw,
      personName: personName,
      intent: intent,
    );

    final missingFields = <VoiceField>[];
    if (intent == VoiceIntent.unknown) missingFields.add(VoiceField.intent);
    if (intent.requiresAmount && amountMatch == null) {
      missingFields.add(VoiceField.amount);
    }
    if (intent.requiresPerson && personName == null) {
      missingFields.add(VoiceField.person);
    }
    if (intent == VoiceIntent.createRepayment &&
        repaymentDirection == null) {
      missingFields.add(VoiceField.repaymentDirection);
    }

    final warnings = <String>[];
    if (intent == VoiceIntent.unknown) {
      warnings.add(
        'I could not identify the action. Start with spent, received, lent, '
        'borrowed, returned or saved.',
      );
    }
    if (intent.requiresAmount && amountMatch == null) {
      warnings.add('I could not find an amount in your sentence.');
    }
    if (!dateMatch.explicit && !intent.isQuery) {
      warnings.add('No date was heard, so today is selected.');
    }
    if (intent.requiresPerson && personName == null) {
      warnings.add('This entry needs a person. Add a name in review.');
    }
    if (intent == VoiceIntent.createRepayment &&
        repaymentDirection == null) {
      warnings.add('I could not tell whether money was paid or received.');
    }
    if (_categoryIsRelevant(intent) && categoryName == null) {
      warnings.add('No category was recognised. Choose one in review.');
    }
    if (amountMatch != null && amountMatch.amount > 1000000000000) {
      warnings.add('That amount looks unusually large. Please review it.');
    }

    final confidence = _calculateConfidence(
      intent: intent,
      amount: amountMatch,
      explicitDate: dateMatch.explicit,
      categoryFound: categoryName != null,
      personFound: personName != null,
      directionFound: repaymentDirection != null,
      interestFound: interest != null,
      warningCount: warnings.length,
      missingCount: missingFields.length,
    );

    final interestRelevant = intent == VoiceIntent.createLending ||
        intent == VoiceIntent.createBorrowing;

    return ParsedVoiceCommand(
      originalText: text,
      intent: intent,
      amount: amountMatch?.amount,
      currency: amountMatch?.currency ?? 'INR',
      transactionDate: DateTime(
        dateMatch.date.year,
        dateMatch.date.month,
        dateMatch.date.day,
      ),
      confidence: confidence,
      missingFields: missingFields,
      warnings: warnings,
      personName: personName,
      categoryName: categoryName,
      description: description,
      transactionTime: timeMatch?.time,
      interestRate: interestRelevant ? interest?.rate : null,
      interestType: interestRelevant ? interest?.type : null,
      repaymentDirection: repaymentDirection,
      explicitDate: dateMatch.explicit,
      explicitCurrency: amountMatch?.currencyExplicit ?? false,
    );
  }

  VoiceIntent _detectIntent(
    String text, {
    required List<Person> knownPersons,
  }) {
    final lower = text.toLowerCase();

    // Read-only questions are recognised first. Their wording often contains
    // create verbs ("how much did I spend"), so they must win before those.
    if (RegExp(
      r"\b(?:who\s+owes\s+me|what\s+do\s+i\s+owe|"
      r"(?:my|outstanding|pending|active|total)\s+loans?|"
      r"loan\s+balance|how\s+much\s+(?:do\s+i\s+owe|is\s+(?:my\s+)?loan))\b",
    ).hasMatch(lower)) {
      return VoiceIntent.queryLoans;
    }

    if (RegExp(
      r"\b(?:show|list|display)\b[^.]{0,30}\btransactions?\b|"
      r"\b(?:my|recent|last|latest|all)\b[^.]{0,15}\btransactions?\b",
    ).hasMatch(lower)) {
      return VoiceIntent.queryTransactions;
    }

    if (RegExp(
      r"\b(?:how\s+much\s+(?:did\s+i|have\s+i|i|do\s+i)\s+spen[dt]|"
      r"how\s+much\s+(?:money\s+)?(?:was\s+)?spent|"
      r"total\s+(?:expenses?|spending)|my\s+(?:expenses?|spending)|"
      r"spending\s+(?:this|last)\s+(?:month|week))\b",
    ).hasMatch(lower)) {
      return VoiceIntent.queryExpenses;
    }

    if (RegExp(
      r"\b(?:how\s+much\s+(?:did\s+i|have\s+i|i|do\s+i)\s+earn(?:ed)?|"
      r"total\s+income|my\s+(?:income|earnings)|"
      r"income\s+(?:this|last)\s+(?:month|week))\b",
    ).hasMatch(lower)) {
      return VoiceIntent.queryIncome;
    }

    if (RegExp(
      r"\b(?:what(?:'s| is)?\s+(?:my\s+)?(?:current\s+)?balance|"
      r"how\s+much\s+(?:money\s+)?(?:do\s+i|i)\s+have|my\s+balance|"
      r"account\s+balance|balance\s+enquiry)\b",
    ).hasMatch(lower)) {
      return VoiceIntent.queryBalance;
    }

    final hasRepaymentVerb = RegExp(
      r'\b(?:returned|repaid|paid\s+back|paid\b[^.]{0,30}\bback|'
      r'gave\s+back|gave\b[^.]{0,20}\bback)\b',
    ).hasMatch(lower);
    if (hasRepaymentVerb) return VoiceIntent.createRepayment;

    final receivedFrom = RegExp(r'\breceived\b[^.]{0,40}\bfrom\b').hasMatch(lower);
    final incomeSpecific = RegExp(
      r'\b(?:salary|income|freelance|client|business|bonus|commission|'
      r'dividend|refund|cashback)\b',
    ).hasMatch(lower);
    if (receivedFrom && !incomeSpecific) {
      return VoiceIntent.createRepayment;
    }

    if (RegExp(
      r'\b(?:borrowed|borrow|took\s+(?:a\s+)?loan|loan\s+from)\b',
    ).hasMatch(lower)) {
      return VoiceIntent.createBorrowing;
    }

    if (RegExp(
      r'\b(?:lent|loaned|gave\s+(?:a\s+)?loan|loan\s+to)\b',
    ).hasMatch(lower)) {
      return VoiceIntent.createLending;
    }

    final hasKnownPerson = knownPersons.any(
      (person) => person.name.trim().isNotEmpty &&
          RegExp(
            r'\b' + RegExp.escape(person.name.toLowerCase()) + r'\b',
          ).hasMatch(lower),
    );
    if (hasKnownPerson &&
        RegExp(r'\b(?:settled|cleared)\b').hasMatch(lower) &&
        !RegExp(r'\b(?:bill|invoice|fee|fees)\b').hasMatch(lower)) {
      return VoiceIntent.createRepayment;
    }

    if (RegExp(
      r'\b(?:saved|save|savings?|put\s+aside|set\s+aside)\b',
    ).hasMatch(lower)) {
      return VoiceIntent.createSavings;
    }

    if (RegExp(
      r'\b(?:received|earned|salary|income|credited|got\s+paid|bonus|'
      r'freelance|refund|cashback|dividend)\b',
    ).hasMatch(lower)) {
      return VoiceIntent.createIncome;
    }

    if (RegExp(
      r'\b(?:spent|spend|paid|bought|buy|purchase|purchased|expense|bill)\b',
    ).hasMatch(lower)) {
      return VoiceIntent.createExpense;
    }

    return VoiceIntent.unknown;
  }

  String? _extractPerson(
    String text, {
    required VoiceIntent intent,
    required List<Person> knownPersons,
  }) {
    final lower = text.toLowerCase();

    final sortedKnown = knownPersons
        .where((person) => person.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final person in sortedKnown) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(person.name.toLowerCase().trim()) + r'\b',
      );
      if (pattern.hasMatch(lower)) return person.name;
    }

    if (intent == VoiceIntent.createLending) {
      final direct = _capture(text, _nameAfterLending);
      final toPerson = _capture(text, _nameAfterLoanTo);
      final loanTo = _capture(text, _nameAfterLoanLabel);
      final trailingTo = _capture(text, _nameAfterTo);
      return direct ?? toPerson ?? loanTo ?? trailingTo;
    }

    if (intent == VoiceIntent.createBorrowing) {
      final borrowedFrom = _capture(text, _nameAfterBorrowedFrom);
      final from = _capture(text, _nameAfterFrom);
      return borrowedFrom ?? from;
    }

    if (intent == VoiceIntent.createRepayment) {
      final subject = _capture(text, _repaymentSubject);
      final afterVerb = _capture(text, _nameAfterReturnVerb);
      final paidBack = _capture(text, _nameBeforeBack);
      final toPerson = _capture(text, _nameAfterTo);
      final fromPerson = _capture(text, _nameAfterFrom);
      return subject ?? paidBack ?? afterVerb ?? toPerson ?? fromPerson;
    }

    return null;
  }

  String? _capture(String text, String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
    if (match == null || match.groupCount < 1) return null;
    final candidate = _cleanName(match.group(1));
    return candidate;
  }

  String? _cleanName(String? raw) {
    if (raw == null) return null;
    final tokens = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final accepted = <String>[];

    for (final token in tokens) {
      if (accepted.length >= 3) break;
      final cleaned = token.replaceAll(RegExp(r'[.,;:!?]+$'), '');
      final lower = cleaned.toLowerCase();
      if (cleaned.isEmpty ||
          cleaned.length > 30 ||
          RegExp(r'\d').hasMatch(cleaned) ||
          NlpVocabulary.nameStopWords.contains(lower) ||
          NlpVocabulary.currencyWords.containsKey(lower) ||
          NlpVocabulary.monthNumber(lower) != null ||
          NlpVocabulary.numberWords.containsKey(lower)) {
        break;
      }
      accepted.add(cleaned);
    }

    if (accepted.isEmpty) return null;
    if (accepted.length == 1 && accepted.first.length < 2) return null;
    return accepted.map(_titleWord).join(' ');
  }

  String _titleWord(String word) {
    if (word.isEmpty) return word;
    if (word.length <= 3 && word == word.toUpperCase()) return word;
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }

  RepaymentDirection? _detectRepaymentDirection(
    String text,
    String? personName,
  ) {
    final lower = text.toLowerCase();
    final person = personName?.toLowerCase();

    final personIsSubject = person != null &&
        RegExp(
          "\\b${RegExp.escape(person)}\\s+(?:has\\s+|had\\s+)?"
          r'(?:returned|repaid|settled|paid\s+me|gave\s+me)',
        ).hasMatch(lower);
    final paidMeBack = RegExp(
      r'\b(?:paid|gave|returned)\s+me(?:\s+back)?\b',
    ).hasMatch(lower);
    final fromPerson = person != null &&
        RegExp(r'\bfrom\s+' + RegExp.escape(person) + r'\b').hasMatch(lower);

    final iSubject = RegExp(
      r'\b(?:i|we)\s+(?:have\s+|had\s+)?'
      r'(?:returned|repaid|settled|paid\b[^.]{0,30}\bback|gave\b[^.]{0,20}\bback)',
    ).hasMatch(lower);
    final paidToPerson = person != null &&
        RegExp(
          "\\b(?:returned|repaid|paid|gave)\\b[^.]{0,40}\\bto\\s+"
          "${RegExp.escape(person)}\\b",
        ).hasMatch(lower);
    final paidPersonBack = person != null &&
        RegExp(
          "\\b(?:paid|gave)\\s+${RegExp.escape(person)}\\s+back\\b",
        ).hasMatch(lower);

    if (paidMeBack || personIsSubject || fromPerson) {
      return RepaymentDirection.received;
    }
    if (iSubject || paidToPerson || paidPersonBack) {
      return RepaymentDirection.paid;
    }
    return null;
  }

  String? _detectCategory(
    String text, {
    required VoiceIntent intent,
    required List<Category> knownCategories,
  }) {
    if (intent.isQuery ||
        intent == VoiceIntent.createRepayment ||
        intent == VoiceIntent.createLending ||
        intent == VoiceIntent.createBorrowing) {
      return null;
    }

    final lower = text.toLowerCase();
    final candidates = <String, String>{
      for (final entry in NlpVocabulary.categoryKeywords.entries)
        entry.key: entry.value,
      for (final category in knownCategories)
        if (category.name.trim().isNotEmpty)
          category.name.toLowerCase(): category.name,
    };

    final keys = candidates.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in keys) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(key).replaceAll(r'\ ', r'\s+') + r'\b',
      );
      if (pattern.hasMatch(lower)) return candidates[key];
    }
    return null;
  }

  bool _categoryIsRelevant(VoiceIntent intent) =>
      intent == VoiceIntent.createExpense ||
      intent == VoiceIntent.createIncome ||
      intent == VoiceIntent.createSavings;

  InterestMatch? _parseInterest(String text) {
    final percent = RegExp(
      r'(\d{1,3}(?:\.\d+)?)\s*(?:%|percent(?:age)?)',
      caseSensitive: false,
    ).firstMatch(text);

    RegExpMatch? match = percent;
    if (percent == null) {
      match = RegExp(
        r'\binterest(?:\s+(?:rate|of|at))?\s*(?:of\s+|at\s+)?'
        r'(\d{1,3}(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(text);
    }
    if (match == null) return null;

    final rate = double.tryParse(match.group(1)!);
    if (rate == null || rate < 0 || rate > 100) return null;

    final lower = text.toLowerCase();
    final type = lower.contains('compound')
        ? InterestType.compound
        : lower.contains('flat')
            ? InterestType.flat
            : InterestType.simple;

    return InterestMatch(
      rate: rate,
      type: type,
      raw: match.group(0)!,
    );
  }

  String _maskAmountNoise(
    String text, {
    required String datePhrase,
    String? timePhrase,
    String? interestPhrase,
  }) {
    var masked = text;
    masked = _maskPhrase(masked, datePhrase);
    if (timePhrase != null) masked = _maskPhrase(masked, timePhrase);
    if (interestPhrase != null) masked = _maskPhrase(masked, interestPhrase);
    masked = masked.replaceAllMapped(
      RegExp(r'\d{1,3}(?:\.\d+)?\s*(?:%|percent(?:age)?)', caseSensitive: false),
      (match) => ' ' * match.group(0)!.length,
    );
    return masked;
  }

  String _maskPhrase(String text, String phrase) {
    if (phrase.trim().isEmpty) return text;
    final pattern = RegExp(RegExp.escape(phrase), caseSensitive: false);
    return text.replaceAllMapped(pattern, (match) => ' ' * match.group(0)!.length);
  }

  String _buildDescription({
    required String text,
    required String datePhrase,
    String? timePhrase,
    required String? amountPhrase,
    String? interestPhrase,
    required String? personName,
    required VoiceIntent intent,
  }) {
    var result = text;
    for (final phrase in [
      datePhrase,
      timePhrase,
      amountPhrase,
      interestPhrase,
      personName,
    ]) {
      if (phrase == null || phrase.trim().isEmpty) continue;
      result = result.replaceAll(
        RegExp(RegExp.escape(phrase), caseSensitive: false),
        ' ',
      );
    }

    final wordsToRemove = <String>[
      r'\b(?:i|we|my|me|our)\b',
      r'\b(?:have|has|had|was|were|just|also)\b',
      r'\b(?:spent|spend|paid|pay|bought|buy|purchased|purchase)\b',
      r'\b(?:received|receive|earned|earn|got|get|credited)\b',
      r'\b(?:saved|save|put|set|aside)\b',
      r'\b(?:lent|lend|loaned|loan|borrowed|borrow|took|taken)\b',
      r'\b(?:returned|return|repaid|repay|settled|settle|gave|given|back)\b',
      r'\b(?:of|on|for|to|from|about|at|in|the|a|an|and|with)\b',
      r'\b(?:rupees?|rs\.?|inr|dollars?|usd|euros?|eur|pounds?|gbp)\b',
    ];
    for (final pattern in wordsToRemove) {
      result = result.replaceAll(RegExp(pattern, caseSensitive: false), ' ');
    }

    result = result
        .replaceAll(RegExp(r'[^\w\s&%.-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    result = result.replaceAll(RegExp(r'^[\s.,;:!?-]+'), '');
    result = result.replaceAll(RegExp(r'[\s.,;:!?-]+$'), '');

    if (result.length > 160) {
      result = '${result.substring(0, 157).trimRight()}...';
    }
    if (result.isEmpty) return '';
    return '${result[0].toUpperCase()}${result.substring(1)}';
  }

  double _calculateConfidence({
    required VoiceIntent intent,
    required AmountMatch? amount,
    required bool explicitDate,
    required bool categoryFound,
    required bool personFound,
    required bool directionFound,
    required bool interestFound,
    required int warningCount,
    required int missingCount,
  }) {
    if (intent == VoiceIntent.unknown) return 0;

    if (intent.isQuery) {
      var score = 0.86;
      if (explicitDate) score += 0.05;
      score -= warningCount * 0.05;
      return score.clamp(0.0, 0.99);
    }

    var score = 0.4;
    if (amount != null) {
      score += 0.3;
      if (amount.currencyExplicit) score += 0.05;
    }
    score += explicitDate ? 0.1 : 0.03;
    if (categoryFound && _categoryIsRelevant(intent)) score += 0.08;
    if (personFound && intent.requiresPerson) score += 0.12;
    if (directionFound) score += 0.05;
    if (interestFound) score += 0.02;
    score -= warningCount * 0.025;
    score -= missingCount * 0.15;
    return score.clamp(0.0, 0.99);
  }
}

class InterestMatch {
  const InterestMatch({
    required this.rate,
    required this.type,
    required this.raw,
  });

  final double rate;
  final InterestType type;
  final String raw;
}
