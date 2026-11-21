"""SQLAlchemy models. Importing this package registers every table."""

from app.models.application_event import ApplicationEvent
from app.models.audit_log import AuditLog
from app.models.category import Category
from app.models.exchange_rate_cache import ExchangeRateCache
from app.models.interest_scheme import InterestScheme
from app.models.loan import Loan
from app.models.person import Person
from app.models.repayment import Repayment
from app.models.transaction import Transaction
from app.models.user import User
from app.models.voice_command import VoiceCommand

__all__ = [
    "ApplicationEvent",
    "AuditLog",
    "Category",
    "ExchangeRateCache",
    "InterestScheme",
    "Loan",
    "Person",
    "Repayment",
    "Transaction",
    "User",
    "VoiceCommand",
]
