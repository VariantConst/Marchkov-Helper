# backend/app.py

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from routes import router as api_router
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import os
from typing import Callable
from datetime import datetime

# 创建logs文件夹(如果不存在)
if not os.path.exists('logs'):
    os.makedirs('logs')

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# 移除所有现有的处理程序
for handler in logger.handlers[:]:
    logger.removeHandler(handler)

# 获取当前日期并格式化为字符串
current_date = datetime.now().strftime('%Y-%m-%d')

# 创建TimedRotatingFileHandler
file_handler = TimedRotatingFileHandler(
    filename=f'logs/app_{current_date}.log',
    when='midnight',
    interval=1,
    backupCount=30,
    encoding='utf-8'
)

# 设置日志格式
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
file_handler.setFormatter(formatter)

# 将处理程序添加到logger
logger.addHandler(file_handler)

app = FastAPI()

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def add_process_time_header(request: Request, call_next: Callable) -> Callable:
    """
    添加处理时间头的中间件。

    :param request: 请求对象
    :param call_next: 下一个要调用的函数
    :return: 响应对象
    """
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    logging.info(f"请求 {request.url.path} 花费了 {process_time:.2f} 秒\n")
    return response

# 包含API路由
app.include_router(api_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)