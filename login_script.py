import requests
import os
import json
import pickle
import time
from flutter_secure_storage import FlutterSecureStorage

COOKIES_FILE = "cookies.pkl"
CREDENTIALS_KEY = "user_credentials"
storage = FlutterSecureStorage()

def load_cookies():
    if os.path.exists(COOKIES_FILE):
        with open(COOKIES_FILE, "rb") as f:
            return pickle.load(f)
    return None

def save_cookies(cookies):
    with open(COOKIES_FILE, "wb") as f:
        pickle.dump(cookies, f)

async def save_credentials(username, password):
    credentials = json.dumps({"username": username, "password": password})
    await storage.write(key=CREDENTIALS_KEY, value=credentials)

async def load_credentials():
    credentials = await storage.read(key=CREDENTIALS_KEY)
    if credentials:
        return json.loads(credentials)
    return None

async def clear_credentials():
    await storage.delete(key=CREDENTIALS_KEY)

async def login():
    s = requests.Session()
    s.headers.update(headers)
    
    cookies = load_cookies()
    if cookies:
        s.cookies.update(cookies)
        if check_login_status(s):
            print("使用已保存的 cookies 登录成功")
            print("Cookies:", s.cookies.get_dict())
            return s
    
    print("使用用户名密码登录")
    credentials = await load_credentials()
    if credentials:
        username = credentials["username"]
        password = credentials["password"]
    else:
        username = os.environ["PKU_USERNAME"]
        password = os.environ["PKU_PASSWORD"]
    
    print(f"尝试使用用户名 {username} 登录")
    
    r = s.get("https://wproc.pku.edu.cn/api/login/main")
    print("获取登录页面响应:", r.status_code)
    
    r = s.post(
        "https://iaaa.pku.edu.cn/iaaa/oauthlogin.do",
        data={
            "appid": "wproc",
            "userName": username,
            "password": password,
            "redirUrl": "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/",
        },
    )
    
    print("登录请求响应:", r.text)
    token = json.loads(r.text)["token"]
    print("登录成功，token是", token)
    
    r = s.get(
        f"https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand={time.time()}&token={token}"
    )
    print("获取登录重定向响应:", r.status_code)
    
    save_cookies(s.cookies)
    await save_credentials(username, password)
    print("新的 cookies 已保存")
    print("Cookies:", s.cookies.get_dict())
    return s

async def logout():
    await clear_credentials()
    if os.path.exists(COOKIES_FILE):
        os.remove(COOKIES_FILE)
    print("已清除用户凭据和 cookies")

def check_login_status(session):
    try:
        r = session.get("https://wproc.pku.edu.cn/v2/reserve/", allow_redirects=False)
        return r.status_code == 200
    except:
        return False

def fetch_data(session, date):
    r = session.get(
        f"https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time={date}&p=1&page_size=0"
    )
    resources = json.loads(r.text)["d"]["list"]
    return resources

# 使用示例
session = login()
date = "2024-09-21"
resources = fetch_data(session, date)
print(resources)