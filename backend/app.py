from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError
import base64
from typing import Optional, List
import logging
import time
from datetime import datetime, timedelta
import pytz
import asyncio
from playwright.async_api import Error as PlaywrightError

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = FastAPI()

class UserCredentials(BaseModel):
    username: str
    password: str
    target_time: Optional[str] = None
    is_return: bool = False

class ReservationResult(BaseModel):
    reserved_route: str
    reserved_time: str
    qr_code: str

class QRCodeResult(BaseModel):
    success: bool
    reservations: List[ReservationResult]
    message: str

async def login(context, username, password):
    try:
        page = await context.new_page()
        await page.goto("https://wproc.pku.edu.cn/v2/site/index", timeout=120000)
        logging.info("Navigated to login page")
        
        # 等待页面加载完成
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
    
async def reserve_first_available(page, target_time=None, reserve_url="https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=4", max_retries=3):
    for attempt in range(max_retries):
        try:
            await page.goto(reserve_url, timeout=60000, wait_until="networkidle")
            logging.info(f"Navigated to reservation page: {reserve_url}")

            bus_times = await page.query_selector_all(".m_weekReserve_list > div")
            first_available = None
            first_available_time = None
            
            beijing_tz = pytz.timezone('Asia/Shanghai')
            current_time = datetime.now(beijing_tz).strftime("%H:%M")
            
            for bus in bus_times:
                time_elem = await bus.query_selector("div:first-child")
                status_elem = await bus.query_selector("div:nth-child(2)")
                
                if time_elem and status_elem:
                    t = await time_elem.inner_text()
                    status = await status_elem.inner_text()
                    
                    logging.info(f"Time: {t}, Status: {status}")
                    
                    if "可预约" in status:
                        if target_time:
                            if t >= target_time and (not first_available or t < first_available_time):
                                first_available = bus
                                first_available_time = t
                        elif t >= current_time and (not first_available or t < first_available_time):
                            first_available = bus
                            first_available_time = t

            if first_available:
                logging.info(f"Clicking on the first available bus at {first_available_time}")
                await first_available.click(timeout=30000)
                await page.click("text= 确定预约  ", timeout=30000)
                logging.info("Reservation confirmed")
                return True, first_available_time
            else:
                logging.info("No available bus times")
                return False, None

        except PlaywrightTimeoutError as e:
            logging.warning(f"Timeout during reservation (attempt {attempt + 1}/{max_retries}): {str(e)}")
            if attempt == max_retries - 1:
                raise HTTPException(status_code=504, detail=f"Reservation process timed out after {max_retries} attempts: {str(e)}")
        except PlaywrightError as e:
            logging.warning(f"Playwright error during reservation (attempt {attempt + 1}/{max_retries}): {str(e)}")
            if attempt == max_retries - 1:
                raise HTTPException(status_code=500, detail=f"Reservation failed after {max_retries} attempts due to Playwright error: {str(e)}")
        except Exception as e:
            logging.error(f"Unexpected error during reservation (attempt {attempt + 1}/{max_retries}): {str(e)}")
            if attempt == max_retries - 1:
                raise HTTPException(status_code=500, detail=f"Reservation failed after {max_retries} attempts due to unexpected error: {str(e)}")

    # 如果所有尝试都失败，返回失败结果
    return False, None

async def get_qr_code(page, reserved_time):
    try:
        await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime", timeout=60000)
        await page.wait_for_selector(".pku_matter_list_data", timeout=60000)
        logging.info("Navigated to QR code page")

        reserved_items = await page.query_selector_all(".pku_matter_list_data > li")
        for item in reserved_items:
            time_span = await item.query_selector(".content_title_top > span:nth-child(2)")
            if time_span:
                reservation_time = await time_span.inner_text()
                reservation_time = reservation_time.strip()
                _, date, t = reservation_time.split(" ")
                if date == await page.evaluate("() => new Date().toISOString().split('T')[0]") and t == reserved_time:
                    logging.info(f"Found today's reservation: {reservation_time}")
                    qrcode_span = await item.query_selector(".matter_list_data_btn a:has-text('签到二维码')")
                    if qrcode_span:
                        await qrcode_span.click(timeout=30000)
                        qrcode_canvas = await page.wait_for_selector("#rtq_main_canvas", timeout=30000)
                        base64_data = await page.evaluate("""(qrcode_canvas) => {
                            return qrcode_canvas.toDataURL('image/png');
                        }""", qrcode_canvas)
                        reservation_details = await page.wait_for_selector(".rtq_main", timeout=30000)
                        reserved_route = await (await reservation_details.query_selector("p:first-child")).inner_text()
                        reserved_route = reserved_route.strip()[1:-1]
                        reserved_time_detailed = await (await reservation_details.query_selector("p:nth-child(2)")).inner_text()
                        reserved_time_detailed = reserved_time_detailed.split("：")[1].strip()
                        logging.info("QR code retrieved successfully")
                        return base64_data, reserved_route, reserved_time_detailed
        logging.info("QR code not found")
        return None
    except PlaywrightTimeoutError as e:
        logging.error(f"Timeout while getting QR code: {str(e)}")
        raise HTTPException(status_code=504, detail=f"QR code retrieval timed out: {str(e)}")
    except Exception as e:
        logging.error(f"Error while getting QR code: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve QR code: {str(e)}")

async def process_reservation(context, url, target_time):
    page = await context.new_page()
    try:
        success, reserved_time = await reserve_first_available(page, target_time, url)
        if success:
            logging.info(f"Successfully reserved for URL: {url}")
            reserved_results = await get_qr_code(page, reserved_time)
            if reserved_results:
                qr_code, reserved_route, reserved_time_detailed = reserved_results
                return ReservationResult(
                    reserved_route=reserved_route,
                    reserved_time=reserved_time_detailed,
                    qr_code=qr_code
                )
            else:
                logging.warning(f"Failed to get QR code for URL: {url}")
        else:
            logging.info(f"No available reservation for URL: {url}")
        return None
    finally:
        await page.close()

@app.post("/get_qr_code", response_model=QRCodeResult)
async def api_get_qr_code(credentials: UserCredentials):
    async with async_playwright() as p:
        iphone_12 = p.devices['iPhone 12']
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context(**iphone_12)
        
        try:
            # 首先登录
            login_success = await login(context, credentials.username, credentials.password)
            if not login_success:
                return QRCodeResult(success=False, reservations=[], message="Failed to login")

            if credentials.is_return:
                urls = [
                    "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=7",
                    "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=6",
                    "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=5"
                ]
            else:
                urls = [
                    "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=4",
                    "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=3",
                    "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=2",
                ]
            
            # 并发处理所有预约任务
            tasks = [process_reservation(context, url, credentials.target_time) for url in urls]
            reservations = await asyncio.gather(*tasks)
            reservations = [r for r in reservations if r is not None]
            
            if reservations:
                return QRCodeResult(success=True, reservations=reservations, message=f"Successfully retrieved {len(reservations)} QR code(s)")
            else:
                return QRCodeResult(success=False, reservations=[], message="Failed to make any reservations or retrieve QR codes")
        except HTTPException as e:
            raise e
        except Exception as e:
            logging.error(f"Unexpected error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")
        finally:
            await browser.close()
            
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)