"""
FiscalShieldAI - QFluentKit Demo
财智哨兵 Fluent Design 界面演示
"""
import sys
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QComboBox, QFrame, QGraphicsDropShadowEffect,
    QStackedWidget, QScrollArea, QTextEdit, QTableWidget, QTableWidgetItem,
    QHeaderView, QAbstractItemView, QLineEdit
)
from PyQt6.QtCore import Qt, QPropertyAnimation, QEasingCurve, QSize, QTimer
from PyQt6.QtGui import QFont, QColor, QPalette, QIcon, QPixmap, QPainter, QLinearGradient

from qfluentwidgets import (
    FluentIcon as FIF, FluentWindow, NavigationItemPosition,
    InfoBar, InfoBarPosition, Theme, setTheme,
    PrimaryPushButton, PushButton, ComboBox,
    CardWidget, HyperlinkButton, ToggleButton,
    BodyLabel, CaptionLabel, TitleLabel, SubtitleLabel, LargeTitleLabel,
    MessageBox, SearchLineEdit, Pivot, PillToolButton,
    SmoothScrollArea, Flyout, FlyoutAnimationType
)


class RiskCard(CardWidget):
    """风险等级卡片组件"""
    def __init__(self, title, level, color, confidence, parent=None):
        super().__init__(parent)
        self.setFixedHeight(180)
        self.setMinimumWidth(220)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 16, 20, 16)

        # 标题
        title_label = SubtitleLabel(title)
        layout.addWidget(title_label)

        layout.addSpacing(8)

        # 风险等级
        level_label = TitleLabel(level)
        level_label.setStyleSheet(f"color: {color}; font-size: 28px; font-weight: bold;")
        layout.addWidget(level_label)

        layout.addSpacing(4)

        # 置信度
        conf_label = BodyLabel(f"置信度 {confidence}%")
        conf_label.setStyleSheet("color: #909399;")
        layout.addWidget(conf_label)

        layout.addStretch()

        # 左侧彩色边条
        self.setStyleSheet(f"""
            CardWidget {{
                border-left: 4px solid {color};
                border-radius: 12px;
                background: white;
            }}
        """)


