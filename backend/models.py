# backend/models.py

from pydantic import BaseModel
from typing import Optional, List

class UserCredentials(BaseModel):
    username: str
    password: str
    target_time: Optional[str] = None
    is_return: bool = False

class ReservationResult(BaseModel):
    reserved_route: str
    reserved_time: str
    qr_code: str

class QRCodeResult(BaseModel):
    success: bool
    reservations: List[ReservationResult]
    message: str