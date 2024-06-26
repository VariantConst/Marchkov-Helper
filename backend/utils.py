# backend/utils.py

from playwright.async_api import Page, TimeoutError as PlaywrightTimeoutError
from fastapi import HTTPException
import logging
from datetime import datetime, timedelta
import asyncio

async def login(context, username, password):
    try:
        page = await context.new_page()
        await page.goto("https://wproc.pku.edu.cn/v2/site/index", timeout=120000)
        logging.info("Navigated to login page")
        
        await page.wait_for_load_state("networkidle", timeout=60000)
        
        username_selector = "input[placeholder='学号/职工号/手机号']"
        password_selector = "input[placeholder='密码']"
        login_button_selector = 'input#logon_button[type="submit"][value="登录"]'
        
        await page.wait_for_selector(username_selector, state="visible", timeout=60000)
        await page.fill(username_selector, username, timeout=30000)
        logging.info("Filled username")

        await page.wait_for_selector(password_selector, state="visible", timeout=60000)
        await page.fill(password_selector, password, timeout=30000)
        logging.info("Filled password")

        await page.wait_for_selector(login_button_selector, state="visible", timeout=60000)
        await page.click(login_button_selector, timeout=30000)
        logging.info("Clicked login button")

        await page.wait_for_selector('p.name:text("班车预约")', state="visible", timeout=60000)
        logging.info("Login successful")

        await page.close()
        return True
    except PlaywrightTimeoutError as e:
        logging.error(f"Timeout during login: {str(e)}")
        raise HTTPException(status_code=504, detail=f"Login process timed out: {str(e)}")
    except Exception as e:
        logging.error(f"Error during login: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Login failed: {str(e)}")

async def get_qr_code(page, reserved_time):
    try:
        await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime", timeout=60000)
        await page.reload(timeout=60000)
        await page.wait_for_load_state("networkidle", timeout=60000)

        reserved_items = await page.query_selector_all(".pku_matter_list_data > li")
        today = datetime.today().date().isoformat()
        logging.info(f"Ready to retrieve QR code for {today} {reserved_time}")
        for item in reserved_items:
            time_span = await item.query_selector(".content_title_top > span:nth-child(2)")
            if time_span:
                reservation_time = await time_span.inner_text()
                reservation_time = reservation_time.strip()
                _, date_str, t = reservation_time.split()
                logging.info(f"Found reservation: {date_str} {t}")
                if date_str == today and t == reserved_time:
                    qrcode_span = await item.query_selector(".matter_list_data_btn a:has-text('签到二维码')")
                    logging.info("Found QR code button! Ready to click and get the QR code...")
                    if qrcode_span:
                        await qrcode_span.click(timeout=30000)
                        qrcode_canvas = await page.wait_for_selector("#rtq_main_canvas", timeout=30000)
                        base64_data = await page.evaluate("""(qrcode_canvas) => {
                            return qrcode_canvas.toDataURL('image/png');
                        }""", qrcode_canvas)
                        logging.info("QR code retrieved successfully")
                        reservation_details = await page.wait_for_selector(".rtq_main", timeout=30000)
                        reserved_route = await (await reservation_details.query_selector("p:first-child")).inner_text()
                        reserved_route = reserved_route.strip()[1:-1]
                        reserved_time_detailed = await (await reservation_details.query_selector("p:nth-child(2)")).inner_text()
                        reserved_time_detailed = reserved_time_detailed.split("：")[1].strip()
                        logging.info("QR code retrieved successfully")
                        return base64_data, reserved_route, reserved_time_detailed
    except PlaywrightTimeoutError as e:
        logging.error(f"QR code retrieval timed out: {str(e)}")
        raise HTTPException(status_code=504, detail=f"QR code retrieval timed out: {str(e)}")

