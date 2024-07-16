import requests
from datetime import datetime, timedelta

headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
}

session = None
token = None
bus_info = None
last_access_time = None
SESSION_TIMEOUT = timedelta(hours=1)

def init_session():
    global session, last_access_time, token, bus_info
    session = requests.Session()
    session.headers.update(headers)
    last_access_time = datetime.now()
    token = None
    bus_info = None
    return session

def get_session():
    global session, last_access_time
    current_time = datetime.now()
    
    if session is None or (last_access_time and current_time - last_access_time > SESSION_TIMEOUT):
        return init_session()
    
    last_access_time = current_time
    return session

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