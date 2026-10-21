import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../features/voice/nlp/voice_nlp_parser.dart';
import '../repositories/admin_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/directory_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/income_repository.dart';
import '../repositories/ledger_repository.dart';
import '../repositories/loan_repository.dart';
import '../repositories/repayment_repository.dart';
import '../repositories/savings_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/api_client.dart';
import '../services/secure_token_storage.dart';
import '../services/speech_service.dart';
import 'session_providers.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

final dioProvider = Provider<Dio>((ref) {
  return createApiClient(
    ref.watch(appConfigProvider),
    ref.watch(tokenStorageProvider),
    onUnauthorized: () {
      final storage = ref.read(tokenStorageProvider);
      unawaited(storage.clearSession());
      ref.read(sessionEventProvider.notifier).notifyUnauthorized();
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return ApiTransactionRepository(ref.watch(dioProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ApiExpenseRepository(ref.watch(transactionRepositoryProvider));
});

final incomeRepositoryProvider = Provider<IncomeRepository>((ref) {
  return ApiIncomeRepository(ref.watch(transactionRepositoryProvider));
});

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return ApiSavingsRepository(ref.watch(transactionRepositoryProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return ApiDashboardRepository(ref.watch(dioProvider));
});

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return ApiLoanRepository(ref.watch(dioProvider));
});

final repaymentRepositoryProvider = Provider<RepaymentRepository>((ref) {
  return ApiRepaymentRepository(
    ref.watch(dioProvider),
    ref.watch(transactionRepositoryProvider),
  );
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return ApiLedgerRepository(ref.watch(dioProvider));
});

final personRepositoryProvider = Provider<PersonRepository>((ref) {
  return ApiDirectoryRepository(ref.watch(dioProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return ApiDirectoryRepository(ref.watch(dioProvider));
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return ApiAdminRepository(ref.watch(dioProvider));
});

final speechRecognitionServiceProvider =
    Provider<SpeechRecognitionService>((ref) {
  return DeviceSpeechRecognitionService();
});

final voiceNlpParserProvider = Provider<VoiceNlpParser>((ref) {
  return const VoiceNlpParser();
});
