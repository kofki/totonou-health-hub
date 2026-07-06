from datetime import date

import pytest

from worker import garmin, vesync


def test_garmin_sync_is_stub() -> None:
    with pytest.raises(NotImplementedError, match="P2-01"):
        garmin.sync_day(date(2026, 7, 5))


def test_vesync_sync_is_stub() -> None:
    with pytest.raises(NotImplementedError, match="P2-02"):
        vesync.sync_day(date(2026, 7, 5))
