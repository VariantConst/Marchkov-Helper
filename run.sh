#!/bin/bash

# 启动 Python 后端
python backend/app.py &

# 启动 React 前端
pnpm run dev -H 0.0.0.0

# 等待所有后台进程完成
wait