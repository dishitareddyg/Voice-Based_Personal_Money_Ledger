from app.api.routes.typed import build_typed_router
from app.core.enums import TransactionType

router = build_typed_router(
    TransactionType.INCOME, prefix="/income", tag="income"
)
