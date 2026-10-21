enum TransactionType {
  income,
  expense,
  saving,
  lending,
  borrowing,
  repayment;

  String get apiValue {
    switch (this) {
      case TransactionType.saving:
        return 'savings';
      case TransactionType.lending:
        return 'lending';
      case TransactionType.borrowing:
        return 'borrowing';
      case TransactionType.repayment:
        return 'repayment';
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
    }
  }

  String get commandIntent {
    switch (this) {
      case TransactionType.income:
        return 'CREATE_INCOME';
      case TransactionType.expense:
        return 'CREATE_EXPENSE';
      case TransactionType.saving:
        return 'CREATE_SAVINGS';
      case TransactionType.lending:
        return 'CREATE_LENDING';
      case TransactionType.borrowing:
        return 'CREATE_BORROWING';
      case TransactionType.repayment:
        return 'CREATE_REPAYMENT';
    }
  }

  String get label {
    switch (this) {
      case TransactionType.saving:
        return 'Savings';
      case TransactionType.lending:
        return 'Lending';
      case TransactionType.borrowing:
        return 'Borrowing';
      case TransactionType.repayment:
        return 'Repayment';
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
    }
  }

  String get actionLabel => label;

  static TransactionType parse(dynamic value) {
    final normalized = value?.toString().toLowerCase().trim() ?? '';
    switch (normalized) {
      case 'income':
      case 'credit':
      case 'salary':
        return TransactionType.income;
      case 'expense':
      case 'spend':
      case 'debit':
        return TransactionType.expense;
      case 'saving':
      case 'savings':
      case 'save':
        return TransactionType.saving;
      case 'lending':
      case 'lend':
      case 'loan_given':
      case 'loan_lent':
        return TransactionType.lending;
      case 'borrowing':
      case 'borrow':
      case 'loan_taken':
      case 'loan_borrowed':
        return TransactionType.borrowing;
      case 'repayment':
      case 'repay':
      case 'loan_repayment':
        return TransactionType.repayment;
      default:
        return TransactionType.expense;
    }
  }
}

enum LoanKind {
  lent,
  borrowed;

  String get apiValue => this == LoanKind.lent ? 'lent' : 'borrowed';
  String get label => this == LoanKind.lent ? 'Lent' : 'Borrowed';

  static LoanKind parse(dynamic value) {
    return value?.toString().toLowerCase() == 'borrowed'
        ? LoanKind.borrowed
        : LoanKind.lent;
  }
}

enum RepaymentDirection {
  received,
  paid;

  String get apiValue => name;
  String get label => this == RepaymentDirection.received ? 'Received' : 'Paid';

  static RepaymentDirection? tryParse(dynamic value) {
    final normalized = value?.toString().toLowerCase().trim();
    if (normalized == 'received' || normalized == 'incoming') {
      return RepaymentDirection.received;
    }
    if (normalized == 'paid' || normalized == 'outgoing') {
      return RepaymentDirection.paid;
    }
    return null;
  }
}

enum InterestType {
  simple,
  compound,
  flat;

  String get apiValue => name;
  String get label {
    switch (this) {
      case InterestType.simple:
        return 'Simple';
      case InterestType.compound:
        return 'Compound';
      case InterestType.flat:
        return 'Flat';
    }
  }

  static InterestType parse(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'compound':
        return InterestType.compound;
      case 'flat':
        return InterestType.flat;
      default:
        return InterestType.simple;
    }
  }
}
