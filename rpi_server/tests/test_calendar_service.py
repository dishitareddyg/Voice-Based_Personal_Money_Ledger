from __future__ import annotations

from datetime import date

import pytest

from app.core.errors import AppError
from app.services.calendar_service import _month_bounds


def test_month_bounds_regular_year() -> None:
    assert _month_bounds("2026-02") == (
        date(2026, 2, 1),
        date(2026, 2, 28),
    )


def test_month_bounds_leap_year() -> None:
    assert _month_bounds("2024-02") == (
        date(2024, 2, 1),
        date(2024, 2, 29),
    )


def test_month_bounds_december() -> None:
    assert _month_bounds("2026-12") == (
        date(2026, 12, 1),
        date(2026, 12, 31),
    )


def test_month_bounds_rejects_bad_input() -> None:
    for value in ("2026-13", "2026-1", "February", ""):
        with pytest.raises(AppError) as info:
            _month_bounds(value)
        assert info.value.code.value == "VALIDATION_ERROR"
