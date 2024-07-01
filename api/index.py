from fastapi import FastAPI
from dotenv import load_dotenv
from .reserve import PKUReserve
from os import getenv
import datetime
from logging import getLogger

logger = getLogger(__name__)


app = FastAPI()

load_dotenv()

reserve = PKUReserve()

@app.get("/api/login")
def login():
    reserve = PKUReserve()
    try:
        token = reserve.login(getenv("PKU_USERNAME"), getenv("PKU_PASSWORD"))
        if token:
            return {"success": True, "username": getenv("PKU_USERNAME")}
            # possible_expired_bus, possible_future_bus = reserve.decide_bus(datetime.datetime.now().strftime("%Y-%m-%d"), datetime.datetime.now().strftime("%H:%M"))
            # return {"success": True, "possible_expired_bus": possible_expired_bus, "possible_future_bus": possible_future_bus}
        else:
            return {"success": False, "message": "登录失败，请检查用户名和密码"}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}
    
@app.get("/api/get_available_bus")
def get_available_bus():
    reserve = PKUReserve()
    reserve.login(getenv("PKU_USERNAME"), getenv("PKU_PASSWORD"))
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    cur_time = datetime.datetime.now().strftime("%H:%M")
    try:
        possible_bus = reserve.get_available_bus(date, cur_time)
        return {"success": True, "possible_bus": possible_bus}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}
    
@app.get("/api/reserve_and_get_qrcode")
def reserve_and_get_qrcode(resource_id: int, period: str, sub_resource_id: int):
    print(f"resource_id: {resource_id}, period: {period}, sub_resource_id: {sub_resource_id}")
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    try:
        qrcode, app_id, app_appointment_id = reserve.reserve_and_get_qrcode(resource_id, period, sub_resource_id, date)
        if qrcode is None:
            return {"success": False, "message": "预约失败，没有找到二维码。"}
        print(f"qrcode: {qrcode}")
        return {"success": True, "qrcode": qrcode, "app_id": app_id, "app_appointment_id": app_appointment_id}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}
    
@app.get("/api/get_temp_qrcode")
def get_temp_qrcode(resource_id: int, start_time: str):
    try:
        print(f"准备获取临时码: resource_id: {resource_id}, start_time: {start_time}")
        qrcode = reserve.get_temp_qrcode(resource_id, start_time)
        return {"success": True, "qrcode": qrcode}
    except Exception as e:
        return {"success": False, "message": f"获取临时码发生错误: {str(e)}"}
    
@app.get("/api/cancel_reservation")
def cancel_reservation(appointment_id: str, hall_appointment_data_id: str):
    try:
        result = reserve.cancel_reservation(appointment_id, hall_appointment_data_id)
        return {"success": True, "result": result}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}