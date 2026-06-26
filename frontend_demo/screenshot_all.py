"""
FiscalShieldAI - 自动截取所有页面
"""
import sys
import os
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
from PyQt6.QtGui import QFont

from demo import MainWindow


def main():
    os.makedirs("D:/FiscalShieldAI/frontend_demo/screenshots", exist_ok=True)

    app = QApplication(sys.argv)
    font = QFont("Microsoft YaHei", 10)
    app.setFont(font)

    window = MainWindow()
    window.resize(1400, 900)
    window.show()

    def capture_home():
        screen = app.primaryScreen()
        if screen:
            pixmap = screen.grabWindow(window.winId())
            pixmap.save("D:/FiscalShieldAI/frontend_demo/screenshots/01_home.png")
            print("Captured: 01_home.png")
            # 切换到预测页
            window.stackedWidget.setCurrentIndex(1)
            QTimer.singleShot(800, capture_predict)

    def capture_predict():
        screen = app.primaryScreen()
        if screen:
            pixmap = screen.grabWindow(window.winId())
            pixmap.save("D:/FiscalShieldAI/frontend_demo/screenshots/02_predict.png")
            print("Captured: 02_predict.png")
            # 切换到报告页
            window.stackedWidget.setCurrentIndex(2)
            QTimer.singleShot(800, capture_report)

    def capture_report():
        screen = app.primaryScreen()
        if screen:
            pixmap = screen.grabWindow(window.winId())
            pixmap.save("D:/FiscalShieldAI/frontend_demo/screenshots/03_report.png")
            print("Captured: 03_report.png")
            print("All screenshots done!")
            app.quit()

    # 1秒后开始截图
    QTimer.singleShot(1000, capture_home)
    app.exec()


if __name__ == "__main__":
    main()
