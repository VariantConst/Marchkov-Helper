# backend/services.py

from models import UserCredentials, QRCodeResult, ReservationResult
from utils import login, get_bus_time, make_reservation, get_qr_code, get_temporary_qr_code
from config import data_route_urls
from playwright.async_api import async_playwright, BrowserContext
import logging
import asyncio
from datetime import datetime
from typing import List, Tuple, Optional

# 配置日志
logger = logging.getLogger(__name__)

async def get_qr_code_service(credentials: UserCredentials) -> QRCodeResult:
    """
    获取二维码服务的主函数。

    :param credentials: 用户凭证
    :return: 二维码结果
    """
    async with async_playwright() as p:
        browser_context = await setup_browser_context(p)
        page = await browser_context.new_page()
        
        try:
            # 尝试登录
            login_success = await login(page, credentials.username, credentials.password)
            if not login_success:
                return QRCodeResult(success=False, reservations=[], message="登录失败")

            # 根据用户选择确定路线
            routes = data_route_urls["to_changping" if credentials.is_return else "to_yanyuan"]
            credentials.target_time = credentials.target_time or datetime.now().strftime("%H:%M")

            # 获取所有路线的巴士时间
            bus_info = [get_bus_time(browser_context, route_name, route_url, credentials.target_time) 
                        for (route_name, route_url) in routes.items()]
            all_bus_info = await asyncio.gather(*bus_info)
            all_bus_info = [bus_info for bus_info in all_bus_info if bus_info]  # 移除None值

            # 检查是否有过期的巴士（10分钟内）
            has_expired_bus = any([bus_info[0] for bus_info in all_bus_info])
            logging.info(f"10分钟内有过期的巴士：{has_expired_bus}")

            if has_expired_bus:
                return await handle_expired_buses(all_bus_info)
            else:
                return await handle_future_reservation(all_bus_info)

        finally:
            await browser_context.close()

async def setup_browser_context(p) -> BrowserContext:
    """
    设置浏览器上下文，模拟iPhone 12 Pro。

    :param p: Playwright实例
    :return: 配置好的浏览器上下文
    """
    iphone_12_pro = p.devices['iPhone 12 Pro']
    browser_options = {
        **iphone_12_pro,
        "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1",
        "locale": "zh-CN",
        "timezone_id": "Asia/Shanghai",
        "geolocation": {"latitude": 39.9042, "longitude": 116.4074},
        "permissions": ["geolocation"]
    }
    browser = await p.webkit.launch(headless=False)
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

async def handle_expired_buses(all_bus_info: List[Tuple[bool, str, str, str, BrowserContext]]) -> QRCodeResult:
    """
    处理过期的巴士预约。

    :param all_bus_info: 所有巴士信息的列表
    :return: 二维码结果
    """
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

async def handle_future_reservation(all_bus_info: List[Tuple[bool, str, str, str, BrowserContext]]) -> QRCodeResult:
    """
    处理未来的巴士预约。

    :param all_bus_info: 所有巴士信息的列表
    :return: 二维码结果
    """
    if not all_bus_info:
        return QRCodeResult(success=False, reservations=[], message="未找到可用的巴士时间")
    
    # 按时间排序，选择最早的时间
    all_bus_info.sort(key=lambda x: x[1])
    _, earliest_time, route_name, route_url, page = all_bus_info[0]

    logging.info(f"尝试预约 {route_name} 路线的 {earliest_time} 巴士")
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
            logging.warning("巴士已预约，但无法获取二维码。尝试取消预约。")
            return QRCodeResult(success=False, reservations=[], 
                                message="车给你约了，但是系统里没有乘车码。等会再来吧。")
    else:
        return QRCodeResult(success=False, reservations=[], 
                            message="预约过程中发生错误。")
