import 'package:flutter/material.dart';

class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.savings,
    required this.lending,
    required this.borrowing,
    required this.repayment,
    required this.warning,
    required this.neutral,
    required this.balanceGlow,
  });

  final Color income;
  final Color expense;
  final Color savings;
  final Color lending;
  final Color borrowing;
  final Color repayment;
  final Color warning;
  final Color neutral;
  final Color balanceGlow;

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? savings,
    Color? lending,
    Color? borrowing,
    Color? repayment,
    Color? warning,
    Color? neutral,
    Color? balanceGlow,
  }) {
    return FinanceColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      savings: savings ?? this.savings,
      lending: lending ?? this.lending,
      borrowing: borrowing ?? this.borrowing,
      repayment: repayment ?? this.repayment,
      warning: warning ?? this.warning,
      neutral: neutral ?? this.neutral,
      balanceGlow: balanceGlow ?? this.balanceGlow,
    );
  }

  @override
  FinanceColors lerp(covariant FinanceColors? other, double t) {
    if (other == null) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      savings: Color.lerp(savings, other.savings, t)!,
      lending: Color.lerp(lending, other.lending, t)!,
      borrowing: Color.lerp(borrowing, other.borrowing, t)!,
      repayment: Color.lerp(repayment, other.repayment, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      balanceGlow: Color.lerp(balanceGlow, other.balanceGlow, t)!,
    );
  }
}

extension FinanceColorsContext on BuildContext {
  FinanceColors get financeColors =>
      Theme.of(this).extension<FinanceColors>() ?? AppTheme.lightFinance;
}

class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF0E6B5C);
  static const Color _lightSurface = Color(0xFFF6F8F5);
  static const Color _darkSurface = Color(0xFF0D1512);

  static const FinanceColors lightFinance = FinanceColors(
    income: Color(0xFF17815E),
    expense: Color(0xFFC44848),
    savings: Color(0xFF6554C0),
    lending: Color(0xFF2D6FBE),
    borrowing: Color(0xFFC57921),
    repayment: Color(0xFF0E7C7B),
    warning: Color(0xFFB26A00),
    neutral: Color(0xFF5C6B66),
    balanceGlow: Color(0xFF7BD8B4),
  );

  static const FinanceColors darkFinance = FinanceColors(
    income: Color(0xFF6FD6A8),
    expense: Color(0xFFFF9A94),
    savings: Color(0xFFB9A9FF),
    lending: Color(0xFF91C4F5),
    borrowing: Color(0xFFFFC777),
    repayment: Color(0xFF7CD8D5),
    warning: Color(0xFFFFC46B),
    neutral: Color(0xFFA9B8B2),
    balanceGlow: Color(0xFF2E8A6C),
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: _lightSurface,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0F4F0),
      surfaceContainer: const Color(0xFFE9EFEA),
    );
    return _base(scheme, lightFinance);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: _darkSurface,
      surfaceContainerLowest: const Color(0xFF101A16),
      surfaceContainerLow: const Color(0xFF16211D),
      surfaceContainer: const Color(0xFF1B2823),
    );
    return _base(scheme, darkFinance);
  }

  static ThemeData _base(ColorScheme scheme, FinanceColors finance) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[finance],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? .28 : .45),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: .7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: isDark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .55),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: isDark ? const Color(0xFF24332D) : const Color(0xFF20332B),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
