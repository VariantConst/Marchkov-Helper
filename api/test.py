import json
import datetime
import requests
from logging import getLogger
from dotenv import load_dotenv
from os import getenv
from fastapi import FastAPI
from pytz import timezone

# 从.env.local读取环境变量
load_dotenv(dotenv_path="../.env.local")

logger = getLogger(__name__)

app = FastAPI()

s = requests.Session()
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
}

username = "1700011620"
password = "xyfpku2017"

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

r = s.get(
    f"https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token={token}"
)

date = datetime.datetime.now().strftime("%Y-%m-%d")

r = s.get(
    f"https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=%{date}&p=1&page_size=0"
)
resources = json.loads(r.text)["d"]["list"]

r = s.get(
    "https://wproc.pku.edu.cn/site/reservation/launch",
    data={
        "resource_id": "7",
        "data": '[{"date": "2024-07-05", "period": 46, "sub_resource_id": 0}]',
    },
)

r = s.get(
    "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc",
)
apps = json.loads(r.text)["d"]["data"]

app_0 = apps[0]
app_id = app_0["id"]
app_appointment_id = app_0["hall_appointment_data_id"]
r = s.get(
    f"https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&id=${app_id}&hall_appointment_data_id=${app_appointment_id}"
)
print(r.text)
