from sqlalchemy import Column, String, Float, Integer, DateTime, func, ForeignKey
from app.database import Base

class Trip(Base):
    __tablename__ = "trips"

    id = Column(String, primary_key=True, index=True)
    driver_id = Column(String, nullable=False, index=True)
    route_id = Column(String, nullable=True)
    vehicle_id = Column(String, nullable=True)
    service_type = Column(String, default="COMBI") # COMBI, TAXI, BUS
    passenger_count = Column(Integer, default=1)
    revenue = Column(Float, default=8.0)
    distance_meters = Column(Float, default=0.0)
    duration_seconds = Column(Integer, default=0)
    start_lat = Column(Float, nullable=True)
    start_lng = Column(Float, nullable=True)
    end_lat = Column(Float, nullable=True)
    end_lng = Column(Float, nullable=True)
    status = Column(String, default="COMPLETED") # IN_PROGRESS, COMPLETED, CANCELLED
    started_at = Column(DateTime, default=func.now())
    ended_at = Column(DateTime, nullable=True)

class TaxiBooking(Base):
    __tablename__ = "taxi_bookings"

    id = Column(String, primary_key=True, index=True)
    passenger_id = Column(String, nullable=False, index=True)
    driver_id = Column(String, nullable=True, index=True)
    pickup_lat = Column(Float, nullable=False)
    pickup_lng = Column(Float, nullable=False)
    dropoff_lat = Column(Float, nullable=True)
    dropoff_lng = Column(Float, nullable=True)
    service_type = Column(String, default="STANDARD") # STANDARD, SPECIAL
    estimated_fare = Column(Float, default=8.0)
    final_fare = Column(Float, nullable=True)
    status = Column(String, default="PENDING") # PENDING, ACCEPTED, ON_TRIP, COMPLETED, CANCELLED
    created_at = Column(DateTime, default=func.now())
    completed_at = Column(DateTime, nullable=True)

class Review(Base):
    __tablename__ = "reviews"

    id = Column(Integer, primary_key=True, autoincrement=True)
    trip_id = Column(String, nullable=True)
    driver_id = Column(String, nullable=False)
    passenger_id = Column(String, nullable=False)
    rating = Column(Integer, nullable=False)
    comment = Column(String, nullable=True)
    created_at = Column(DateTime, default=func.now())
