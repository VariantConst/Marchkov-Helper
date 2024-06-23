import asyncio
from playwright.async_api import async_playwright
import os
from datetime import datetime, timedelta
import re
import sys
import logging
import argparse
from dotenv import load_dotenv

load_dotenv()
USERNAME = os.getenv("USERNAME")
PASSWORD = os.getenv("PASSWORD")

# 设置日志
log_dir = "logs"
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, f"reservation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

async def wait_for_children_to_load(page):
    logger.info("等待时间选项加载完成")
    
    try:
        # Wait for the number of children to stabilize
        last_count = 0
        stable_count = 0
        max_attempts = 50  # Increase the number of attempts
        
        for _ in range(max_attempts):
            current_count = await page.evaluate('''
                () => document.querySelectorAll('.el-select-dropdown__item').length
            ''')
            
            if current_count == last_count:
                stable_count += 1
                if stable_count >= 5:
                    break
            else:
                stable_count = 0
                last_count = current_count
            
            await asyncio.sleep(0.2)  # Shorter sleep interval
        
        logger.info(f"Time options loaded. Total options: {last_count}")
        
        # Return the loaded time options
        return await page.query_selector_all('.el-scrollbar__view .el-select-dropdown__item')
    
    except Exception as e:
        logger.error(f"Error in wait_for_children_to_load: {str(e)}")
        return []

async def select_time(page):
    try:
        logger.info("开始尝试选择时间...")

        # 确保时间选择器可见并可点击
        await page.wait_for_selector('.rtq_main_item:nth-of-type(2)', state='visible', timeout=60000)
        time_input = await page.query_selector('.rtq_main_item:nth-of-type(2) .el-input__inner')
        
        if not time_input:
            logger.error("未找到时间输入框")
            return None

        # 点击时间输入框以打开选择器
        await time_input.click()
        logger.info("已点击时间输入框")

        # 等待选项加载完成
        try:
            time_options = await wait_for_children_to_load(page)
        except Exception as e:
            logger.error(f"等待时间选项加载时发生错误: {str(e)}")
            return None
        
        if not time_options:
            logger.error("未找到时间选项")
            return None

        logger.info(f"找到 {len(time_options)} 个时间选项")

        # 选择最接近当前时间的选项
        current_time = datetime.now()
        closest_time = None
        min_diff = float('inf')

        for option in time_options:
            try:
                option_text = await option.inner_text()
                time_match = re.search(r'(\d{2}:\d{2})', option_text)
                if time_match:
                    option_time = datetime.strptime(time_match.group(1), "%H:%M").replace(year=current_time.year, month=current_time.month, day=current_time.day)
                    time_diff = abs((current_time - option_time).total_seconds())
                    if time_diff < min_diff:
                        min_diff = time_diff
                        closest_time = option
            except Exception as e:
                logger.error(f"处理时间选项时发生错误: {str(e)}")

        if closest_time:
            try:
                selected_time = await closest_time.inner_text()
                logger.info(f"选择最近的时间: {selected_time}")
                await closest_time.click()
                return selected_time
            except Exception as e:
                logger.error(f"点击选中的时间选项时发生错误: {str(e)}")
                return None
        else:
            logger.warning("未找到合适的时间选项")
            return None

    except Exception as e:
        logger.error(f"select_time 函数执行过程中发生未预期的错误: {str(e)}")
        return None
    
