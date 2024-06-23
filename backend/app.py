from fastapi import FastAPI, BackgroundTasks
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import asyncio
import os
from datetime import datetime, timedelta
import aiofiles
import logging
import json
from urllib.parse import quote

# 设置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI()

# 添加 CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 替换为您的前端 URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 确保 qr_codes 目录存在
os.makedirs("qr_codes", exist_ok=True)

class ReservationRequest(BaseModel):
    type: str
    time: Optional[str] = None
    headless: bool = True

async def run_reservation_script(type: str, time: Optional[str], headless: bool):
    command = ["python", "backend/reservation_script.py", type]
    if time:
        command.extend(["--time", time])
    command.extend(["--headless", str(headless).lower()])
    
    logger.info(f"执行命令/: {' '.join(command)}")
    
    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    
    stdout, stderr = await process.communicate()
    
    if process.returncode == 0:
        logger.info("预约成功")
        return True, stdout.decode()
    else:
        logger.error("预约失败")
        return False, stderr.decode()

@app.post("/reserve")
async def reserve(request: ReservationRequest):
    logger.info(f"收到预约请求: {request}")
    try:
        success, message = await run_reservation_script(request.type, request.time, request.headless)
        return JSONResponse(content={"success": success, "message": message})
    except Exception as e:
        logger.error(f"启动预约进程时出错: {str(e)}")
        return JSONResponse(content={"success": False, "message": f"启动预约进程失败: {str(e)}"})

@app.get("/qr-code/{type}")
async def get_qr_code(type: str):
    qr_code_dir = "qr_codes"
    logger.info(f"正在查找 {type} 类型的二维码")
    try:
        files = os.listdir(qr_code_dir)
        now = datetime.now()
        
        matching_files = []
        for file in files:
            if file.startswith(f"{type}-bus_"):
                file_parts = file.split('-')
                if len(file_parts) >= 4:
                    bus_time = datetime.strptime(file_parts[1].replace('bus_', ''), "%Y%m%d%H%M")
                    save_time = datetime.strptime(file_parts[2].replace('save_', ''), "%Y%m%d%H%M%S")
                    
                    # Check if the file was created within the last 20 seconds
                    if now - save_time < timedelta(seconds=30):
                        matching_files.append(file)
        
        if matching_files:
            # Sort files by save time, most recent first
            latest_file = sorted(matching_files, key=lambda f: f.split('-')[2], reverse=True)[0]
            logger.info(f"找到二维码文件: {latest_file}")
            
            # URL encode the filename
            encoded_filename = quote(latest_file)
            
            return FileResponse(
                os.path.join(qr_code_dir, latest_file),
                headers={
                    "Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}",
                    "Access-Control-Expose-Headers": "Content-Disposition"
                }
            )
        else:
            logger.warning(f"未找到符合条件的 {type} 类型的二维码")
            return JSONResponse(content={"success": False, "message": "找不到符合条件的二维码图片"})
    except Exception as e:
        logger.error(f"获取二维码时出错: {str(e)}")
        return JSONResponse(content={"success": False, "message": f"获取二维码失败: {str(e)}"})
    
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)