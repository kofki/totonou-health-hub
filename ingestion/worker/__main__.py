from datetime import date

from worker import garmin, vesync


def main() -> None:
    today = date.today()
    for source in (garmin, vesync):
        try:
            source.sync_day(today)
        except NotImplementedError as exc:
            print(f"[ingestion] {exc}")


if __name__ == "__main__":
    main()
