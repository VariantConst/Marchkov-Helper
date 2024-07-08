import requests
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class ExpiringSession:
    def __init__(self, expiration_time=timedelta(minutes=1)):
        self.session = requests.Session()
        self.expiration_time = expiration_time
        self.last_used = datetime.now()
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
        }
        self.session.headers.update(self.headers)
        self.token = None
        self.bus_info = None

    def get_session(self):
        current_time = datetime.now()
        if current_time - self.last_used > self.expiration_time:
            logger.info("Session expired. Creating a new session.")
            self.session = requests.Session()
            self.session.headers.update(self.headers)
            self.token = None
            self.bus_info = None
        self.last_used = current_time
        return self.session

    def update_token(self, token):
        self.token = token

    def update_bus_info(self, bus_info):
        self.bus_info = bus_info

global_session = ExpiringSession()

def get_db_session():
    return global_session.get_session()