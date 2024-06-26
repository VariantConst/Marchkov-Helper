# backend/utils.py

from playwright.async_api import Page, TimeoutError as PlaywrightTimeoutError
from playwright.async_api import Error as PlaywrightError
from fastapi import HTTPException
import logging
from datetime import datetime, timedelta
import asyncio
from typing import Tuple, Optional, List
import random

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


async def login(page: Page, username: str, password: str, max_retries: int = 5) -> bool:
    """
    执行登录过程。

    :param page: Playwright的Page对象
    :param username: 用户名
    :param password: 密码
    :param max_retries: 最大重试次数，默认为5
    :return: 登录成功返回True，否则抛出异常
    """
    for i in range(max_retries):
        try:
            # 导航到登录页面
            await page.goto("https://iaaa.pku.edu.cn/iaaa/oauth.jsp?appID=wproc&appName=办事大厅预约版&redirectUrl=https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/site/index", timeout=12000)
            logging.info("已导航至登录页面")
            
            # 填写用户名和密码
            await page.fill("#user_name", username, timeout=5000)
            logging.info("已填写用户名")

            await page.fill("#password", password, timeout=5000)
            logging.info("已填写密码")

            # 点击登录按钮
            await page.click("#logon_button", timeout=5000)
            logging.info("已点击登录按钮")

            # 等待重定向完成
            await page.wait_for_url("https://wproc.pku.edu.cn/v2/site/index", timeout=1000)
            
            logging.info("登录成功")
            return True

        except PlaywrightTimeoutError as e:
            logging.warning(f"登录操作超时：{str(e)}，第 {i + 1} 次尝试")
        except PlaywrightError as e:
            if "net::" in str(e):
                logging.warning(f"网络错误：{str(e)}，第 {i + 1} 次尝试")
            else:
                logging.warning(f"Playwright错误：{str(e)}，第 {i + 1} 次尝试")
        except Exception as e:
            logging.warning(f"登录过程出错：{str(e)}，第 {i + 1} 次尝试")

        # 实现指数退避
        wait_time = ((2 ** i) + random.random()) / 10
        logging.info(f"等待 {wait_time:.2f} 秒后重试")
        await asyncio.sleep(wait_time)

        # 刷新页面或创建新的浏览器上下文
        await page.close()
        page = await page.context.new_page()

    # 如果所有重试都失败，抛出异常
    raise HTTPException(status_code=504, detail="登录失败：重试次数过多")


async def get_qr_code(page: Page, reserved_time: str) -> Tuple[str, str, str]:
    """
    获取指定预约时间的二维码。

    :param page: Playwright的Page对象
    :param reserved_time: 预约时间
    :return: 返回二维码的base64数据、预约路线和详细预约时间
    """
    try:
        # 导航到预约时间页面
        # await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime", timeout=6000)
        await page.wait_for_load_state("networkidle", timeout=6000)
        
        # 查找所有预约项
        reserved_items = await page.query_selector_all(".pku_matter_list_data > li")
        today = datetime.today().date().isoformat()
        logging.info(f"准备获取 {today} {reserved_time} 的二维码")
        
        for item in reserved_items:
            time_span = await item.query_selector(".content_title_top > span:nth-child(2)")
            if time_span:
                reservation_time = await time_span.inner_text()
                reservation_time = reservation_time.strip()
                _, date_str, t = reservation_time.split()
                logging.info(f"找到预约：{date_str} {t}")
                if date_str == today and t == reserved_time:
                    qrcode_span = await item.query_selector(".matter_list_data_btn a:has-text('签到二维码')")
                    logging.info("找到二维码按钮！准备点击并获取二维码...")
                    if qrcode_span:
                        await qrcode_span.click(timeout=3000)
                        qrcode_canvas = await page.wait_for_selector("#rtq_main_canvas", timeout=3000)
                        base64_data = await page.evaluate("""(qrcode_canvas) => {
                            return qrcode_canvas.toDataURL('image/png');
                        }""", qrcode_canvas)
                        logging.info("二维码获取成功")
                        
                        # 获取预约详情
                        reservation_details = await page.wait_for_selector(".rtq_main", timeout=3000)
                        reserved_route = await (await reservation_details.query_selector("p:first-child")).inner_text()
                        reserved_route = reserved_route.strip()[1:-1]
                        reserved_time_detailed = await (await reservation_details.query_selector("p:nth-child(2)")).inner_text()
                        reserved_time_detailed = reserved_time_detailed.split("：")[1].strip()
                        logging.info("预约详情获取成功")
                        return base64_data, reserved_route, reserved_time_detailed
    except PlaywrightTimeoutError as e:
        logging.error(f"二维码获取超时：{str(e)}")
        raise HTTPException(status_code=504, detail=f"二维码获取超时：{str(e)}")