async def get_temporary_qr_code(page, time_to_reserve, route_name):
    try:
        await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime", timeout=60000)
        await page.wait_for_load_state("networkidle", timeout=60000)
        await page.click("li:has-text('临时登记码')", timeout=30000)
        input_elements = await page.query_selector_all('input[placeholder="请选择"].el-input__inner')
        if len(input_elements) < 2:
            await page.reload(timeout=60000)
            await page.wait_for_load_state("networkidle", timeout=60000)
            input_elements = await page.query_selector_all('input[placeholder="请选择"].el-input__inner')

        await input_elements[0].click(timeout=30000)
        await page.click(f".el-select-dropdown__item > span:has-text('{route_name}')", timeout=30000)

        await input_elements[1].click(timeout=30000)
        time_options = await page.query_selector_all(".el-select-dropdown__item span")
        time_texts = [await option.inner_text() for option in time_options]

        valid_times = [
            datetime.strptime(t, "%H:%M")
            for t in time_texts
            if t.replace(":", "").isdigit()
        ]

        if not valid_times:
            raise ValueError("No valid time options found")

        time_to_reserve = datetime.strptime(time_to_reserve, "%H:%M")
        nearest_time = min(valid_times, key=lambda x: abs(x - time_to_reserve))
        nearest_time_str = nearest_time.strftime("%H:%M")
        logging.info(f"Selected nearest time: {nearest_time_str}")

        await page.click(f".el-select-dropdown__item > span:has-text('{nearest_time_str}')", timeout=30000)

        canvas = await page.wait_for_selector("#rtq_main_canvas", timeout=30000)
        base64_data = await page.evaluate("""(canvas) => {
            return canvas.toDataURL('image/png');
        }""", canvas)
        logging.info("Temporary QR code retrieved successfully")
        return base64_data, route_name, f"{datetime.now().strftime('%Y-%m-%d')} {nearest_time_str}"
    except PlaywrightTimeoutError as e:
        logging.error(f"Temporary QR code retrieval timed out: {str(e)}")
        raise HTTPException(status_code=504, detail=f"Temporary QR code retrieval timed out: {str(e)}")

async def get_bus_time(context, route_name: str, route_url: str, target_time: str) -> tuple:
    try:
        page = await context.new_page()
        await page.goto(route_url, timeout=60000, wait_until="networkidle")
        logging.info(f"Navigated to {route_name} reservation page: {route_url}")
        bus_times = await page.query_selector_all(".m_weekReserve_list > div")
        has_expired_bus = False
        time_to_reserve = datetime.strptime("23:59", "%H:%M")
        target_time = datetime.strptime(target_time, "%H:%M")
        
        for bus in bus_times:
            time_elem = await bus.query_selector("div:first-child")
            status_elem = await bus.query_selector("div:nth-child(2)")
            
            if time_elem and status_elem:
                t = await time_elem.inner_text()
                status = await status_elem.inner_text()
                
                logging.info(f"Time: {t}, Status: {status}")

                t = datetime.strptime(t, "%H:%M")

                has_expired_bus = has_expired_bus or \
                    (target_time - timedelta(minutes=10) <= t <= target_time and "可预约" in status)

                if has_expired_bus:
                    time_to_reserve = t
                    break
                elif t > target_time and "可预约" in status:
                    time_to_reserve = min(time_to_reserve, t)
        
        if time_to_reserve == datetime.strptime("23:59", "%H:%M"):
            logging.warning("No available buses")
            return None
        return has_expired_bus, time_to_reserve.strftime("%H:%M"), route_name, route_url, page

    except PlaywrightTimeoutError as e:
        logging.error(f"Timeout: {str(e)}")
        raise HTTPException(status_code=504, detail=f"Timeout: {str(e)}")

async def make_reservation(page, time, url):
    await page.goto(url, timeout=60000, wait_until="networkidle")
    bus_times = await page.query_selector_all(".m_weekReserve_list > div")
    
    for bus in bus_times:
        time_elem = await bus.query_selector("div:first-child")
        status_elem = await bus.query_selector("div:nth-child(2)")
        
        if time_elem and status_elem:
            t = await time_elem.inner_text()
            status = await status_elem.inner_text()
            
            if t == time and "可预约" in status:
                await bus.click(timeout=30000)
                await page.click("text= 确定预约 ", timeout=30000)
                
                try:
                    result = await page.wait_for_selector("p:has-text('我的预约'), p:has-text('同一时间段不可重复预约')", timeout=30000)
                    result_text = await result.inner_text()
                    
                    if "我的预约" in result_text or "同一时间段不可重复预约" in result_text:
                        logging.info(f"Reservation confirmed for {time}")
                        return True
                except Exception as e:
                    logging.error(f"Error while waiting for reservation result: {str(e)}")
                    return False

    logging.warning(f"Failed to make reservation for {time}")
    return False