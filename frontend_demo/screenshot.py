"""
FiscalShieldAI - 自动截图脚本
运行demo并自动截图保存
"""
import sys
import time
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
from PyQt6.QtGui import QFont

# 导入demo中的MainWindow
from demo import MainWindow


def take_screenshots():
    app = QApplication(sys.argv)
    font = QFont("Microsoft YaHei", 10)
    app.setFont(font)

    window = MainWindow()
    window.resize(1400, 900)
    window.show()

    # 等窗口渲染完成
    def capture():
        # 截图1：首页
        screen = app.primaryScreen()
        if screen:
            pixmap = screen.grabWindow(window.winId())
            pixmap.save("D:/FiscalShieldAI/frontend_demo/screenshots/01_home.png")
            print("✅ 截图1：首页已保存")

            # 切换到预测页
            window.stackedWidget.setCurrentIndex(1)
            QTimer.singleShot(500, capture_predict)

    def capture_predict():
        screen = app.primaryScreen()
        if screen:
            pixmap = screen.grabWindow(window.winId())
            pixmap.save("D:/FiscalShieldAI/frontend_demo/screenshots/02_predict.png")
            print("✅ 截图2：预测页已保存")

            # 切换到报告页
            window.stackedWidget.setCurrentIndex(2)
            QTimer.singleShot(500, capture_report)

    def capture_report():
        screen = app.primaryScreen()
        if screen:
            pixmap = screen.grabWindow(window.winId())
            pixmap.save("D:/FiscalShieldAI/frontend_demo/screenshots/03_report.png")
            print("✅ 截图3：AI报告页已保存")
            print("\n🎉 全部截图完成！")
            app.quit()

    QTimer.singleShot(1000, capture)
    app.exec()


if __name__ == "__main__":
    import os
    os.makedirs("D:/FiscalShieldAI/frontend_demo/screenshots", exist_ok=True)
    take_screenshots()
