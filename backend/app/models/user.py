from sqlalchemy import Column, String, Float, Integer, DateTime, func, Boolean
from app.database import Base

class UserRole:
    PASSENGER = "PASSENGER"
    DRIVER = "DRIVER"
    ADMIN = "ADMIN"

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    full_name = Column(String, nullable=False)
    phone_number = Column(String, nullable=True, unique=True)
    email = Column(String, nullable=True, unique=True)
    role = Column(String, default=UserRole.PASSENGER)
    created_at = Column(DateTime, default=func.now())

class DriverProfile(Base):
    __tablename__ = "driver_profiles"

    driver_id = Column(String, primary_key=True, index=True)
    vehicle_id = Column(String, nullable=True)
    assigned_route_id = Column(String, nullable=True)
    service_type = Column(String, default="COMBI") # COMBI, TAXI, BUS
    is_online = Column(Boolean, default=False)
    rating_avg = Column(Float, default=5.0)
    rating_count = Column(Integer, default=0)
    current_lat = Column(Float, nullable=True)
    current_lng = Column(Float, nullable=True)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())
