import json
from datetime import datetime
import logging
import pytz
import requests
from .config import settings


logger = logging.getLogger(__name__)


def get_beijing_time():
    return datetime.now(pytz.timezone('Asia/Shanghai'))


def login(username: str, password: str, session: requests.Session):
    try:
        r = session.get("https://wproc.pku.edu.cn/api/login/main")
        r = session.post(
            "https://iaaa.pku.edu.cn/iaaa/oauthlogin.do",
            data={
                "appid": "wproc",
                "userName": username,
                "password": password,
                "redirUrl": "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/",
            },
        )
        print(f"登录结果: {r.text}")
        token = json.loads(r.text)["token"]
        logger.info(f"用户 {username} 登录成功。")
        return token
    except Exception as e:
        logger.error(f"登录失败: {e}")
        return None


def get_bus_info(current_time: datetime, token: str, session: requests.Session):
    try:
        date = current_time.strftime("%Y-%m-%d")
        r = session.get(
            f"https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token={token}"
        )
        r = session.get(
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
    CRITICAL_TIME = datetime.strptime(settings.CRITICAL_TIME, "%H").time()
    is_to_yanyuan = settings.FLAG_MORNING_TO_YANYUAN if current_time.time() < CRITICAL_TIME else not settings.FLAG_MORNING_TO_YANYUAN
    logger.info(f"因为当前时间 {current_time.time()} {'早于' if current_time.time() < CRITICAL_TIME else '晚于'} {CRITICAL_TIME}，所以预约{'去燕园' if is_to_yanyuan else '回昌平'}的班车。")
    return is_to_yanyuan


def get_temp_qrcode(resource_id: int, start_time: str, session: requests.Session):
    '''获取临时码。'''
    try:
        r = session.get(
            f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id={resource_id}&text={start_time}",
        )
        print(f"获取临时码结果: {r.text}")
        temp_qrcode = json.loads(r.text)["d"]["code"]
        logger.info(f"已为班车 {resource_id}，发车时刻 {start_time} 获取临时码：{temp_qrcode}")
        return temp_qrcode
    except Exception as e:
        logger.error(f"获取临时码失败: {e}")
        return None


def reserve_and_get_qrcode(resource_id: int, date: str, period: int, start_time: str, session: requests.Session):
    logger.info(f"尝试预约班车: resource_id {resource_id}, date {date}, period {period}, start_time {start_time}")
    try:
        r = session.get(
            "https://wproc.pku.edu.cn/site/reservation/launch",
            data={
                "resource_id": resource_id,
                "data": f'[{{"date": "{date}", "period": {period}, "sub_resource_id": 0}}]',
            },
        )
        logger.info(f"预约结果: {r.text}")
        r = session.get(
            "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc",
        )
        apps = json.loads(r.text)["d"]["data"]

        for app in apps:
            expected_app_tim = get_beijing_time().strftime("%Y-%m-%d") + " " + start_time
            if app["resource_id"] != resource_id or app["appointment_tim"].strip() != expected_app_tim:
                continue
            logger.info(f"找到了符合条件 expected_app_tim {expected_app_tim} 的预约: 具有 id {app['id']} 和 hall_appointment_data_id {app['hall_appointment_data_id']}")
            app_id = app["id"]
            app_appointment_id = app["hall_appointment_data_id"]
            r = session.get(
                f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?id={app_id}&type=0&hall_appointment_data_id={app_appointment_id}"
            )
            logger.info(f"获取二维码结果: {r.text}")
            qrcode = json.loads(r.text)["d"]["code"]

            return qrcode, app_id, app_appointment_id
    except Exception as e:
        logger.error(f"预约并获取二维码失败: {e}")
        return None, None, None


def reserve_bus(current_time: datetime, is_to_yanyuan: bool, bus_info: list, session: requests.Session):
    '''
    预约给定方向的班车。

    Args:
        - current_time: 当前时间。
        - is_to_yanyuan: 是否预约去燕园的班车。
        - bus_info: 班车信息列表。
        - session: requests.Session 对象。

    Returns:
        - success: 预约函数是否成功执行完毕。
        - message: 预约失败时的错误信息。
    '''
    logger.info(f"尝试预约{'去燕园' if is_to_yanyuan else '回昌平'}的班车。")
    try:
        for bus in bus_info:
            resource_id = bus["id"]
            route_name = bus["name"]

            if not (resource_id in [2, 4] and is_to_yanyuan or resource_id in [5, 6, 7] and not is_to_yanyuan):
                continue
            
            for period in next(iter(bus["table"].values())):
                time_id = period["time_id"]
                date = period["date"]
                start_time = period["yaxis"]
                margin = period["row"]["margin"]

                if margin == 0 or date != current_time.strftime("%Y-%m-%d"):
                    continue
                
                naive_datetime = datetime.strptime(date + " " + start_time, "%Y-%m-%d %H:%M")
                aware_datetime = current_time.tzinfo.localize(naive_datetime)
                time_diff_with_sign = (aware_datetime - current_time).total_seconds() / 60
                has_expired_bus = -settings.PREV_INTERVAL < time_diff_with_sign < 0
                has_future_bus = 0 <= time_diff_with_sign < settings.NEXT_INTERVAL
                if not has_expired_bus and not has_future_bus:
                    continue

                logger.info(f"找到符合条件的班车: {route_name} {start_time}，时间差为 {time_diff_with_sign} 分钟。")

                if has_expired_bus:
                    logger.info(f"班车 {route_name} 已过期 {time_diff_with_sign} 分钟，尝试获取临时码。")
                    temp_qrcode = get_temp_qrcode(resource_id, start_time, session)
                    return {
                        "success": True,
                        "message": "",
                        "qrcode_type": "临时码",
                        "route_name": route_name,
                        "start_time": start_time,
                        "qrcode": temp_qrcode,
                    }
                elif has_future_bus:
                    logger.info(f"班车 {route_name} 将于 {time_diff_with_sign} 分钟后发车，尝试获取乘车码。")
                    qrcode, app_id, app_appointment_id = reserve_and_get_qrcode(resource_id, date, time_id, start_time, session)
                        
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


def cancel_reservation(app_id: int, app_appointment_id: int, session: requests.Session):
    try:
        r = session.post(
            "https://wproc.pku.edu.cn/site/reservation/single-time-cancel",
            data={
                "appointment_id": app_id,
                "data_id[0]": app_appointment_id,
            },
        )
        logger.info(f"取消 appointment_id {app_id} 的预约结果: {r.text}")
        result = json.loads(r.text)
        if result.get("e") == 0:
            return {"success": True, "message": "预约取消成功"}
        else:
            return {"success": False, "message": result.get("m", "预约取消失败")}
    except Exception as e:
        logger.error(f"取消预约失败: {e}")
        return {"success": False, "message": str(e)}