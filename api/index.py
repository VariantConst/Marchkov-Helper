import json
import datetime
import requests
from logging import getLogger
from dotenv import load_dotenv
from os import getenv
from fastapi import FastAPI
from pytz import timezone

# 从.env.local读取环境变量
load_dotenv(dotenv_path=".env.local")

logger = getLogger(__name__)

app = FastAPI()

s = requests.Session()
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
}
token = None

def get_beijing_time():
    return datetime.datetime.now(timezone('Asia/Shanghai'))
    # return datetime.datetime.now(timezone('Asia/Shanghai')).replace(hour=17, minute=50)

def login(username, password):
    global token
    try:
        r = s.get("https://wproc.pku.edu.cn/api/login/main")
        r = s.post(
            "https://iaaa.pku.edu.cn/iaaa/oauthlogin.do",
            data={
                "appid": "wproc",
                "userName": username,
                "password": password,
                "redirUrl": "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/",
            },
        )
        token = json.loads(r.text)["token"]
        return token
    except Exception as e:
        logger.error(f"Login failed: {e}")
        return None

def get_bus_info(date=None):
    if date is None:
        date = datetime.datetime.now().strftime("%Y-%m-%d")
    r = s.get(
        f"https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token={token}"
    )
    r = s.get(
        f"https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=%{date}&p=1&page_size=0"
    )
    return json.loads(r.text)["d"]["list"]

def get_available_bus(date, cur_time, prev_interval=None, next_interval=None):
    if prev_interval is None:
        prev_interval = int(getenv("PREV_INTERVAL", 10))
    if next_interval is None:
        next_interval = int(getenv("NEXT_INTERVAL", 30))
    print(f"开始获取 {date} {cur_time} 的车次信息")
    all_bus_info = get_bus_info(date)
    possible_expired_bus = {}
    possible_future_bus = {}
    cur_time = datetime.datetime.strptime(cur_time, "%H:%M")
    
    min_future_time_diff = {}

    for bus_info in all_bus_info:
        id = bus_info["id"]
        name = bus_info["name"]
        if int(id) not in [2, 4, 5, 6, 7]:
            continue
        for bus_item in list(bus_info["table"].values())[0]:
            if bus_item['abscissa'] != date or bus_item['row']['margin'] == 0:
                continue
            time_id = bus_item['time_id']
            start_time = bus_item['yaxis']
            start_time = datetime.datetime.strptime(start_time, "%H:%M")
            time_diff = (start_time - cur_time).total_seconds() / 60
            if 0 < time_diff <= next_interval:
                if id not in min_future_time_diff or time_diff < min_future_time_diff[id]['time_diff']:
                    min_future_time_diff[id] = {
                        'time_diff': time_diff,
                        'name': name,
                        'time_id': time_id,
                        'start_time': start_time.strftime("%H:%M")
                    }
            elif 0 >= time_diff >= -prev_interval:
                possible_expired_bus[id] = {
                    "name": name,
                    "time_id": time_id,
                    "start_time": start_time.strftime("%H:%M")
                }
    
    for id, bus_info in min_future_time_diff.items():
        possible_future_bus[id] = {
            "name": bus_info['name'],
            "time_id": bus_info['time_id'],
            "start_time": bus_info['start_time']
        }

    print(f"可选的过期车次: {possible_expired_bus}，可选的未来车次: {possible_future_bus}")
    return {"possible_expired_bus": possible_expired_bus, "possible_future_bus": possible_future_bus}

def reserve_and_get_qrcode(resource_id, period, sub_resource_id, date=None, start_time=None):
    if date is None:
        date = datetime.datetime.now().strftime("%Y-%m-%d")
    
    print(f"准备预约: resource_id: {resource_id}, period: {period}, sub_resource_id: {sub_resource_id}, date: {date}, start_time: {start_time}")

    r = s.get(
        "https://wproc.pku.edu.cn/site/reservation/launch",
        data={
            "resource_id": resource_id,
            "data": f'[{{"date": "{date}", "period": {period}, "sub_resource_id": {sub_resource_id}}}]',
        },
    )
    print(f"预约结果: {r.text}")
    r = s.get(
        "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc",
    )
    apps = json.loads(r.text)["d"]["data"]

    for app in apps:
        # 检查是否是刚刚预约的班车
        expected_app_tim = get_beijing_time().strftime("%Y-%m-%d") + " " + start_time
        if app["resource_id"] != resource_id or app["appointment_tim"].strip() != expected_app_tim:
            continue
        app_id = app["id"]
        app_appointment_id = app["hall_appointment_data_id"]
        r = s.get(
            f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&id=${app_id}&hall_appointment_data_id=${app_appointment_id}"
        )
        print(r.text)
        return json.loads(r.text)["d"]["code"], app_id, app_appointment_id
    else:
        print("预约失败，没有找到二维码。")
        return None, None, None

def get_temp_qrcode(resource_id, start_time):
    r = s.get(
        f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id={resource_id}&text={start_time}",
    )
    return json.loads(r.text)["d"]["code"]

def cancel_reservation(appointment_id, hall_appointment_data_id):
    r = s.post(
        "https://wproc.pku.edu.cn/site/reservation/single-time-cancel",
        data={
            "appointment_id": appointment_id,
            "data_id[0]": hall_appointment_data_id,
        },
    )
    print(f"取消预约结果: {r.text}")
    return json.loads(r.text)

@app.get("/api/login")
def api_login():
    try:
        token = login(getenv("PKU_USERNAME"), getenv("PKU_PASSWORD"))
        if token:
            return {"success": True, "username": getenv("PKU_USERNAME")}
        else:
            return {"success": False, "message": "登录失败，请检查用户名和密码"}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}

@app.get("/api/get_available_bus")
def api_get_available_bus():
    login(getenv("PKU_USERNAME"), getenv("PKU_PASSWORD"))
    beijing_time = get_beijing_time()
    date = beijing_time.strftime("%Y-%m-%d")
    cur_time = beijing_time.strftime("%H:%M")
    try:
        possible_bus = get_available_bus(date, cur_time)
        return {"success": True, "possible_bus": possible_bus}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}

@app.get("/api/reserve_and_get_qrcode")
def api_reserve_and_get_qrcode(resource_id: int, period: str, sub_resource_id: int, start_time: str):
    print(f"resource_id: {resource_id}, period: {period}, sub_resource_id: {sub_resource_id}")
    date = get_beijing_time().strftime("%Y-%m-%d")
    try:
        qrcode, app_id, app_appointment_id = reserve_and_get_qrcode(resource_id, period, sub_resource_id, date, start_time)
        if qrcode is None:
            return {"success": False, "message": "预约失败，没有找到二维码。"}
        print(f"qrcode: {qrcode}")
        return {"success": True, "qrcode": qrcode, "app_id": app_id, "app_appointment_id": app_appointment_id}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}

@app.get("/api/get_temp_qrcode")
def api_get_temp_qrcode(resource_id: int, start_time: str):
    try:
        print(f"准备获取临时码: resource_id: {resource_id}, start_time: {start_time}")
        qrcode = get_temp_qrcode(resource_id, start_time)
        return {"success": True, "qrcode": qrcode}
    except Exception as e:
        return {"success": False, "message": f"获取临时码发生错误: {str(e)}"}

@app.get("/api/cancel_reservation")
def api_cancel_reservation(appointment_id: str, hall_appointment_data_id: str):
    try:
        result = cancel_reservation(appointment_id, hall_appointment_data_id)
        return {"success": True, "result": result}
    except Exception as e:
        return {"success": False, "message": f"发生错误: {str(e)}"}