async def get_temporary_qr_code(page: Page, time_to_reserve: str, route_name: str) -> Tuple[str, str, str]:
    """
    获取临时二维码。

    :param page: Playwright的Page对象
    :param time_to_reserve: 预约时间
    :param route_name: 路线名称
    :return: 返回临时二维码的base64数据、路线名称和预约时间
    """
    try:
        # 导航到预约页面
        await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime", timeout=6000)
        await page.click("li:has-text('临时登记码')", timeout=3000)

        RETRY_DELAY = 0
        MAX_RETRIES = 5
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                # 等待输入元素数量稳定
                # await wait_for_stable_element_count(page, 'input[placeholder="请选择"].el-input__inner', timeout=3000, check_interval=10, stability_duration=30)
                
                # 选择路线和时间
                logging.info("选择路线和时间")
                input_elements = await page.query_selector_all('input[placeholder="请选择"].el-input__inner')
                if len(input_elements) < 2:
                    raise ValueError("未找到足够的输入元素")

                logging.info(f"选择路线：{route_name}")
                await input_elements[0].click(timeout=3000)
                await page.click(f".el-select-dropdown__item > span:has-text('{route_name}')", timeout=3000)

                logging.info(f"选择时间：{time_to_reserve}")
                await input_elements[1].click(timeout=3000)
                
                # 获取时间选项
                valid_times = []

                # 使用 evaluate 方法一次性获取所有时间选项的文本
                time_texts = await page.evaluate("""
                    () => Array.from(document.querySelectorAll('.el-select-dropdown__item span'))
                                .map(el => el.textContent.trim())
                """)

                logging.info(f"尝试 {attempt}: 获取到的时间选项为 {time_texts}")

                valid_times = [
                    datetime.strptime(t, "%H:%M")
                    for t in time_texts
                    if t.replace(":", "").isdigit()
                ]

                if valid_times:
                    logging.info(f"成功获取有效时间选项，共 {len(valid_times)} 个")
                    break

                logging.warning(f"尝试 {attempt}: 没有找到有效的时间选项")
            except Exception as e:
                logging.error(f"尝试 {attempt}: 获取时间选项时发生错误: {str(e)}")

            if attempt < MAX_RETRIES:
                logging.info(f"等待 {RETRY_DELAY} 秒后进行第 {attempt + 1} 次尝试")
                await asyncio.sleep(RETRY_DELAY)
            else:
                logging.error("达到最大重试次数，仍未找到有效的时间选项")
                raise ValueError("没有找到有效的时间选项")

        if not valid_times:
            raise ValueError("没有找到有效的时间选项")

        time_to_reserve = datetime.strptime(time_to_reserve, "%H:%M")
        nearest_time = min(valid_times, key=lambda x: abs(x - time_to_reserve))
        nearest_time_str = nearest_time.strftime("%H:%M")
        logging.info(f"选择最接近的时间: {nearest_time_str}")

        await page.click(f".el-select-dropdown__item > span:has-text('{nearest_time_str}')", timeout=3000)

        # 获取二维码
        canvas = await page.wait_for_selector("#rtq_main_canvas", timeout=3000)
        base64_data = await page.evaluate("""(canvas) => {
            return canvas.toDataURL('image/png');
        }""", canvas)
        logging.info("临时二维码获取成功")
        return base64_data, route_name, f"{datetime.now().strftime('%Y-%m-%d')} {nearest_time_str}"
    except PlaywrightTimeoutError as e:
        logging.error(f"临时二维码获取超时：{str(e)}")
        raise HTTPException(status_code=504, detail=f"临时二维码获取超时：{str(e)}")


