# backend/routes.py

from fastapi import APIRouter, HTTPException
from models import UserCredentials, QRCodeResult
from services import get_qr_code_service
import logging

router = APIRouter()

@router.post("/get_qr_code", response_model=QRCodeResult)
async def api_get_qr_code(credentials: UserCredentials):
    try:
        logging.info(f"Received reservation request: {credentials}")
        result = await get_qr_code_service(credentials)
        return result
    except HTTPException as e:
        raise e
    except Exception as e:
        logging.error(f"Unexpected error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")