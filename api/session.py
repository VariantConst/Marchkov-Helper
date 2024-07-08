import requests
from fastapi import Depends

headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
}

session = None
token = None
bus_info = None

def init_session():
    global session
    if session is None:
        session = requests.Session()
        session.headers.update(headers)
    return session

def get_session():
    return init_session()

# 这个函数将被用作依赖
def get_db_session():
    return get_session()

def update_token(new_token):
    global token
    token = new_token

def update_bus_info(new_bus_info):
    global bus_info
    bus_info = new_bus_info

def get_token():
    return token

def get_stored_bus_info():
    return bus_info