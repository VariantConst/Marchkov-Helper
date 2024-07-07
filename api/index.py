import json
from datetime import datetime, timedelta
import requests
import logging
from dotenv import load_dotenv
from os import getenv
from fastapi import FastAPI, HTTPException
import pytz
from fastapi.middleware.cors import CORSMiddleware

# 从.env.local读取环境变量
load_dotenv(dotenv_path=".env.local")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# 更新CORS设置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # 允许前端开发服务器的域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

s = requests.Session()
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
}
token = None
bus_info = None


def get_beijing_time():
    return datetime.now(pytz.timezone('Asia/Shanghai'))#.replace(hour=8, minute=39) + timedelta(days=1)


def login(username: str, password: str):
    global token, bus_info, s
    try:
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
        logger.info(f"用户 {username} 登录成功。")

        # 获取班车信息
        try:
            bus_info = get_bus_info(get_beijing_time())
            logger.info("获取班车信息成功。")
        except Exception as e:
            logger.error(f"获取班车信息失败: {e}")

        return token
    except Exception as e:
        logger.error(f"登录失败: {e}")
        return None


def get_bus_info(current_time: datetime):
    global token
    try:
        date = current_time.strftime("%Y-%m-%d")
        r = s.get(
            f"https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token={token}"
        )
        r = s.get(
            f"https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=%{date}&p=1&page_size=0"
        )
        bus_info = json.loads(r.text)["d"]["list"]
        logger.info(f"获取班车信息成功。")
        return bus_info
    except Exception as e:
        logger.error(f"获取班车信息失败: {e}")
        return None


def get_bus_direction(current_time: datetime):
    '''未指定预约方向时，根据环境变量和当前时间获取应该预约的班车方向。'''
    CRITICAL_TIME = datetime.strptime(getenv("NEXT_PUBLIC_CRITICAL_TIME"), "%H:%M")
    FLAG_MORNING_TO_YANYUAN = getenv("NEXT_PUBLIC_FLAG_MORNING_TO_YANYUAN") == "true"
    is_to_yanyuan = FLAG_MORNING_TO_YANYUAN if current_time.time() < CRITICAL_TIME else not FLAG_MORNING_TO_YANYUAN
    return is_to_yanyuan


def get_temp_qrcode(resource_id: int, start_time: str):
    '''获取临时码。'''
    global s
    r = s.get(
        f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id={resource_id}&text={start_time}",
    )
    temp_qrcode = json.loads(r.text)["d"]["code"]
    logger.info(f"已为班车 {resource_id}，发车时刻 {start_time} 获取临时码：{temp_qrcode}")
    return temp_qrcode


def reserve_and_get_qrcode(resource_id: int, date: str, period: int, start_time: str):
    logger.info(f"尝试预约班车: resource_id {resource_id}, date {date}, period {period}, start_time {start_time}")
    r = s.get(
        "https://wproc.pku.edu.cn/site/reservation/launch",
        data={
            "resource_id": resource_id,
            "data": f'[{{"date": "{date}", "period": {period}, "sub_resource_id": 0}}]',
        },
    )
    logger.info(f"预约结果: {r.text}")
    r = s.get(
        "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc",
    )
    apps = json.loads(r.text)["d"]["data"]

    for app in apps:
        # 检查是否是刚刚预约的班车
        expected_app_tim = get_beijing_time().strftime("%Y-%m-%d") + " " + start_time
        if app["resource_id"] != resource_id or app["appointment_tim"].strip() != expected_app_tim:
            continue
        logger.info(f"找到了符合条件 expected_app_tim {expected_app_tim} 的预约: 具有 id {app['id']} 和 hall_appointment_data_id {app['hall_appointment_data_id']}")
        app_id = app["id"]
        app_appointment_id = app["hall_appointment_data_id"]
        r = s.get(
            f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?id={app_id}&type=0&hall_appointment_data_id={app_appointment_id}"
        )
        logger.info(f"获取二维码结果: {r.text}")
        qrcode = json.loads(r.text)["d"]["code"]

        return qrcode, app_id, app_appointment_id


