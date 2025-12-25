"""Service for handling recurring offers."""
import logging
from datetime import datetime, date, timedelta
from uuid import UUID
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..models.offer import Offer
from ..models.offer_item import OfferItem

logger = logging.getLogger(__name__)

# Recurrence rule format:
# WEEKLY:MON,TUE,WED,THU,FRI,SAT,SUN
# Example: "WEEKLY:TUE,SAT" - every Tuesday and Saturday

DAY_MAP = {
    'MON': 0, 'TUE': 1, 'WED': 2, 'THU': 3,
    'FRI': 4, 'SAT': 5, 'SUN': 6
}

DAY_NAMES_PL = {
    0: 'Poniedziałek', 1: 'Wtorek', 2: 'Środa', 3: 'Czwartek',
    4: 'Piątek', 5: 'Sobota', 6: 'Niedziela'
}


def parse_recurrence_rule(rule: str) -> dict:
    """Parse recurrence rule string into structured format."""
    if not rule:
        return {}

    parts = rule.split(':')
    if len(parts) != 2:
        return {}

    rule_type = parts[0].upper()
    rule_value = parts[1].upper()

    if rule_type == 'WEEKLY':
        days = [DAY_MAP[d.strip()] for d in rule_value.split(',') if d.strip() in DAY_MAP]
        return {'type': 'WEEKLY', 'days': days}

    return {}


def get_next_occurrences(rule: str, from_date: date, count: int = 4) -> list[date]:
    """Get next N occurrence dates based on recurrence rule."""
    parsed = parse_recurrence_rule(rule)
    if not parsed:
        return []

    occurrences = []
    current = from_date

    if parsed['type'] == 'WEEKLY':
        days = parsed['days']
        if not days:
            return []

        # Find occurrences
        max_iterations = count * 14  # Safety limit
        iterations = 0

        while len(occurrences) < count and iterations < max_iterations:
            if current.weekday() in days and current > from_date:
                occurrences.append(current)
            current += timedelta(days=1)
            iterations += 1

    return occurrences


async def generate_recurring_offers(
    db: AsyncSession,
    days_ahead: int = 14,
    dry_run: bool = False
) -> list[dict]:
    """
    Generate new offer instances from recurring templates.

    Args:
        db: Database session
        days_ahead: How many days ahead to generate offers
        dry_run: If True, don't actually create offers, just return what would be created

    Returns:
        List of created/would-be-created offers info
    """
    logger.info(f"Generating recurring offers for next {days_ahead} days...")

    # Get all active recurring templates
    result = await db.execute(
        select(Offer)
        .options(selectinload(Offer.items))
        .where(
            and_(
                Offer.is_recurring == True,
                Offer.is_active == True,
                Offer.parent_offer_id == None,  # Only templates, not instances
            )
        )
    )
    templates = result.scalars().all()

    logger.info(f"Found {len(templates)} recurring templates")

    created = []
    today = date.today()
    end_date = today + timedelta(days=days_ahead)

    for template in templates:
        if not template.recurrence_rule:
            continue

        # Get next occurrences
        occurrences = get_next_occurrences(
            template.recurrence_rule,
            today,
            count=days_ahead  # Generate up to days_ahead occurrences
        )

        for pickup_date in occurrences:
            if pickup_date > end_date:
                continue

            # Check if instance already exists for this date
            existing = await db.execute(
                select(Offer).where(
                    and_(
                        Offer.parent_offer_id == template.id,
                        Offer.pickup_date == pickup_date,
                    )
                )
            )
            if existing.scalar_one_or_none():
                logger.debug(f"Instance already exists for {template.title} on {pickup_date}")
                continue

            # Calculate order deadline (e.g., day before at same time as pickup_time_from)
            deadline_date = pickup_date - timedelta(days=1)
            order_deadline = datetime.combine(
                deadline_date,
                template.pickup_time_from
            )

            offer_info = {
                'template_id': str(template.id),
                'template_title': template.title,
                'pickup_date': pickup_date.isoformat(),
                'order_deadline': order_deadline.isoformat(),
            }

            if not dry_run:
                # Create new offer instance
                new_offer = Offer(
                    title=template.title,
                    description=template.description,
                    pickup_date=pickup_date,
                    pickup_time_from=template.pickup_time_from,
                    pickup_time_to=template.pickup_time_to,
                    order_deadline=order_deadline,
                    is_recurring=False,  # Instance is not recurring
                    parent_offer_id=template.id,
                    is_active=True,
                    is_completed=False,
                )
                db.add(new_offer)
                await db.flush()

                # Copy items from template
                for template_item in template.items:
                    new_item = OfferItem(
                        offer_id=new_offer.id,
                        product_id=template_item.product_id,
                        product_size_id=template_item.product_size_id,
                        price=template_item.price,
                        max_quantity=template_item.max_quantity,
                        available_quantity=template_item.max_quantity,
                    )
                    db.add(new_item)

                offer_info['created_id'] = str(new_offer.id)
                logger.info(f"Created offer instance: {template.title} for {pickup_date}")

            created.append(offer_info)

    if not dry_run and created:
        await db.commit()
        logger.info(f"Generated {len(created)} new offer instances")

    return created


def format_recurrence_rule_pl(rule: str) -> str:
    """Format recurrence rule in Polish for display."""
    parsed = parse_recurrence_rule(rule)
    if not parsed:
        return "Brak"

    if parsed['type'] == 'WEEKLY':
        days = [DAY_NAMES_PL[d] for d in sorted(parsed['days'])]
        return f"Co tydzień: {', '.join(days)}"

    return rule
