from fastapi import FastAPI
from dotenv import load_dotenv
from .reserve import PKUReserve
from os import getenv
import datetime

app = FastAPI()

load_dotenv()

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
    reserve = PKUReserve()
    reserve.login(getenv("PKU_USERNAME"), getenv("PKU_PASSWORD"))
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    try:
        qrcode = reserve.reserve_and_get_qrcode(resource_id, period, sub_resource_id, date)
        return {"success": True, "qrcode": qrcode}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}