# backend/services.py

from models import UserCredentials, QRCodeResult, ReservationResult
from utils import login, get_bus_time, make_reservation, get_qr_code, get_temporary_qr_code
from config import data_route_urls
from playwright.async_api import async_playwright
import logging
import asyncio
from datetime import datetime

logger = logging.getLogger(__name__)

async def get_qr_code_service(credentials: UserCredentials) -> QRCodeResult:
    async with async_playwright() as p:
        browser_context = await setup_browser_context(p)
        
        try:
            login_success = await login(browser_context, credentials.username, credentials.password)
            if not login_success:
                return QRCodeResult(success=False, reservations=[], message="Failed to login")

            routes = data_route_urls["to_changping" if credentials.is_return else "to_yanyuan"]
            credentials.target_time = credentials.target_time or datetime.now().strftime("%H:%M")

            bus_info = [get_bus_time(browser_context, route_name, route_url, credentials.target_time) 
                        for (route_name, route_url) in routes.items()]
            all_bus_info = await asyncio.gather(*bus_info)
            all_bus_info = [bus_info for bus_info in all_bus_info if bus_info]  # Remove None values

            has_expired_bus = any([bus_info[0] for bus_info in all_bus_info])
            logging.info(f"Expired bus within the past 10 minutes: {has_expired_bus}")

            if has_expired_bus:
                return await handle_expired_buses(all_bus_info)
            else:
                return await handle_future_reservation(all_bus_info)

        finally:
            await browser_context.close()

async def setup_browser_context(p):
    iphone_12_pro = p.devices['iPhone 12 Pro']
    browser_options = {
        **iphone_12_pro,
        "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1",
        "locale": "zh-CN",
        "timezone_id": "Asia/Shanghai",
        "geolocation": {"latitude": 39.9042, "longitude": 116.4074},
        "permissions": ["geolocation"]
    }
    browser = await p.webkit.launch(headless=True)
    context = await browser.new_context(**browser_options)
    await context.add_init_script("""
        Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
        if ('getBattery' in navigator) {
            navigator.getBattery = async () => ({
                charging: true,
                chargingTime: 0,
                dischargingTime: Infinity,
                level: 1
            });
        }
        if (!('ontouchstart' in window)) {
            window.ontouchstart = null;
        }
    """)
    return context

async def handle_expired_buses(all_bus_info):
    all_temporary_results = []
    for has_expired, time_to_reserve, route_name, route_url, page in all_bus_info:
        if has_expired:
            temporary_qr_code, _, temporary_time = await get_temporary_qr_code(page, time_to_reserve, route_name)
            all_temporary_results.append(ReservationResult(
                reserved_route=route_name,
                reserved_time=temporary_time,
                qr_code=temporary_qr_code
            ))
    return QRCodeResult(success=True, reservations=all_temporary_results, 
                        message=f"DDL 战士翻车了吧！拿好你的临时码。")

async def handle_future_reservation(all_bus_info):
    if not all_bus_info:
        return QRCodeResult(success=False, reservations=[], message="No available bus times found")
    
    all_bus_info.sort(key=lambda x: x[1])  # Sort by time
    _, earliest_time, route_name, route_url, page = all_bus_info[0]

    logging.info(f"Attempting to reserve bus at {earliest_time} for route {route_name}")
    reservation_success = await make_reservation(page, earliest_time, route_url)
    
    if reservation_success:
        qr_code_result = await get_qr_code(page, earliest_time)
        if qr_code_result:
            qr_code, reserved_route, reserved_time_detailed = qr_code_result
            reservation = ReservationResult(
                reserved_route=reserved_route,
                reserved_time=reserved_time_detailed,
                qr_code=qr_code
            )
            return QRCodeResult(success=True, reservations=[reservation], 
                                message="预约成功！")
        else:
            logging.warning("Bus reserved, but unable to retrieve QR code. Attempting to cancel reservation.")
            return QRCodeResult(success=False, reservations=[], 
                                message="车给你约了，但是系统里没有乘车码。等会再来吧。")
    else:
        return QRCodeResult(success=False, reservations=[], 
                            message="预约过程中发生错误。")
