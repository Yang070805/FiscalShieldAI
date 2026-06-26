# PowerShell截图脚本
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "正在启动FiscalShieldAI Demo..." -ForegroundColor Green

# 启动Python demo
$python = "C:\Users\HUAWEI\AppData\Local\Programs\Python\Python312\python.exe"
$demo = "D:\FiscalShieldAI\frontend_demo\demo.py"
$proc = Start-Process -FilePath $python -ArgumentList $demo -PassThru

# 等待窗口出现
Start-Sleep -Seconds 3

# 截图函数
function Take-Screenshot {
    param([string]$FileName)
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $bitmap = New-Object System.Drawing.Bitmap($screen.Bounds.Width, $screen.Bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.Bounds.Location, [System.Drawing.Point]::Empty, $screen.Bounds.Size)
    $bitmap.Save($FileName)
    $graphics.Dispose()
    $bitmap.Dispose()
    Write-Host "✅ 已保存: $FileName" -ForegroundColor Yellow
}

$screenshotDir = "D:\FiscalShieldAI\frontend_demo\screenshots"
New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null

# 截图
Take-Screenshot "$screenshotDir\01_home.png"

Write-Host "`n🎉 截图完成！查看: $screenshotDir" -ForegroundColor Green
Write-Host "按任意键关闭Demo..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# 关闭Demo
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
