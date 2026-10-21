"""Canonical enumerations shared by models, schemas and services.

The string values are part of the API contract with the Flutter client and are
also persisted in MySQL. Never rename a value without a migration.
"""

from __future__ import annotations

from enum import Enum


class TransactionType(str, Enum):
    INCOME = "income"
    EXPENSE = "expense"
    SAVINGS = "savings"
    LENDING = "lending"
    BORROWING = "borrowing"
    REPAYMENT = "repayment"

    @property
    def is_outflow(self) -> bool:
        """Types that reduce the available cash balance."""
        return self in {
            TransactionType.EXPENSE,
            TransactionType.SAVINGS,
            TransactionType.LENDING,
        }

    @property
    def requires_person(self) -> bool:
        return self in {
            TransactionType.LENDING,
            TransactionType.BORROWING,
            TransactionType.REPAYMENT,
        }

    @property
    def requires_balance(self) -> bool:
        return self in {
            TransactionType.EXPENSE,
            TransactionType.SAVINGS,
            TransactionType.LENDING,
        }

    @property
    def loan_kind(self) -> "LoanKind | None":
        if self is TransactionType.LENDING:
            return LoanKind.LENT
        if self is TransactionType.BORROWING:
            return LoanKind.BORROWED
        return None


class CommandIntent(str, Enum):
    """Structured intents emitted by the mobile voice parser."""

    CREATE_INCOME = "CREATE_INCOME"
    CREATE_EXPENSE = "CREATE_EXPENSE"
    CREATE_SAVINGS = "CREATE_SAVINGS"
    CREATE_LENDING = "CREATE_LENDING"
    CREATE_BORROWING = "CREATE_BORROWING"
    CREATE_REPAYMENT = "CREATE_REPAYMENT"

    @property
    def transaction_type(self) -> "TransactionType":
        return {
            CommandIntent.CREATE_INCOME: TransactionType.INCOME,
            CommandIntent.CREATE_EXPENSE: TransactionType.EXPENSE,
            CommandIntent.CREATE_SAVINGS: TransactionType.SAVINGS,
            CommandIntent.CREATE_LENDING: TransactionType.LENDING,
            CommandIntent.CREATE_BORROWING: TransactionType.BORROWING,
            CommandIntent.CREATE_REPAYMENT: TransactionType.REPAYMENT,
        }[self]


class LoanKind(str, Enum):
    LENT = "lent"
    BORROWED = "borrowed"


class LoanStatus(str, Enum):
    OPEN = "open"
    CLOSED = "closed"


class RepaymentDirection(str, Enum):
    RECEIVED = "received"
    PAID = "paid"


class InterestType(str, Enum):
    SIMPLE = "simple"
    COMPOUND = "compound"
    FLAT = "flat"


class CompoundingFrequency(str, Enum):
    """How compound interest is capitalised.

    ``none`` is used for simple/flat interest, where compounding does not
    apply. The value is stored with the scheme and copied into reports.
    """

    NONE = "none"
    DAILY = "daily"
    MONTHLY = "monthly"
    QUARTERLY = "quarterly"
    HALF_YEARLY = "half_yearly"
    YEARLY = "yearly"


class UserRole(str, Enum):
    USER = "user"
    ADMIN = "admin"


class TransactionStatus(str, Enum):
    COMPLETED = "completed"
    REVERSED = "reversed"


class AdminAction(str, Enum):
    """Whitelisted administrative commands. There is no arbitrary SQL API."""

    DATABASE_STATS = "DATABASE_STATS"
    RUN_MIGRATIONS = "RUN_MIGRATIONS"
    CREATE_BACKUP = "CREATE_BACKUP"
    OPTIMIZE_INDEXES = "OPTIMIZE_INDEXES"
    PRUNE_RATE_CACHE = "PRUNE_RATE_CACHE"


class ErrorCode(str, Enum):
    # Validation
    VALIDATION_ERROR = "VALIDATION_ERROR"
    INVALID_AMOUNT = "INVALID_AMOUNT"
    INVALID_CURRENCY = "INVALID_CURRENCY"
    INVALID_INTEREST_RATE = "INVALID_INTEREST_RATE"
    INVALID_REPAYMENT_DIRECTION = "INVALID_REPAYMENT_DIRECTION"
    INVALID_TRANSACTION_TYPE = "INVALID_TRANSACTION_TYPE"

    # Financial rules
    INSUFFICIENT_BALANCE = "INSUFFICIENT_BALANCE"
    INVALID_PERSON = "INVALID_PERSON"
    INVALID_CATEGORY = "INVALID_CATEGORY"
    INVALID_LOAN = "INVALID_LOAN"
    LOAN_NOT_FOUND = "LOAN_NOT_FOUND"
    LOAN_CLOSED = "LOAN_CLOSED"
    REPAYMENT_EXCEEDS_OUTSTANDING = "REPAYMENT_EXCEEDS_OUTSTANDING"
    PERSON_IN_USE = "PERSON_IN_USE"
    CATEGORY_IN_USE = "CATEGORY_IN_USE"

    # Idempotency
    DUPLICATE_REQUEST = "DUPLICATE_REQUEST"
    IDEMPOTENCY_CONFLICT = "IDEMPOTENCY_CONFLICT"

    # Auth / authorization
    UNAUTHORIZED = "UNAUTHORIZED"
    INVALID_CREDENTIALS = "INVALID_CREDENTIALS"
    FORBIDDEN = "FORBIDDEN"
    USER_INACTIVE = "USER_INACTIVE"
    EMAIL_ALREADY_EXISTS = "EMAIL_ALREADY_EXISTS"

    # Admin
    ADMIN_CONFIRMATION_REQUIRED = "ADMIN_CONFIRMATION_REQUIRED"
    ADMIN_PASSWORD_INVALID = "ADMIN_PASSWORD_INVALID"
    UNSUPPORTED_ACTION = "UNSUPPORTED_ACTION"

    # Infrastructure
    NOT_FOUND = "NOT_FOUND"
    METHOD_NOT_ALLOWED = "METHOD_NOT_ALLOWED"
    EXCHANGE_RATE_UNAVAILABLE = "EXCHANGE_RATE_UNAVAILABLE"
    DATABASE_ERROR = "DATABASE_ERROR"
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    INTERNAL_ERROR = "INTERNAL_ERROR"
