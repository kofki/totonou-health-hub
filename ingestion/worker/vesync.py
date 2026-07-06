from datetime import date

from worker.config import settings


def sync_day(day: date) -> dict:
    # Example: pyvesync logs in with VeSync(email, password, time_zone), then
    # manager.update() populates devices — the smart scale exposes weight/body-composition
    # TODO: P2-02 — blocked on P2-03: implement after the owner designs the payload contract
    raise NotImplementedError(f"P2-02 not started (would sync {day} for {settings.vesync_email})")
