import json
import datetime
import requests
from logging import getLogger
from dotenv import load_dotenv
from os import getenv

load_dotenv()

logger = getLogger(__name__)

class PKUReserve:
    def __init__(self):
        self.s = requests.Session()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
        }
        self.token = None

    def login(self, username, password):
        try:
            r = self.s.get("https://wproc.pku.edu.cn/api/login/main")
            r = self.s.post(
                "https://iaaa.pku.edu.cn/iaaa/oauthlogin.do",
                data={
                    "appid": "wproc",
                    "userName": username,
                    "password": password,
                    "redirUrl": "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/",
                },
            )
            self.token = json.loads(r.text)["token"]
            return self.token
        except Exception as e:
            logger.error(f"Login failed: {e}")
            return None
                             

    def get_bus_info(self, date=None):
        '''
        Get all bus available on a specific date.
        '''
        if date is None:
            date = datetime.datetime.now().strftime("%Y-%m-%d")  # Default to today
        r = self.s.get(
            f"https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token={self.token}"
        )
        date = datetime.datetime.now().strftime("%Y-%m-%d")

        r = self.s.get(
            f"https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=%{date}&p=1&page_size=0"
        )
        self.bus_info = json.loads(r.text)["d"]["list"]

        return self.bus_info
    
    def get_available_bus(self, date, cur_time, prev_interval=10, next_interval=600):
        '''
        Decide which bus to reserve.

        Args:
        @date: The date to reserve, in the format of "YYYY-MM-DD".
        @cur_time: The current time, in the format of "HH:MM".
        @prev_interval: The interval to reserve the previous bus, in minutes.
        @next_interval: The interval to reserve the next bus, in minutes.

        Returns:
        A dictionary containing the information of the bus to reserve.
        '''
        all_bus_info = self.get_bus_info(date)
        possible_expired_bus = {}
        possible_future_bus = {}
        cur_time = datetime.datetime.strptime(cur_time, "%H:%M")
        for bus_info in all_bus_info:
            id = bus_info["id"]
            name = bus_info["name"]
            for bus_item in list(bus_info["table"].values())[0]:
                if bus_item['abscissa'] != date or bus_item['row']['margin'] == 0:
                    continue
                time_id = bus_item['time_id']
                start_time = bus_item['yaxis']
                # Calculate the time difference, with sign
                start_time = datetime.datetime.strptime(start_time, "%H:%M")
                time_diff = (start_time - cur_time).total_seconds() / 60

                # Here we assume that there is at most one bus in the next interval
                # and at most one bus in the previous interval
                if 0 < time_diff <= next_interval:
                    possible_future_bus[id] = {
                        "name": name,
                        "time_id": time_id,
                        "start_time": start_time.strftime("%H:%M")
                    }
                elif 0 >= time_diff >= -prev_interval:
                    possible_expired_bus[id] = {
                        "name": name,
                        "time_id": time_id,
                        "start_time": start_time.strftime("%H:%M")
                    }
                    
        return {"possible_expired_bus": possible_expired_bus, "possible_future_bus": possible_future_bus}
    
    def reserve(self, resource_id, period, sub_resource_id, date=None):
        '''
        Reserve a bus.
        '''
        if date is None:
            date = datetime.datetime.now().strftime("%Y-%m-%d")
        r = self.s.get(
            "https://wproc.pku.edu.cn/site/reservation/launch",
            data={
                "resource_id": resource_id,
                "data": f'[{{"date": "{date}", "period": {period}, "sub_resource_id": {sub_resource_id}}}]',
            },
        )
        return json.loads(r.text)
    
    def reserve_and_get_qrcode(self, resource_id, period, sub_resource_id, date=None):
        '''
        Reserve a bus and get the QR code.
        '''
        if date is None:
            date = datetime.datetime.now().strftime("%Y-%m-%d")
        r = self.s.get(
            "https://wproc.pku.edu.cn/site/reservation/launch",
            data={
                "resource_id": resource_id,
                "data": f'[{{"date": "{date}", "period": {period}, "sub_resource_id": {sub_resource_id}}}]',
            },
        )
        r = self.s.get(
            "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc",
        )
        apps = json.loads(r.text)["d"]["data"]
        print(f"Apps: {apps}")
        app_0 = apps[0]
        app_id = app_0["id"]
        app_appointment_id = app_0["hall_appointment_data_id"]
        r = self.s.get(
            f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&id=${app_id}&hall_appointment_data_id=${app_appointment_id}"
        )
        return r.text
    
    def get_apps(self, status=2, sort_time=True, sort="asc"):
        '''
        Get all appointments.
        '''
        r = self.s.get(
            f"https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status={status}&sort_time={sort_time}&sort={sort}"
        )
        return json.loads(r.text)["d"]["data"]
    
    def cancel_app(self, appointment_id, hall_appointment_data_id):
        '''
        Cancel an appointment.
        '''
        r = self.s.post(
            "https://wproc.pku.edu.cn/site/reservation/single-time-cancel",
            data={
                "appointment_id": appointment_id,
                "data_id[0]": hall_appointment_data_id,
            },
        )
        return json.loads(r.text)
    
if __name__ == "__main__":
    pku = PKUReserve()
    pku.login(getenv("PKU_USERNAME"), getenv("PKU_PASSWORD"))
    print(f"Login successfully with token: {pku.token}")
    if not pku.token:
        print("Login failed.")
    bus_info = pku.get_bus_info()
    available_bus = pku.get_available_bus(datetime.datetime.now().strftime("%Y-%m-%d"), datetime.datetime.now().strftime("%H:%M"))
    qr_code = pku.reserve_and_get_qrcode(7, 47, 0)
    print(f"QR code: {qr_code}")
