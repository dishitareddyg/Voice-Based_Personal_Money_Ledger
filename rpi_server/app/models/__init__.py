"""SQLAlchemy models. Importing this package registers every table."""

from app.models.category import Category
from app.models.interest_scheme import InterestScheme
from app.models.loan import Loan
from app.models.person import Person
from app.models.repayment import Repayment
from app.models.transaction import Transaction
from app.models.user import User

__all__ = [
    "Category",
    "InterestScheme",
    "Loan",
    "Person",
    "Repayment",
    "Transaction",
    "User",
]
