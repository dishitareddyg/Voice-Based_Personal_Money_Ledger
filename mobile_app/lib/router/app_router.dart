import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_screen.dart';
import '../features/auth/presentation/create_account_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/ledger/presentation/borrowing_screen.dart';
import '../features/ledger/presentation/expenses_screen.dart';
import '../features/ledger/presentation/income_screen.dart';
import '../features/ledger/presentation/lending_screen.dart';
import '../features/ledger/presentation/repayments_screen.dart';
import '../features/ledger/presentation/savings_screen.dart';
import '../features/persons/presentation/persons_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shared/presentation/main_shell.dart';
import '../features/transactions/presentation/transaction_history_screen.dart';
import '../features/voice/nlp/voice_command.dart';
import '../features/voice/presentation/transaction_review_screen.dart';
import '../features/voice/presentation/voice_entry_screen.dart';
import '../providers/auth_provider.dart';
import 'routes.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  ref.listen(authControllerProvider, (previous, next) {
    refresh.refresh();
  });

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final path = state.uri.path;

      if (path == Routes.splash) {
        return null;
      }

      final auth = ref.read(authControllerProvider);
      if (auth.isLoading && !auth.hasValue) {
        return Routes.splash;
      }

      final session = auth.valueOrNull;
      final isAuthRoute = path == Routes.login || path == Routes.register;

      if (session == null) {
        return isAuthRoute ? null : Routes.login;
      }

      if (isAuthRoute) {
        return Routes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const CreateAccountScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.voice,
                builder: (context, state) => const VoiceEntryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.transactions,
                builder: (context, state) =>
                    const TransactionHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.review,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is ParsedVoiceCommand) {
            return TransactionReviewScreen(command: extra);
          }
          return const _ReviewFallbackScreen();
        },
      ),
      GoRoute(
        path: Routes.expenses,
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: Routes.income,
        builder: (context, state) => const IncomeScreen(),
      ),
      GoRoute(
        path: Routes.savings,
        builder: (context, state) => const SavingsScreen(),
      ),
      GoRoute(
        path: Routes.lending,
        builder: (context, state) => const LendingScreen(),
      ),
      GoRoute(
        path: Routes.borrowing,
        builder: (context, state) => const BorrowingScreen(),
      ),
      GoRoute(
        path: Routes.repayments,
        builder: (context, state) => const RepaymentsScreen(),
      ),
      GoRoute(
        path: Routes.persons,
        builder: (context, state) => const PersonsScreen(),
      ),
      GoRoute(
        path: Routes.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: Routes.admin,
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class _ReviewFallbackScreen extends StatelessWidget {
  const _ReviewFallbackScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_none_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'There is no confirmed voice entry to review.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(Routes.voice),
                child: const Text('Go to voice entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
