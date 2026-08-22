from sqlalchemy import Column, String, Float, Integer, ForeignKey, DateTime, func, Enum
from sqlalchemy.orm import relationship
import enum
from app.database import Base

class RouteType(str, enum.Enum):
    COMBI = "COMBI"
    BUS = "BUS"
    TAXI = "TAXI"

class Route(Base):
    __tablename__ = "routes"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    origin_name = Column(String, nullable=False)
    destination_name = Column(String, nullable=False)
    route_type = Column(String, default=RouteType.COMBI.value)
    base_fare = Column(Float, default=8.0)
    created_at = Column(DateTime, default=func.now())

    stops = relationship("RouteStop", back_populates="route", cascade="all, delete-orphan")

class Stop(Base):
    __tablename__ = "stops"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    description = Column(String, nullable=True)
    created_at = Column(DateTime, default=func.now())

    route_associations = relationship("RouteStop", back_populates="stop")

class RouteStop(Base):
    __tablename__ = "route_stops"

    id = Column(Integer, primary_key=True, autoincrement=True)
    route_id = Column(String, ForeignKey("routes.id"), nullable=False)
    stop_id = Column(String, ForeignKey("stops.id"), nullable=False)
    stop_sequence = Column(Integer, default=1)
    distance_from_start_meters = Column(Float, default=0.0)

    route = relationship("Route", back_populates="stops")
    stop = relationship("Stop", back_populates="route_associations")

class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(String, primary_key=True, index=True)
    license_plate = Column(String, nullable=False, unique=True)
    vehicle_type = Column(String, default=RouteType.COMBI.value)
    capacity = Column(Integer, default=15)
    model = Column(String, nullable=True)
    created_at = Column(DateTime, default=func.now())
