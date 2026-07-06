from datetime import date

from worker.config import settings


def sync_day(day: date) -> dict:
    # Example: python-garminconnect logs in with your normal Garmin account and exposes
    # methods like get_steps_data(day), get_heart_rates(day), get_sleep_data(day)
    # TODO: P2-01 — blocked on P2-03: the owner designs the ingestion→API payload contract
    # before this glue gets implemented (login/session cache, pulls, retries, push to api)
    raise NotImplementedError(f"P2-01 not started (would sync {day} for {settings.garmin_email})")
