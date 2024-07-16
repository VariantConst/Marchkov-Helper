import logging
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .utils import login, get_beijing_time, get_bus_direction, reserve_bus, cancel_reservation, get_bus_info
from .session import get_db_session, update_token, update_bus_info, get_token, get_stored_bus_info
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def ensure_login(session: requests.Session = Depends(get_db_session)):
    token = get_token()
    if not token:
        token = login(settings.USERNAME, settings.PASSWORD, session)
        if token:
            update_token(token)
            bus_info = get_bus_info(get_beijing_time(), token, session)
            update_bus_info(bus_info)
            logger.info("Logged in and fetched bus info successfully.")
        else:
            logger.error("Failed to log in.")
            return None
    return session

@app.get("/api/auth")
async def auth(token: str):
    try:
        if settings.AUTH_TOKEN == "" or token != settings.AUTH_TOKEN:
            return {"success": False, "message": "环境变量 AUTH_TOKEN 错误或未设置。"}
        return {"success": True, "message": "TOKEN 验证成功"}
    except Exception as e:
        logger.error(f"认证失败: {e}")
        return {"success": False, "message": f"认证过程中发生错误: {str(e)}"}

@app.get("/api/login")
async def api_login(session: requests.Session = Depends(get_db_session)):
    try:
        token = get_token()
        if not token:
            token = login(settings.USERNAME, settings.PASSWORD, session)
            if token:
                update_token(token)
                bus_info = get_bus_info(get_beijing_time(), token, session)
                update_bus_info(bus_info)
                return {"success": True, "message": "登录成功", "username": settings.USERNAME}
            else:
                return {"success": False, "message": "登录失败。请检查环境变量 USERNAME 和 PASSWORD。"}
        return {"success": True, "message": "已经登录", "username": settings.USERNAME}
    except Exception as e:
        logger.error(f"登录失败: {e}")
        return {"success": False, "message": f"登录过程中发生错误: {str(e)}"}

@app.get("/api/reserve")
async def reserve(is_first_load: bool=True, is_to_yanyuan: bool = True, session: requests.Session = Depends(ensure_login)):
    try:
        current_time = get_beijing_time()
        if is_first_load:
            is_to_yanyuan = get_bus_direction(current_time)
        print(f"将按照 is_first_load {is_first_load}, is_to_yanyuan {is_to_yanyuan} 进行预约。")

        bus_info = get_stored_bus_info()
        if bus_info is None:
            token = get_token()
            bus_info = get_bus_info(get_beijing_time(), token, session)
            update_bus_info(bus_info)

        reservation = reserve_bus(current_time, is_to_yanyuan, bus_info, session)
        if not reservation["success"]:
            if is_first_load:
                is_to_yanyuan = not is_to_yanyuan
                reservation = reserve_bus(current_time, is_to_yanyuan, bus_info, session)
            if not reservation["success"]:
                return {
                    "success": False,
                    "message": "这会没有班车可坐。急了？" if is_first_load else "反向无车可坐。"
                }
        
        return {
            "success": True,
            "message": "预约成功",
            "is_to_yanyuan": is_to_yanyuan,
            "qrcode_type": reservation["qrcode_type"],
            "route_name": reservation["route_name"],
            "start_time": reservation["start_time"],
            "qrcode": reservation["qrcode"],
            "app_id": reservation.get("app_id", None),
            "app_appointment_id": reservation.get("app_appointment_id", None),
        }
        
    except Exception as e:
        logger.error(f"预约失败: {e}")
        return {"success": False, "message": f"预约过程中发生错误: {str(e)}"}

@app.get("/api/cancel")
async def api_cancel_reservation(app_id: int, app_appointment_id: int, session: requests.Session = Depends(ensure_login)):
    result = cancel_reservation(app_id, app_appointment_id, session)
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)