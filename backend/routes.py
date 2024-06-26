# backend/routes.py

from fastapi import APIRouter, HTTPException
from models import UserCredentials, QRCodeResult
from services import get_qr_code_service
import logging
from typing import Dict, Any

router = APIRouter()

@router.post("/get_qr_code", response_model=QRCodeResult)
async def api_get_qr_code(credentials: UserCredentials) -> Dict[str, Any]:
    """
    处理获取二维码的API请求。

    :param credentials: 用户凭证
    :return: 二维码结果
    :raises HTTPException: 当发生意外错误时
    """
    try:
        logging.info(f"收到预约请求：{credentials}")
        result = await get_qr_code_service(credentials)
        return result
    except HTTPException as e:
        raise e
    except Exception as e:
        logging.error(f"发生意外错误：{str(e)}")
        raise HTTPException(status_code=500, detail=f"发生意外错误：{str(e)}")