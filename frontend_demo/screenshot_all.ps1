# PowerShell - 截取所有页面
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyType System.Drawing

$python = "C:\Users\HUAWEI\AppData\Local\Programs\Python\Python312\python.exe"
$screenshotDir = "D:\FiscalShieldAI\frontend_demo\screenshots"
New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null

function Take-Screenshot {
    param([string]$FileName)
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $bitmap = New-Object System.Drawing.Bitmap($screen.Bounds.Width, $screen.Bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.Bounds.Location, [System.Drawing.Point]::Empty, $screen.Bounds.Size)
    $bitmap.Save($FileName)
    $graphics.Dispose()
    $bitmap.Dispose()
    Write-Host "Saved: $FileName"
}

# 启动demo
$proc = Start-Process -FilePath $python -ArgumentList "D:\FiscalShieldAI\frontend_demo\demo.py" -PassThru
Start-Sleep -Seconds 3

# 截图1：首页
Take-Screenshot "$screenshotDir\01_home.png"

# 模拟切换到预测页（通过键盘快捷键或点击）
# QFluentKit的导航栏可以用Ctrl+Tab切换，或者我们用AutoHotKey风格的方式
# 简单方案：用Python脚本切换页面

Write-Host "Done! Check screenshots folder."
Write-Host "Press any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
