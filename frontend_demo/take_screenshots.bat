@echo off
echo 正在截图...
cd /d D:\FiscalShieldAI\frontend_demo
mkdir screenshots 2>nul
python screenshot.py
echo.
echo 截图完成！查看 screenshots 文件夹
pause