async def get_bus_time(context: Page, route_name: str, route_url: str, target_time: str) -> Optional[Tuple[bool, str, str, str, Page]]:
    """
    获取指定路线的巴士时间。

    :param context: Playwright的浏览器上下文
    :param route_name: 路线名称
    :param route_url: 路线URL
    :param target_time: 目标时间
    :return: 如果找到合适的巴士时间，返回一个元组，否则返回None
    """
    try:
        page = await context.new_page()
        await page.goto(route_url, timeout=6000)
        logging.info(f"已导航至 {route_name} 预约页面：{route_url}")

        # 等待元素数量稳定
        await wait_for_stable_element_count(page, ".m_weekReserve_list > div", timeout=6000, check_interval=10, stability_duration=250)
        
        max_retries = 5

        for attempt in range(max_retries):
            bus_times = await page.query_selector_all(".m_weekReserve_list > div")
            logging.info(f"找到 {len(bus_times)} 个巴士时间：{bus_times}")
            has_expired_bus = False
            time_to_reserve = datetime.strptime("23:59", "%H:%M")
            target_time = datetime.strptime(target_time, "%H:%M")
            
            for bus in bus_times:
                time_elem = await bus.query_selector("div:first-child")
                status_elem = await bus.query_selector("div:nth-child(2)")
                
                if time_elem and status_elem:
                    t = await time_elem.inner_text()
                    status = await status_elem.inner_text()
                    
                    logging.info(f"时间: {t}, 状态: {status}")

                    t = datetime.strptime(t, "%H:%M")

                    has_expired_bus = has_expired_bus or \
                        (target_time - timedelta(minutes=10) <= t <= target_time and "禁用" not in status)

                    if has_expired_bus:
                        time_to_reserve = t
                        break
                    elif target_time < t < target_time + timedelta(minutes=60) and "可预约" in status:
                        time_to_reserve = min(time_to_reserve, t)
            
            if time_to_reserve == datetime.strptime("23:59", "%H:%M"):
                if attempt < max_retries - 1:
                    logging.info(f"第 {attempt + 1} 次尝试未找到合适的巴士时间，重试")
                    continue
                else:
                    logging.warning("未找到合适的巴士时间")
                    return None
                
            return has_expired_bus, time_to_reserve.strftime("%H:%M"), route_name, route_url, page
        
        else:
            logging.warning("未找到合适的巴士时间")
            return None

    except PlaywrightTimeoutError as e:
        logging.error(f"超时：{str(e)}")
        raise HTTPException(status_code=504, detail=f"超时：{str(e)}")

async def wait_for_stable_element_count(page: Page, selector: str, timeout: int = 3000, check_interval: int = 10, stability_duration: int = 300):
    """
    等待指定选择器的元素数量稳定。

    :param page: Playwright页面对象
    :param selector: CSS选择器
    :param timeout: 总超时时间（毫秒）
    :param check_interval: 检查间隔（毫秒）
    :param stability_duration: 稳定持续时间（毫秒）
    """
    start_time = datetime.now()
    last_count = -1
    last_stable_time = None

    while (datetime.now() - start_time).total_seconds() * 1000 < timeout:
        current_count = await page.locator(selector).count()
        
        if current_count == last_count:
            if last_stable_time is None:
                last_stable_time = datetime.now()
            elif (datetime.now() - last_stable_time).total_seconds() * 1000 >= stability_duration:
                logging.info(f"元素数量已稳定在 {current_count}")
                return
        else:
            last_count = current_count
            last_stable_time = None
        
        await asyncio.sleep(check_interval / 1000)

    raise PlaywrightTimeoutError(f"等待元素数量稳定超时：{selector}")

async def make_reservation(page: Page, time: str, url: str) -> bool:
    """
    进行巴士预约。

    :param page: Playwright的Page对象
    :param time: 预约时间
    :param url: 预约页面URL
    :return: 预约成功返回True，否则返回False
    """
    await page.goto(url, timeout=6000, wait_until="networkidle")
    bus_times = await page.query_selector_all(".m_weekReserve_list > div")
    
    for bus in bus_times:
        time_elem = await bus.query_selector("div:first-child")
        status_elem = await bus.query_selector("div:nth-child(2)")
        
        if time_elem and status_elem:
            t = await time_elem.inner_text()
            status = await status_elem.inner_text()
            
            if t == time and "可预约" in status:
                await bus.click(timeout=3000)
                await page.click("text= 确定预约 ", timeout=3000)
                
                try:
                    result = await page.wait_for_selector("p:has-text('我的预约'), p:has-text('同一时间段不可重复预约')", timeout=3000)
                    result_text = await result.inner_text()
                    
                    if "我的预约" in result_text or "同一时间段不可重复预约" in result_text:
                        logging.info(f"{time} 的预约已确认")
                        await page.wait_for_load_state("networkidle", timeout=6000)
                        return True
                except Exception as e:
                    logging.error(f"等待预约结果时出错：{str(e)}")
                    return False

    logging.warning(f"未能成功预约 {time}")
    return False