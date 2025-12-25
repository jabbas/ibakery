from datetime import date, timedelta
from dateutil.relativedelta import relativedelta


def parse_recurrence_rule(rule: str) -> dict:
    """
    Parse recurrence rule string.

    Formats:
    - WEEKLY:MON - every Monday
    - WEEKLY:TUE,FRI - every Tuesday and Friday
    - BIWEEKLY:SAT - every 2 weeks on Saturday
    - MONTHLY:15 - every month on 15th day
    """
    parts = rule.upper().split(":")
    if len(parts) != 2:
        raise ValueError(f"Invalid recurrence rule: {rule}")

    frequency = parts[0]
    value = parts[1]

    return {"frequency": frequency, "value": value}


DAY_MAP = {
    "MON": 0,
    "TUE": 1,
    "WED": 2,
    "THU": 3,
    "FRI": 4,
    "SAT": 5,
    "SUN": 6,
}


def get_next_occurrence(rule: str, after_date: date) -> date:
    """Get the next occurrence date based on recurrence rule."""
    parsed = parse_recurrence_rule(rule)
    frequency = parsed["frequency"]
    value = parsed["value"]

    if frequency == "WEEKLY":
        days = [DAY_MAP[d.strip()] for d in value.split(",")]
        current = after_date + timedelta(days=1)

        while True:
            if current.weekday() in days:
                return current
            current += timedelta(days=1)
            if current > after_date + timedelta(days=14):
                break

    elif frequency == "BIWEEKLY":
        days = [DAY_MAP[d.strip()] for d in value.split(",")]
        current = after_date + timedelta(days=1)

        while True:
            if current.weekday() in days:
                return current
            current += timedelta(days=1)
            if current > after_date + timedelta(days=21):
                break

    elif frequency == "MONTHLY":
        day_of_month = int(value)
        next_month = after_date + relativedelta(months=1)
        try:
            return date(next_month.year, next_month.month, day_of_month)
        except ValueError:
            # Handle months with fewer days
            last_day = (next_month + relativedelta(months=1) - timedelta(days=1)).day
            return date(next_month.year, next_month.month, min(day_of_month, last_day))

    raise ValueError(f"Unknown frequency: {frequency}")


def get_occurrences(
    rule: str,
    start_date: date,
    end_date: date,
) -> list[date]:
    """Get all occurrence dates within a date range."""
    occurrences = []
    current = start_date - timedelta(days=1)

    while True:
        next_date = get_next_occurrence(rule, current)
        if next_date > end_date:
            break
        occurrences.append(next_date)
        current = next_date

    return occurrences