class MainWindow(FluentWindow):
    """主窗口 - Fluent Design"""
    def __init__(self):
        super().__init__()
        self.setWindowTitle("🛡️ 财智哨兵 - FiscalShieldAI")
        self.setMinimumSize(1200, 800)
        self.resize(1400, 900)

        # 设置主题
        setTheme(Theme.DARK)

        # 创建页面
        self.homeInterface = self._create_home_page()
        self.homeInterface.setObjectName("homeInterface")
        self.predictInterface = self._create_predict_page()
        self.predictInterface.setObjectName("predictInterface")
        self.reportInterface = self._create_report_page()
        self.reportInterface.setObjectName("reportInterface")

        # 添加导航
        self.addSubInterface(self.homeInterface, FIF.HOME, "首页")
        self.addSubInterface(self.predictInterface, FIF.CHECKBOX, "风险预测")
        self.addSubInterface(self.reportInterface, FIF.DOCUMENT, "AI报告")

    def _create_home_page(self):
        """首页 - 项目概览"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(40, 30, 40, 30)
        layout.setSpacing(20)

        # 大标题
        title = LargeTitleLabel("🛡️ 财智哨兵")
        title.setStyleSheet("font-size: 36px; font-weight: bold;")
        layout.addWidget(title)

        subtitle = SubtitleLabel("地方财政风险智能预警系统 — FiscalShieldAI")
        subtitle.setStyleSheet("color: #909399; font-size: 16px;")
        layout.addWidget(subtitle)

        layout.addSpacing(20)

        # 三张角色卡片
        cards_layout = QHBoxLayout()
        cards_layout.setSpacing(20)

        roles = [
            ("🏛️ 政务版", "标准化 · 高合规\n数据不出域", "#409EFF"),
            ("🏢 企业版", "团队协作 · 深度分析\n数据安全", "#67C23A"),
            ("👤 民用版", "轻量易用 · 隐私优先", "#E6A23C"),
        ]

        for title_text, desc, color in roles:
            card = CardWidget()
            card.setFixedHeight(200)
            card_layout = QVBoxLayout(card)
            card_layout.setContentsMargins(24, 20, 24, 20)

            icon_label = QLabel(title_text.split()[0])
            icon_label.setStyleSheet("font-size: 36px;")
            card_layout.addWidget(icon_label)

            card_layout.addSpacing(8)

            name_label = TitleLabel(title_text.split()[1] if len(title_text.split()) > 1 else title_text)
            name_label.setStyleSheet(f"color: {color}; font-weight: bold;")
            card_layout.addWidget(name_label)

            desc_label = BodyLabel(desc)
            desc_label.setStyleSheet("color: #909399;")
            card_layout.addWidget(desc_label)

            card_layout.addStretch()

            card.setStyleSheet(f"""
                CardWidget {{
                    border: 2px solid {color}20;
                    border-radius: 16px;
                    background: white;
                }}
            """)

            cards_layout.addWidget(card)

        layout.addLayout(cards_layout)

        layout.addSpacing(20)

        # 技术亮点
        highlights = QFrame()
        highlights.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #1a1a2e, stop:1 #16213e);
                border-radius: 16px;
                padding: 30px;
            }
        """)
        hl_layout = QVBoxLayout(highlights)
        hl_layout.setContentsMargins(30, 24, 30, 24)

        hl_title = TitleLabel("✨ 核心技术亮点")
        hl_title.setStyleSheet("color: white; font-size: 20px;")
        hl_layout.addWidget(hl_title)

        hl_layout.addSpacing(16)

        features = [
            "🧠 知识蒸馏压缩：118K参数 → 2K参数（83%压缩），准确率100%",
            "⚡ 双引擎架构：小模型数值推理（6ms）+ 大模型报告生成",
            "👥 三角色一体化：一套引擎服务政务/企业/民用三类用户",
            "📦 端侧友好：2,026参数，15KB模型，CPU推理<1ms",
        ]

        for feat in features:
            feat_label = BodyLabel(feat)
            feat_label.setStyleSheet("color: #E0E0E0; font-size: 14px;")
            hl_layout.addWidget(feat_label)

        layout.addWidget(highlights)
        layout.addStretch()

        return widget

    def _create_predict_page(self):
        """预测页面"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(40, 30, 40, 30)
        layout.setSpacing(20)

        # 标题
        title = TitleLabel("📊 风险预测")
        layout.addWidget(title)

        # 输入区
        input_frame = CardWidget()
        input_frame.setStyleSheet("CardWidget { border-radius: 12px; background: white; }")
        input_layout = QHBoxLayout(input_frame)
        input_layout.setContentsMargins(24, 16, 24, 16)
        input_layout.setSpacing(16)

        input_layout.addWidget(BodyLabel("城市"))
        city_combo = ComboBox()
        city_combo.addItems(["南京", "苏州", "无锡", "常州", "镇江"])
        city_combo.setFixedWidth(120)
        input_layout.addWidget(city_combo)

        input_layout.addWidget(BodyLabel("年份"))
        year_combo = ComboBox()
        year_combo.addItems(["2023", "2024", "2025", "2026"])
        year_combo.setFixedWidth(100)
        input_layout.addWidget(year_combo)

        input_layout.addStretch()

        predict_btn = PrimaryPushButton("🚀 开始预测")
        predict_btn.setFixedWidth(160)
        predict_btn.setFixedHeight(40)
        input_layout.addWidget(predict_btn)

        layout.addWidget(input_frame)

        # 风险结果卡片
        cards_layout = QHBoxLayout()
        cards_layout.setSpacing(16)

        cards_layout.addWidget(RiskCard("财政风险", "中等偏低", "#8BC34A", "72.0"))
        cards_layout.addWidget(RiskCard("金融风险", "低风险", "#4CAF50", "85.0"))
        cards_layout.addWidget(RiskCard("综合风险", "中等偏低", "#8BC34A", "72.0"))

        layout.addLayout(cards_layout)

        # 预警横幅
        warning_frame = CardWidget()
        warning_frame.setStyleSheet("""
            CardWidget {
                background: #FFF3E0;
                border-left: 4px solid #FF9800;
                border-radius: 8px;
            }
        """)
        warning_layout = QHBoxLayout(warning_frame)
        warning_layout.setContentsMargins(20, 12, 20, 12)
        warning_icon = QLabel("🔵")
        warning_layout.addWidget(warning_icon)
        warning_text = BodyLabel("蓝色预警！检测到中等偏低风险（置信度72.0%），建议定期监测。")
        warning_text.setStyleSheet("color: #E65100; font-weight: bold;")
        warning_layout.addWidget(warning_text)
        warning_layout.addStretch()
        layout.addWidget(warning_frame)

        # 指标详情表格
        table_label = SubtitleLabel("📋 9项核心指标")
        layout.addWidget(table_label)

        table = QTableWidget(9, 4)
        table.setHorizontalHeaderLabels(["指标名称", "当前值", "安全线", "状态"])
        table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        table.setAlternatingRowColors(True)
        table.setStyleSheet("""
            QTableWidget {
                background: white;
                border-radius: 8px;
                border: 1px solid #E0E6ED;
                gridline-color: #F0F2F5;
                font-size: 13px;
            }
            QTableWidget::item {
                padding: 8px 12px;
            }
            QHeaderView::section {
                background: #F5F7FA;
                border: none;
                border-bottom: 2px solid #E0E6ED;
                padding: 10px;
                font-weight: bold;
                font-size: 13px;
            }
            QTableWidget::item:selected {
                background: #E3F2FD;
            }
        """)

        indicators = [
            ("负债率", "15.1%", "< 60%", "✅ 正常", "#4CAF50"),
            ("债务率", "71.0%", "< 100%", "✅ 正常", "#4CAF50"),
            ("赤字率", "2.8%", "< 3%", "⚠️ 接近", "#FF9800"),
            ("现金短期债务比", "1.07", "> 1.0", "✅ 正常", "#4CAF50"),
            ("短期债务占比", "25.8%", "< 30%", "✅ 正常", "#4CAF50"),
            ("存贷比", "99.3%", "< 100%", "⚠️ 接近", "#FF9800"),
            ("不良贷款率", "0.80%", "< 2%", "✅ 正常", "#4CAF50"),
            ("拨备覆盖率", "330.0%", "> 150%", "✅ 正常", "#4CAF50"),
            ("资本充足率", "16.9%", "> 10.5%", "✅ 正常", "#4CAF50"),
        ]

        for row, (name, value, safe, status, color) in enumerate(indicators):
            table.setItem(row, 0, QTableWidgetItem(name))
            table.setItem(row, 1, QTableWidgetItem(value))
            table.setItem(row, 2, QTableWidgetItem(safe))

            status_item = QTableWidgetItem(status)
            status_item.setForeground(QColor(color))
            table.setItem(row, 3, status_item)

            # 行高
            table.setRowHeight(row, 45)

        layout.addWidget(table)
        layout.addStretch()

        return widget

    def _create_report_page(self):
        """AI报告页面"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(40, 30, 40, 30)
        layout.setSpacing(20)

        title = TitleLabel("🤖 AI智能分析报告")
        layout.addWidget(title)

        # 报告内容
        report_frame = CardWidget()
        report_frame.setStyleSheet("CardWidget { border-radius: 12px; background: white; }")
        report_layout = QVBoxLayout(report_frame)
        report_layout.setContentsMargins(30, 24, 30, 24)
        report_layout.setSpacing(16)

        report_content = QTextEdit()
        report_content.setReadOnly(True)
        report_content.setStyleSheet("""
            QTextEdit {
                border: none;
                background: transparent;
                font-size: 14px;
                line-height: 1.6;
            }
        """)
        report_content.setHtml("""
        <h2 style="color: #303133;">📊 风险概况</h2>
        <p>南京市2026年财政风险等级为<strong style="color: #8BC34A;">"中等偏低"</strong>，
        金融风险等级为<strong style="color: #4CAF50;">"低风险"</strong>，综合风险等级为
        <strong style="color: #8BC34A;">"中等偏低"</strong>。</p>

        <h2 style="color: #303133;">📈 关键发现</h2>
        <ul>
            <li>负债率15.1%，远低于60%安全线，债务规模控制良好</li>
            <li>赤字率2.8%，接近3%国际警戒线，需持续关注</li>
            <li>存贷比99.3%，接近100%安全线，资金运用效率需优化</li>
            <li>拨备覆盖率330%，远超150%要求，风险抵御能力强</li>
        </ul>

        <h2 style="color: #303133;">⚠️ 风险预警</h2>
        <p style="color: #FF9800;">🔵 <strong>蓝色预警</strong>：赤字率接近警戒线，建议优化财政支出结构，
        控制赤字规模。存贷比偏高，建议加强资金流动性管理。</p>

        <h2 style="color: #303133;">💡 建议</h2>
        <ol>
            <li>关注赤字率变化趋势，制定财政收支平衡方案</li>
            <li>优化存贷结构，提高资金使用效率</li>
            <li>保持拨备覆盖率优势，持续增强风险抵御能力</li>
            <li>建议每季度进行一次风险评估，动态监测指标变化</li>
        </ol>

        <p style="color: #909399; font-size: 12px; margin-top: 20px;">
        📅 报告生成时间：2026-06-26 | 🤖 生成引擎：vivo蓝心大模型 | 📊 数据来源：小模型推理结果
        </p>
        """)
        report_layout.addWidget(report_content)

        layout.addWidget(report_frame)
        layout.addStretch()

        return widget


if __name__ == "__main__":
    app = QApplication(sys.argv)

    # 设置全局字体
    font = QFont("Microsoft YaHei", 10)
    app.setFont(font)

    window = MainWindow()
    window.show()

    sys.exit(app.exec())
