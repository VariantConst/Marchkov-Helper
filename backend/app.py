# backend/app.py

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from routes import router as api_router
import time
import logging
from typing import Callable

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

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
    logging.info(f"请求 {request.url.path} 花费了 {process_time:.2f} 秒")
    return response

# 包含API路由
app.include_router(api_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)