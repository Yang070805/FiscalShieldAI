@echo off
chcp 65001 >nul
echo ==========================================
echo   Fiscal Shield AI - 环境初始化 (Windows)
echo ==========================================

echo.
echo [检测 Python 环境]
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo   ❌ 未找到 Python，请先安装 Python 3.10 或 3.12
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version') do echo   找到: %%i

where python3.10 >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('python3.10 --version') do echo   找到: %%i
    set TRAIN_PY=python3.10
) else (
    echo   ⚠️  未找到 python3.10，训练环境将使用默认 Python
    set TRAIN_PY=python
)

echo.
echo ==========================================
echo   环境 A：推理服务（默认 Python，运行 api_server.py）
echo ==========================================
echo.
echo   安装推理服务依赖...
pip install requests torch pandas numpy scikit-learn joblib openpyxl
if %errorlevel% neq 0 (
    echo   ⚠️  部分依赖安装失败，请检查网络
)

echo.
echo ==========================================
echo   环境 B：模型训练（需要 torch-geometric）
echo ==========================================
echo.
echo   建议在 PyCharm 中创建 Python 3.10 虚拟环境：
echo   Settings → Project → Python Interpreter → Add → Virtualenv
echo   Base Interpreter: Python 3.10
echo.
echo   然后在虚拟环境中执行：
echo   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
echo   pip install torch-geometric
echo   pip install pandas numpy scikit-learn openpyxl joblib requests

echo.
echo ==========================================
echo   创建项目目录
echo ==========================================
if not exist "checkpoints" mkdir checkpoints
if not exist "data" mkdir data
echo   ✅ checkpoints\ 和 data\ 目录已创建

echo.
echo ==========================================
echo   初始化完成！
echo ==========================================
echo.
echo   使用方法：
echo   1. 将数据文件放入 data\ 目录
echo      文件格式：南京_data.xlsx, 南京_labels.xlsx 等
echo.
echo   2. 训练教师模型（Python 3.10 虚拟环境）：
echo      python train_teacher.py --data_dir ./data --epochs 100
echo.
echo   3. 知识蒸馏训练（Python 3.10 虚拟环境）：
echo      python train_distill.py --teacher_checkpoint ./checkpoints/best_teacher_model.pth --data_dir ./data
echo.
echo   4. 启动推理服务（默认 Python）：
echo      python api_server.py --port 9527
echo.
echo   5. 设置 MiMo API Key（可选）：
echo      set MIMO_API_KEY=your-key
echo      set MIMO_BASE_URL=https://api.xiaomi.com/v1
echo.
pause
