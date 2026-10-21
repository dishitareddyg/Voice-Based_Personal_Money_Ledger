import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/inr_formatter.dart';
import '../../../core/utils/request_id.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/info_banner.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/transaction_visuals.dart';
import '../../../models/category.dart';
import '../../../models/person.dart';
import '../../../models/transaction_draft.dart';
import '../../../models/transaction_type.dart';
import '../../../providers/infrastructure_providers.dart';
import '../../../providers/ledger_providers.dart';
import '../../../router/routes.dart';
import '../nlp/voice_command.dart';
import '../nlp/voice_entry_controller.dart';
import '../nlp/voice_query_router.dart';

const _supportedCurrencies = <String>[
  'INR',
  'USD',
  'EUR',
  'GBP',
  'AED',
  'SGD',
  'AUD',
  'CAD',
  'JPY',
];

enum _SubmitPhase { reviewing, sending, processing, success, rejected, networkError }

class TransactionReviewScreen extends ConsumerStatefulWidget {
  const TransactionReviewScreen({super.key, required this.command});

  final ParsedVoiceCommand command;

  @override
  ConsumerState<TransactionReviewScreen> createState() =>
      _TransactionReviewScreenState();
}

class _TransactionReviewScreenState
    extends ConsumerState<TransactionReviewScreen> {
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _personController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _interestController = TextEditingController();

  late String _requestId;
  late String _currency;
  late DateTime _date;
  RepaymentDirection? _direction;
  InterestType _interestType = InterestType.simple;
  _SubmitPhase _phase = _SubmitPhase.reviewing;
  String? _formError;

  bool get _submitting =>
      _phase == _SubmitPhase.sending || _phase == _SubmitPhase.processing;

  ParsedVoiceCommand get _command => widget.command;
  TransactionType get _type =>
      _command.intent.transactionType ?? TransactionType.expense;
  bool get _needsPerson => _command.intent.requiresPerson;
  bool get _needsInterest =>
      _type == TransactionType.lending || _type == TransactionType.borrowing;

  @override
  void initState() {
    super.initState();
    _requestId = generateRequestId();
    final amount = _command.amount;
    if (amount != null) {
      _amountController.text = amount % 1 == 0
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
    }
    _categoryController.text = _command.categoryName ?? '';
    _personController.text = _command.personName ?? '';
    _descriptionController.text = _command.description;
    if (_command.interestRate != null) {
      _interestController.text = _command.interestRate!.toStringAsFixed(
        _command.interestRate! % 1 == 0 ? 0 : 2,
      );
    }
    _interestType = _command.interestType ?? InterestType.simple;
    _currency = _supportedCurrencies.contains(_command.currency.toUpperCase())
        ? _command.currency.toUpperCase()
        : 'INR';
    _date = DateTime(
      _command.transactionDate.year,
      _command.transactionDate.month,
      _command.transactionDate.day,
    );
    _direction = _command.repaymentDirection;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _personController.dispose();
    _descriptionController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  double? get _parsedAmount => InrFormatter.tryParse(_amountController.text);

  String? _matchCategoryId(List<Category> categories) {
    final name = _categoryController.text.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final category in categories) {
      if (category.name.toLowerCase() == name) return category.id;
    }
    return null;
  }

  String? _matchPersonId(List<Person> persons) {
    final name = _personController.text.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final person in persons) {
      if (person.name.toLowerCase() == name) return person.id;
    }
    return null;
  }

  String? _validate() {
    if (_parsedAmount == null) return 'Enter a valid amount greater than zero.';
    if (_needsPerson && _personController.text.trim().isEmpty) {
      return 'This entry needs a person.';
    }
    if (_type == TransactionType.repayment && _direction == null) {
      return 'Choose whether money was received or paid.';
    }
    final rate = _interestController.text.trim();
    if (_needsInterest && rate.isNotEmpty && double.tryParse(rate) == null) {
      return 'Enter a valid interest rate or leave it blank.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final error = _validate();
    if (error != null) {
      setState(() {
        _formError = error;
        _phase = _SubmitPhase.reviewing;
      });
      return;
    }

    setState(() {
      _formError = null;
      _phase = _SubmitPhase.sending;
    });

    final categories = ref.read(categoriesProvider).valueOrNull ?? const [];
    final persons = ref.read(personsProvider).valueOrNull ?? const [];
    final categoryId = _matchCategoryId(categories);
    final personId = _matchPersonId(persons);

    final draft = TransactionDraft(
      requestId: _requestId,
      type: _type,
      amount: _parsedAmount!,
      currency: _currency,
      transactionDate: _date,
      description: _descriptionController.text.trim(),
      categoryId: categoryId,
      categoryName: _nullIfEmpty(_categoryController.text),
      personId: personId,
      personName: _nullIfEmpty(_personController.text),
      interestRate: _needsInterest
          ? double.tryParse(_interestController.text.trim())
          : null,
      interestType: _needsInterest ? _interestType : null,
      repaymentDirection:
          _type == TransactionType.repayment ? _direction : null,
      voiceText: _command.originalText,
      parserConfidence: _command.confidence,
    );

    try {
      final result =
          await ref.read(ledgerRepositoryProvider).createVoiceCommand(
        draft,
        onSent: () {
          if (mounted && _phase == _SubmitPhase.sending) {
            setState(() => _phase = _SubmitPhase.processing);
          }
        },
      );
      if (!mounted) return;
      setState(() => _phase = _SubmitPhase.success);
      ref.read(voiceEntryControllerProvider.notifier).resetAfterSubmit();
      ref.invalidateLedgerData();
      await _showResult(result);
      if (mounted) context.go(Routes.dashboard);
    } catch (error) {
      if (!mounted) return;
      final isNetwork =
          error is AppException &&
          (error.kind == AppErrorKind.network ||
              error.kind == AppErrorKind.timeout);
      setState(() {
        _phase =
            isNetwork ? _SubmitPhase.networkError : _SubmitPhase.rejected;
        _formError = error is AppException
            ? error.message
            : friendlyErrorMessage(error);
      });
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _showResult(TransactionResult result) async {
    if (!mounted) return;
    final finance = context.financeColors;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.check_circle_rounded, color: finance.income, size: 40),
        title: Text(result.isDuplicate ? 'Already recorded' : 'Saved securely'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message),
            const SizedBox(height: 12),
            if (result.amountInr != null)
              _ResultRow(
                label: 'Amount (INR)',
                value: InrFormatter.format(result.amountInr!),
              ),
            if (result.exchangeRate != null)
              _ResultRow(
                label: 'Exchange rate',
                value: '1 $_currency = ₹'
                    '${result.exchangeRate!.toStringAsFixed(2)}',
              ),
            if (result.availableBalance != null)
              _ResultRow(
                label: 'Available balance',
                value: InrFormatter.format(result.availableBalance!),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queryTarget = resolveVoiceQuery(_command.intent);
    if (queryTarget != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${_command.intent.label} query')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoBanner(
                    title: 'This is a question',
                    message: '"${_command.originalText}" does not create a '
                        'transaction. Open ${queryTarget.label} to see the answer.',
                    icon: Icons.help_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Open ${queryTarget.label}',
                    icon: Icons.arrow_forward_rounded,
                    expand: true,
                    onPressed: () => context.go(queryTarget.route),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider);
    final persons = ref.watch(personsProvider);
    final categoryNames = _distinct(
      categories.valueOrNull
              ?.where((category) => category.type == _type)
              .map((category) => category.name) ??
          const [],
    );
    final personNames = _distinct(
      persons.valueOrNull?.map((person) => person.name) ?? const [],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review transaction'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: _TypeChip(type: _type)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _ConfidencePill(command: _command),
                        const Spacer(),
                        Text(
                          'How secure is this?',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You said',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${_command.originalText}"',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              if (_command.warnings.isNotEmpty) ...[
                const SizedBox(height: 14),
                InfoBanner(
                  title: 'Check these before saving',
                  message: _command.warnings.join(' '),
                  icon: Icons.fact_check_outlined,
                  color: const Color(0xFFB26A00),
                ),
              ],
              const SizedBox(height: 6),
              const SectionHeader(title: 'Amount'),
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixIcon: Icon(Icons.currency_rupee_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration:
                                const InputDecoration(labelText: 'Currency'),
                            items: _supportedCurrencies
                                .map(
                                  (currency) => DropdownMenuItem(
                                    value: currency,
                                    child: Text(currency),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _currency = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _AmountPreview(
                      amount: _parsedAmount,
                      currency: _currency,
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Details'),
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _categoryController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g. Food & Dining',
                        prefixIcon: Icon(Icons.local_offer_outlined),
                      ),
                    ),
                    if (categoryNames.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _Suggestions(
                        values: categoryNames,
                        onSelected: (value) {
                          _categoryController.text = value;
                          setState(() {});
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _personController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: _needsPerson ? 'Person (required)' : 'Person',
                        hintText: 'e.g. Rahul',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    if (personNames.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _Suggestions(
                        values: personNames,
                        onSelected: (value) {
                          _personController.text = value;
                          setState(() {});
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.event_rounded),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(AppDateFormatter.shortDate(_date))),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    if (_type == TransactionType.repayment) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Who paid whom?',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<RepaymentDirection>(
                        segments: const [
                          ButtonSegment(
                            value: RepaymentDirection.received,
                            label: Text('I received'),
                            icon: Icon(Icons.south_west_rounded),
                          ),
                          ButtonSegment(
                            value: RepaymentDirection.paid,
                            label: Text('I paid'),
                            icon: Icon(Icons.north_east_rounded),
                          ),
                        ],
                        selected: {?_direction},
                        emptySelectionAllowed: true,
                        onSelectionChanged: (selection) => setState(
                          () => _direction =
                              selection.isEmpty ? null : selection.first,
                        ),
                      ),
                    ],
                    if (_needsInterest) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _interestController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Interest rate % (optional)',
                                prefixIcon: Icon(Icons.percent_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<InterestType>(
                        segments: InterestType.values
                            .map(
                              (value) => ButtonSegment(
                                value: value,
                                label: Text(value.label),
                              ),
                            )
                            .toList(),
                        selected: {_interestType},
                        onSelectionChanged: (selection) => setState(
                          () => _interestType = selection.first,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              if (_phase == _SubmitPhase.sending ||
                  _phase == _SubmitPhase.processing) ...[
                const SizedBox(height: 14),
                InfoBanner(
                  title: _phase == _SubmitPhase.sending
                      ? 'Sending securely'
                      : 'Processing on Raspberry Pi',
                  message: _phase == _SubmitPhase.sending
                      ? 'Uploading the confirmed command over HTTPS.'
                      : 'The server is validating balances, currency and '
                          'saving the transaction.',
                  icon: _phase == _SubmitPhase.sending
                      ? Icons.cloud_upload_outlined
                      : Icons.settings_suggest_outlined,
                ),
              ] else if (_formError != null) ...[
                const SizedBox(height: 14),
                InfoBanner(
                  title: _phase == _SubmitPhase.networkError
                      ? 'Network error'
                      : _phase == _SubmitPhase.rejected
                          ? 'Command rejected'
                          : 'Cannot save yet',
                  message: _formError!,
                  icon: _phase == _SubmitPhase.networkError
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline_rounded,
                  color: scheme.error,
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Edit',
                      variant: AppButtonVariant.outlined,
                      onPressed:
                          _submitting ? null : () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Confirm & save',
                      icon: Icons.lock_rounded,
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Your Raspberry Pi validates the amount, converts currency if '
                'needed and writes the entry inside one database transaction.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _distinct(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed.toLowerCase())) result.add(trimmed);
    }
    return result;
  }
}

class _AmountPreview extends StatelessWidget {
  const _AmountPreview({required this.amount, required this.currency});

  final double? amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (amount == null) {
      return Text(
        'Enter the amount as spoken.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      );
    }
    if (currency == 'INR') {
      return Text(
        'You are recording ${InrFormatter.format(amount!)}.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
    }
    return Row(
      children: [
        Icon(Icons.sync_alt_rounded, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Server converts ${InrFormatter.formatOriginal(amount!, currency)} '
            'to rupees at the live rate when saving.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final color = TransactionVisuals.color(context, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.command});

  final ParsedVoiceCommand command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = command.confidence >= 0.85
        ? context.financeColors.income
        : const Color(0xFFB26A00);
    return Row(
      children: [
        Icon(Icons.auto_awesome_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          command.confidenceLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(command.confidence * 100).round()}%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.values, required this.onSelected});

  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .take(12)
          .map(
            (value) => ActionChip(
              label: Text(value),
              onPressed: () => onSelected(value),
            ),
          )
          .toList(),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
