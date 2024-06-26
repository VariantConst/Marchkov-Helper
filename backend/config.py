# backend/config.py

data_route_urls = {
    "to_yanyuan": {
        "新校区→燕园校区": "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=4",
        "200号校区→新校区→西二旗→肖家河→燕园校区": "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=3",
        "200号校区→新校区→燕园校区": "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=2"
    },
    "to_changping": {
        "燕园校区→新校区": "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=7",
        "燕园校区→新校区→200号校区": "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=6",
        "燕园校区→肖家河→西二旗→新校区→200号校区": "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=5"
    }
}

# Add other configuration settings here as needed
TIMEOUT_LONG = 120000  # 2 minutes in milliseconds
TIMEOUT_MEDIUM = 60000  # 1 minute in milliseconds
TIMEOUT_SHORT = 30000  # 30 seconds in milliseconds

USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1"
LOCALE = "zh-CN"
TIMEZONE = "Asia/Shanghai"
GEOLOCATION = {"latitude": 39.9042, "longitude": 116.4074}  # Beijing coordinates