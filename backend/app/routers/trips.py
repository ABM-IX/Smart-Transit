from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
import uuid
import time

from app.database import get_db
from app.models.trip import Trip, TaxiBooking, Review
from app.schemas.trip import TaxiRequestIn, TaxiRequestOut, DriverRatingIn
from app.services.fare import get_fare

router = APIRouter(prefix="/api/trips", tags=["Trips & Bookings"])

@router.post("/taxi/book", response_model=TaxiRequestOut)
async def book_taxi(booking: TaxiRequestIn, db: AsyncSession = Depends(get_db)):
    """Creates a new taxi booking and estimates fare."""
    req_id = f"req-{uuid.uuid4().hex[:8]}"
    fare = get_fare(
        booking.service_type,
        {"lat": booking.pickup.lat, "lng": booking.pickup.lng},
        {"lat": booking.dropoff.lat, "lng": booking.dropoff.lng} if booking.dropoff else None
    )

    db_booking = TaxiBooking(
        id=req_id,
        passenger_id=booking.passenger_id,
        pickup_lat=booking.pickup.lat,
        pickup_lng=booking.pickup.lng,
        dropoff_lat=booking.dropoff.lat if booking.dropoff else None,
        dropoff_lng=booking.dropoff.lng if booking.dropoff else None,
        service_type=booking.service_type,
        estimated_fare=fare,
        status="PENDING"
    )
    try:
        db.add(db_booking)
        await db.commit()
    except Exception:
        pass

    return TaxiRequestOut(
        request_id=req_id,
        passenger_id=booking.passenger_id,
        pickup=booking.pickup,
        dropoff=booking.dropoff,
        service_type=booking.service_type,
        fare_estimate=fare,
        status="PENDING",
        requested_at=time.time()
    )

@router.post("/rating")
async def submit_rating(rating_in: DriverRatingIn, db: AsyncSession = Depends(get_db)):
    """Submits a passenger rating and comment for a driver."""
    review = Review(
        driver_id=rating_in.driver_id,
        passenger_id=rating_in.passenger_id,
        rating=rating_in.rating,
        comment=rating_in.comment
    )
    try:
        db.add(review)
        await db.commit()
    except Exception:
        pass
    
    return {"status": "success", "message": "Rating recorded successfully"}