async def main(type="回寝", time=None, headless=True):
    # 确保 qr_codes 目录存在
    os.makedirs("qr_codes", exist_ok=True)

    if time is None:
        current_time = datetime.now()
    else:
        try:
            current_time = datetime.strptime(time, "%H:%M")
        except ValueError:
            logger.error(f"无效的时间格式: {time}。请使用 HH:MM 格式。")
            return

    if type == "回寝":
        url = "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=7"
        route = "燕园校区→新校区"
    elif type == "上班":
        url = "https://wproc.pku.edu.cn/v2/reserve/reserveDetail?id=4"
        route = "新校区→燕园校区"
    else:
        logger.error(f"无效的预约类型: {type}。请选择 '回寝' 或 '上班'。")
        return

    async with async_playwright() as p:
        try:
            iphone_12 = p.devices['iPhone 12']
            browser = await p.chromium.launch(headless=headless)
            context = await browser.new_context(**iphone_12)
            page = await context.new_page()
            
            # 登录过程
            logger.info("开始登录过程")
            await page.goto("https://wproc.pku.edu.cn/")
            await page.wait_for_selector("input#user_name", state="visible")
            await page.wait_for_selector("input#password", state="visible")
            await page.fill("input#user_name", USERNAME)
            await asyncio.sleep(0.1)
            await page.fill("input#password", PASSWORD)
            await page.click("input#logon_button")
            await page.wait_for_selector('p.name:text("班车预约")', timeout=30000)
            logger.info("登录成功")

            # 访问预约页面
            logger.info(f"访问预约页面: {url}")
            await page.goto(url)
            await page.wait_for_selector("div.m_weekReserve_list", timeout=30000)
            
            # 等待包含数字/数字的元素出现
            await page.wait_for_function('''
                () => {
                    const elements = document.querySelectorAll('div, span');
                    return Array.from(elements).some(el => /\d+\/\d+/.test(el.textContent));
                }
            ''', timeout=30000)
            
            # 解析预约时间段
            time_slots = await page.query_selector_all("div.m_weekReserve_list > div")
            expired_shuttle_within_5_min = False
            all_slots = []
            for slot in time_slots:
                slot_text = await slot.inner_text()
                
                pattern = r'(\d{1,2}:\d{2})\s*([^\(]+)\s*(?:\((\d+/\d+)\))?'
                match = re.search(pattern, slot_text)
                
                if match:
                    slot_time = match.group(1)
                    status = match.group(2).strip()
                    availability = match.group(3) if match.group(3) else ""
                    status_text = f"{status}{' (' + availability + ')' if availability else ''}"
                    
                    logger.info(f"时间: {slot_time}, 状态: {status_text}")
                    all_slots.append((slot_time, status, availability))
                    
                    slot_time_obj = datetime.strptime(slot_time, "%H:%M")
                    time_diff = (current_time - slot_time_obj).total_seconds() / 60
                    if 0 <= time_diff <= 5:
                        expired_shuttle_within_5_min = True
                else:
                    logger.warning(f"无法解析时间段: {slot_text}")

            logger.info(f"当前时间: {current_time.strftime('%H:%M')}")
            logger.info(f"5分钟内有过期班车: {expired_shuttle_within_5_min}")
            
            if expired_shuttle_within_5_min:
                logger.info("发现5分钟内有过期班车，正在导航至临时登记码页面")
                await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime")
                await page.wait_for_selector('li:text("临时登记码")', timeout=30000)
                await page.click('li:text("临时登记码")')

                await page.click('input[placeholder="请选择"]:nth-of-type(1)')

                # 寻找并点击对应的路线选项
                await page.evaluate('route => {'
                        '    const items = Array.from(document.querySelectorAll(".el-select-dropdown__item > span"));'
                        '    const item = items.find(item => item.textContent.trim() === route);'
                        '    if (item) {'
                        '        item.click();'
                        '    } else {'
                        '        throw new Error("未找到对应的路线");'
                        '    }'
                        '}', route)
                
                # 使用新的select_time函数
                selected_time = await select_time(page)
                if selected_time:
                    logger.info(f"成功选择时间: {selected_time}")
                    bus_time = re.search(r'(\d{2}:\d{2})', selected_time).group(1)
                else:
                    logger.error("时间选择失败")
                    return

                await page.wait_for_selector('#rtq_main_canvas', timeout=30000)
                canvas = await page.query_selector('#rtq_main_canvas')
                if canvas:
                    save_time = datetime.now()
                    bus_datetime = datetime.combine(save_time.date(), datetime.strptime(bus_time, "%H:%M").time())
                    file_name = f"qr_codes/{type}-bus_{bus_datetime.strftime('%Y%m%d%H%M')}-save_{save_time.strftime('%Y%m%d%H%M%S')}-临时码.png"
                    await canvas.screenshot(path=file_name)
                    logger.info(f"临时登记码已保存为: {file_name}")
                else:
                    logger.error("未找到二维码画布")
            else:
                logger.info("5分钟内没有过期班车，尝试正常预约")
                reserve_div = await page.query_selector("div.can_subscribe")
                reserve_time = await page.evaluate('(el) => el.children[0].innerText', reserve_div)
                logger.info(f"即将预约 {reserve_time} 的班车")
                if reserve_div:
                    await reserve_div.click()
                    try:
                        await page.wait_for_selector('a:text(" 确定预约 ")', timeout=30000)
                        
                        confirm_button = await page.query_selector('a:text(" 确定预约 ")')
                        if confirm_button:
                            await confirm_button.click()
                            logger.info("预约已确认")

                            await page.goto("https://wproc.pku.edu.cn/v2/matter/m_reserveTime")
                            
                            try:
                                # 首先获取包含所有预约的元素
                                reserves_container = await page.wait_for_selector("ul.pku_matter_list_data", timeout=30000)
                                logger.info("找到预约列表容器")

                                # 然后从该容器中查询所有单独的预约项
                                all_reserves = await reserves_container.query_selector_all("li")  # 假设每个预约项是一个 <li> 元素

                                for reserve in all_reserves:
                                    logger.info(f"reserve: {repr(reserve)}")
                                    reserve_text_element = await reserve.query_selector("span.app_name")
                                    reserve_text = await reserve_text_element.inner_text() 
                                    if route in reserve_text:
                                        qr_link = await reserve.query_selector("a:text('签到二维码')")
                                        break

                                logger.info(f"找到签到二维码链接: {repr(qr_link)}")
                                if qr_link:
                                    await qr_link.click()
                                    try:
                                        await page.wait_for_selector('#rtq_main_canvas', timeout=30000)
                                        canvas = await page.query_selector('#rtq_main_canvas')
                                        if canvas:
                                            save_time = datetime.now()
                                            qrcode_info_div = await page.query_selector("div.rtq_main")
                                            bus_time_element = await qrcode_info_div.query_selector("p:nth-child(2)")
                                            bus_time = await bus_time_element.inner_text()
                                            bus_time = re.search(r'(\d{2}:\d{2})', bus_time).group(1)
                                            bus_datetime = datetime.combine(save_time.date(), datetime.strptime(bus_time, "%H:%M").time())
                                            file_name = f"qr_codes/{type}-bus_{bus_datetime.strftime('%Y%m%d%H%M')}-save_{save_time.strftime('%Y%m%d%H%M%S')}-乘车码.png"
                                            logger.info(f"即将保存二维码为: {file_name}")
                                            await canvas.screenshot(path=file_name)
                                            logger.info(f"二维码已保存为: {file_name}")
                                        else:
                                            logger.error("未找到二维码画布")
                                            raise Exception("预约失败：未找到二维码画布")
                                    except Exception as e:
                                        logger.error(f"获取二维码时出错: {str(e)}")
                                        raise Exception("预约失败：无法获取二维码")
                                else:
                                    logger.error("未找到'签到二维码'链接")
                                    raise Exception("预约失败：未找到'签到二维码'链接")
                            except Exception as e:
                                logger.error(f"等待'签到二维码'链接时出错: {str(e)}")
                                raise Exception("预约失败：无法找到或点击'签到二维码'链接")
                        else:
                            logger.error("未找到确认预约按钮")
                            raise Exception("预约失败：未找到确认预约按钮")
                    except Exception as e:
                        logger.error(f"确认预约过程中出错: {str(e)}")
                        raise Exception("预约失败：确认预约过程中出错")
                else:
                    logger.warning("未找到可用的时间段")
                    raise Exception("预约失败：未找到可用的时间段")

        except Exception as e:
            logger.error(f"发生错误: {str(e)}")
        finally:
            await browser.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="预约班车")
    parser.add_argument("type", choices=["回寝", "上班"], help="预约类型")
    parser.add_argument("--time", help="预约时间 (HH:MM 格式)")
    parser.add_argument("--headless", type=lambda x: (str(x).lower() == 'true'), default=True, help="是否使用无头模式")
    
    args = parser.parse_args()
    
    asyncio.run(main(args.type, args.time, args.headless))