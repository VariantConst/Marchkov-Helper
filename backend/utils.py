# backend/utils.py

from playwright.async_api import Page, TimeoutError as PlaywrightTimeoutError
from fastapi import HTTPException
import logging
from datetime import datetime, timedelta
import asyncio
from typing import Tuple, Optional, List

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
    try:
        for i in range(max_retries):
            try:
                # 导航到登录页面
                await page.goto("https://iaaa.pku.edu.cn/iaaa/oauth.jsp?appID=wproc&appName=办事大厅预约版&redirectUrl=https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/site/index", timeout=120000)
                logging.info("已导航至登录页面")
                
                logging.info("登录页面加载成功")
                
                # 填写用户名和密码
                await page.fill("#user_name", username, timeout=100)
                logging.info("已填写用户名")

                await page.fill("#password", password, timeout=100)
                logging.info("已填写密码")

                # 点击登录按钮
                await page.click("#logon_button", timeout=100)
                logging.info("已点击登录按钮")

                # 等待页面加载完成
                await page.wait_for_load_state("networkidle", timeout=10000)

                # 关闭页面
                await page.close()
                return True

            except PlaywrightTimeoutError as e:
                logging.error(f"登录超时：{str(e)}，第 {i + 1} 次尝试")
                continue
        
        else:
            raise HTTPException(status_code=504, detail="登录失败：重试次数过多")

    except PlaywrightTimeoutError as e:
        logging.error(f"登录过程超时：{str(e)}")
        raise HTTPException(status_code=504, detail=f"登录过程超时：{str(e)}")
    except Exception as e:
        logging.error(f"登录过程出错：{str(e)}")
        raise HTTPException(status_code=500, detail=f"登录失败：{str(e)}")

async def get_qr_code(page: Page, reserved_time: str) -> Tuple[str, str, str]:
    """
    获取指定预约时间的二维码。

    :param page: Playwright的Page对象
    :param reserved_time: 预约时间
    :return: 返回二维码的base64数据、预约路线和详细预约时间
    """
    try:
        # 导航到预约时间页面
        # await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime", timeout=60000)
        await page.wait_for_load_state("networkidle", timeout=60000)
        
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
                        await qrcode_span.click(timeout=30000)
                        qrcode_canvas = await page.wait_for_selector("#rtq_main_canvas", timeout=30000)
                        base64_data = await page.evaluate("""(qrcode_canvas) => {
                            return qrcode_canvas.toDataURL('image/png');
                        }""", qrcode_canvas)
                        logging.info("二维码获取成功")
                        
                        # 获取预约详情
                        reservation_details = await page.wait_for_selector(".rtq_main", timeout=30000)
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
        await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime", timeout=60000)
        await page.click("li:has-text('临时登记码')", timeout=30000)
        
        # 选择路线和时间
        input_elements = await page.query_selector_all('input[placeholder="请选择"].el-input__inner')
        if len(input_elements) < 2:
            await page.reload(timeout=60000)
            await page.wait_for_load_state("networkidle", timeout=60000)
            input_elements = await page.query_selector_all('input[placeholder="请选择"].el-input__inner')

        await input_elements[0].click(timeout=30000)
        await page.click(f".el-select-dropdown__item > span:has-text('{route_name}')", timeout=30000)

        await input_elements[1].click(timeout=30000)
        
        max_retries = 3
        for _ in range(max_retries):
            await page.wait_for_load_state("networkidle", timeout=60000)
            time_options = await page.query_selector_all(".el-select-dropdown__item span")
            time_texts = [await option.inner_text() for option in time_options]

            logging.info(f"可选时间为 {time_texts}，预约时间为 {time_to_reserve}")

            valid_times = [
                datetime.strptime(t, "%H:%M")
                for t in time_texts
                if t.replace(":", "").isdigit()
            ]

            if not valid_times:
                continue
            break
        else:
            raise ValueError("没有找到有效的时间选项")

        time_to_reserve = datetime.strptime(time_to_reserve, "%H:%M")
        nearest_time = min(valid_times, key=lambda x: abs(x - time_to_reserve))
        nearest_time_str = nearest_time.strftime("%H:%M")
        logging.info(f"选择最接近的时间: {nearest_time_str}")

        await page.click(f".el-select-dropdown__item > span:has-text('{nearest_time_str}')", timeout=30000)

        # 获取二维码
        canvas = await page.wait_for_selector("#rtq_main_canvas", timeout=30000)
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
        await page.goto(route_url, timeout=60000)
        logging.info(f"已导航至 {route_name} 预约页面：{route_url}")
        await page.wait_for_load_state("networkidle", timeout=60000)
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
                elif t > target_time and "可预约" in status:
                    time_to_reserve = min(time_to_reserve, t)
        
        if time_to_reserve == datetime.strptime("23:59", "%H:%M"):
            logging.warning("没有可用的巴士")
            return None
        return has_expired_bus, time_to_reserve.strftime("%H:%M"), route_name, route_url, page

    except PlaywrightTimeoutError as e:
        logging.error(f"超时：{str(e)}")
        raise HTTPException(status_code=504, detail=f"超时：{str(e)}")

async def make_reservation(page: Page, time: str, url: str) -> bool:
    """
    进行巴士预约。

    :param page: Playwright的Page对象
    :param time: 预约时间
    :param url: 预约页面URL
    :return: 预约成功返回True，否则返回False
    """
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
                        logging.info(f"{time} 的预约已确认")
                        await page.wait_for_load_state("networkidle", timeout=60000)
                        return True
                except Exception as e:
                    logging.error(f"等待预约结果时出错：{str(e)}")
                    return False

    logging.warning(f"未能成功预约 {time}")
    return False