def reserve_bus(current_time: datetime, is_to_yanyuan: bool):
    '''
    预约给定方向的班车。

    Args:
        - current_time: 当前时间。
        - is_to_yanyuan: 是否预约去燕园的班车。

    Returns:
        - success: 预约函数是否成功执行完毕。
        - message: 预约失败时的错误信息。
    '''
    global bus_info, s
    logger.info(f"尝试预约{'去燕园' if is_to_yanyuan else '回昌平'}的班车。")
    try:
        # 遍历班车信息，找到符合条件的班车
        for bus in bus_info:
            resource_id = bus["id"]
            route_name = bus["name"]

            # 筛选方向
            if resource_id in [2, 4] == is_to_yanyuan:
                continue
            
            for period in next(iter(bus["table"].values())):
                time_id = period["time_id"] # 班车资源ID，如7
                date = period["date"] # 日期，如"2024-06-29"
                start_time = period["yaxis"] # 发车时刻，如"18:30"
                margin = period["row"]["margin"] # 余量

                if margin == 0 or date != current_time.strftime("%Y-%m-%d"):
                    continue
                
                # 计算时间差（不含日期）
                naive_datetime = datetime.strptime(date + " " + start_time, "%Y-%m-%d %H:%M")
                aware_datetime = current_time.tzinfo.localize(naive_datetime) # 班车发车时间
                time_diff_with_sign = (aware_datetime - current_time).total_seconds() // 60
                # print(f"找到班车 {route_name} {start_time}，时间差为 {time_diff_with_sign} 分钟。")
                has_expired_bus = -int(getenv("PREV_INTERVAL")) < time_diff_with_sign < 0
                has_future_bus = 0 < time_diff_with_sign < int(getenv("NEXT_INTERVAL"))
                if not has_expired_bus and not has_future_bus:
                    continue

                logger.info(f"找到符合条件的班车: {route_name} {start_time}，时间差为 {time_diff_with_sign} 分钟。")

                # 优先获取临时码
                if has_expired_bus:
                    logger.info(f"班车 {route_name} 已过期 {time_diff_with_sign} 分钟，尝试获取临时码。")
                    temp_qrcode = get_temp_qrcode(resource_id, start_time)
                    return {
                        "success": True,
                        "message": "",
                        "qrcode_type": "临时码",
                        "route_name": route_name,
                        "start_time": start_time,
                        "qrcode": temp_qrcode,
                    }
                # 按照时间顺序获取乘车码
                elif has_future_bus:
                    logger.info(f"班车 {route_name} 将于 {time_diff_with_sign} 分钟后发车，尝试获取乘车码。")
                    qrcode, app_id, app_appointment_id = reserve_and_get_qrcode(resource_id, date, time_id, start_time)
                        
                    return {
                        "success": True,
                        "message": "",
                        "qrcode_type": "乘车码",
                        "route_name": route_name,
                        "start_time": start_time,
                        "qrcode": qrcode,
                        "app_id": app_id,
                        "app_appointment_id": app_appointment_id,
                    }
        
        logger.info("没有符合条件的班车。")
        return {"success": False, "message": "没有符合条件的班车。"}
    except Exception as e:
        logger.error(f"预约失败: {e}")
        return {"success": False, "message": str(e)}


@app.get("/api/auth")
async def auth(password: str):
    '''
    网页登录验证。首先验证前端输入的登录密码，然后调用login函数进行登录。

    Args:
        - password: 用户指定的登录密码，默认为"123456"。
    
    Returns:
        - success: 是否登录成功。
        - message: 登录失败时的错误信息。
        - username: 登录成功时的用户名。
    '''
    try:
        USER_PASSWORD = getenv("USER_PASSWORD")
        PKU_USERNAME = getenv("PKU_USERNAME")
        PKU_PASSWORD = getenv("PKU_PASSWORD")
        # 验证网页登录密码
        if USER_PASSWORD and password != USER_PASSWORD:
            raise HTTPException(status_code=401, detail="网页登录密码错误。请检查环境变量 USER_PASSWORD。")
        token = login(PKU_USERNAME, PKU_PASSWORD)
        if token:
            return {"success": True, "message": "登录成功", "username": PKU_USERNAME}
        else:
            raise HTTPException(status_code=401, detail="登录失败。请检查环境变量 PKU_USERNAME 和 PKU_PASSWORD。")
    except Exception as e:
        logger.error(f"登录失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/reserve")
async def reserve(is_to_yanyuan: bool = True):
    '''
    完成预约。默认按照环境变量规定的方向进行预约。

    Args:
        - is_to_yanyuan: 是否预约去燕园的班车，默认为True。

    Returns:
        - success: 预约函数是否成功执行完毕。
        - message: 预约失败时的错误信息。
        - is_to_yanyuan: 预约结果是否是去燕园的班车。
        - qrcode_type: 二维码类型（乘车码/临时码）。
        - route_name: 班车路线名称。
        - start_time: 班车发车时间。
        - qrcode: 二维码图片的Base64编码。
        - app_id: 预约ID。
        - app_appointment_id: 预约数据ID。
    '''
    try:
        global token
        if not token:
            raise HTTPException(status_code=401, detail="未登录，请先进行认证。")
        
        current_time = get_beijing_time()
        if not is_to_yanyuan:
            is_to_yanyuan = get_bus_direction(current_time)

        # 尝试预约给定方向的班车
        reservation = reserve_bus(current_time, is_to_yanyuan)
        if not reservation["success"]:
            is_to_yanyuan = not is_to_yanyuan
            reservation = reserve_bus(current_time, is_to_yanyuan)
            if not reservation["success"]:
                raise HTTPException(status_code=404, detail="当前没有可预约的班车。")
        
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
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/api/cancel")
async def cancel_reservation(app_id: int, app_appointment_id: int):
    try:
        r = s.post(
            "https://wproc.pku.edu.cn/site/reservation/single-time-cancel",
            data={
                "appointment_id": app_id,
                "data_id[0]": app_appointment_id,
            },
        )
        logger.info(f"取消预约结果: {r.text}")
        result = json.loads(r.text)
        if result.get("e") == 0:
            return {"success": True, "message": "预约取消成功"}
        else:
            raise HTTPException(status_code=400, detail=result.get("m", "预约取消失败"))
    except Exception as e:
        logger.error(f"取消预约失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))