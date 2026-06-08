"""
quick_test.py — 财智哨兵 交互式测试脚本（增强版 v3）
使用方法：
  1. 先启动服务：python api_server.py --port 9527
  2. 再开窗口运行：python quick_test.py
"""

import socket
import json
import sys

SERVER_HOST = '127.0.0.1'
SERVER_PORT = 9527

# 支持的城市列表（与 data/ 目录下的 xlsx 文件对应）
SUPPORTED_CITIES = ["南京", "苏州", "无锡", "常州", "镇江"]

INDICATOR_FIELDS = [
    ("负债率(%)", "负债率", "债务占GDP的比例"),
    ("债务率(%)", "债务率", "债务占财政收入的比例"),
    ("赤字率(%)", "赤字率", "财政赤字占GDP的比例"),
    ("现金短期债务比", "现金短期债务比", "现金与短期债务的比值"),
    ("短期债务占比(%)", "短期债务占比", "短期债务占总债务的比例"),
    ("存贷比(%)", "存贷比", "贷款与存款的比值"),
    ("不良贷款率(%)", "不良贷款率", "不良贷款占总贷款的比例"),
    ("拨备覆盖率(%)", "拨备覆盖率", "拨备与不良贷款的比值"),
    ("资本充足率(%)", "资本充足率", "资本与风险资产的比值"),
]


def send_request(action, data=None):
    """发送请求到服务端"""
    request = {"action": action}
    if data:
        request.update(data)

    try:
        s = socket.socket()
        s.connect((SERVER_HOST, SERVER_PORT))
        s.sendall(json.dumps(request, ensure_ascii=False).encode("utf-8"))
        response = s.recv(65536).decode("utf-8")
        s.close()
        return json.loads(response)
    except ConnectionRefusedError:
        print(f"\n❌ 无法连接服务端 ({SERVER_HOST}:{SERVER_PORT})")
        print("   请确认 api_server.py 已启动！")
        sys.exit(1)


def get_input_indicators():
    """交互式获取用户输入的指标值"""
    print("\n请输入以下 9 个指标的数值：\n")

    indicators = {}
    for label, key, desc in INDICATOR_FIELDS:
        while True:
            try:
                val = input(f"  {label}（{desc}）: ").strip()
                indicators[key] = float(val)
                break
            except ValueError:
                print(f"  ❌ 请输入有效的数字")

    return indicators


def linear_extrapolate(historical_data, target_year):
    """
    根据历史数据线性外推目标年份的指标
    historical_data: [(year, {指标: 值}), ...]
    返回: {指标: 推算值}
    """
    years = [item[0] for item in historical_data]
    n = len(years)

    if n < 2:
        # 只有1年数据，直接返回
        return historical_data[0][1]

    # 对每个指标做线性回归 y = a*x + b
    indicators = {}
    for label, key, desc in INDICATOR_FIELDS:
        values = [item[1].get(key, 0) for item in historical_data]

        # 最小二乘法
        sum_x = sum(years)
        sum_y = sum(values)
        sum_xy = sum(x * y for x, y in zip(years, values))
        sum_x2 = sum(x * x for x in years)

        denom = n * sum_x2 - sum_x * sum_x
        if denom == 0:
            indicators[key] = values[-1]  # 无法回归，取最后一个值
        else:
            a = (n * sum_xy - sum_x * sum_y) / denom
            b = (sum_y - a * sum_x) / n
            predicted = a * target_year + b
            indicators[key] = round(predicted, 2)

    return indicators


def trend_extrapolate(city, target_year):
    """
    趋势外推模式：输入历史年份数据，自动推算目标年份
    """
    print("\n" + "=" * 50)
    print(f"  📈 趋势外推模式：{city} → {target_year}年")
    print("=" * 50)

    # 输入历史年份数量
    while True:
        try:
            n_years = int(input("\n  你有几年的历史数据？(2-5): ").strip())
            if 2 <= n_years <= 5:
                break
            print("  ❌ 请输入 2~5 之间的数字")
        except ValueError:
            print("  ❌ 请输入有效数字")

    historical_data = []

    for i in range(n_years):
        print(f"\n  --- 第 {i+1} 年的数据 ---")
        while True:
            try:
                year = int(input(f"  年份: ").strip())
                break
            except ValueError:
                print("  ❌ 请输入有效的年份")

        print(f"  请输入 {year} 年的 9 个指标：")
        indicators = {}
        for label, key, desc in INDICATOR_FIELDS:
            while True:
                try:
                    val = input(f"    {label}（{desc}）: ").strip()
                    indicators[key] = float(val)
                    break
                except ValueError:
                    print("    ❌ 请输入有效的数字")

        historical_data.append((year, indicators))

    # 排序
    historical_data.sort(key=lambda x: x[0])

    # 展示历史数据
    print("\n" + "-" * 50)
    print("  📊 历史数据汇总：")
    for year, ind in historical_data:
        print(f"  {year}年: 负债率={ind.get('负债率',0)}%, 债务率={ind.get('债务率',0)}%, 赤字率={ind.get('赤字率',0)}%")

    # 外推
    print(f"\n  ⏳ 正在根据趋势推算 {target_year} 年的指标...")
    predicted = linear_extrapolate(historical_data, target_year)

    print(f"\n  📈 {target_year} 年推算结果：")
    for label, key, desc in INDICATOR_FIELDS:
        print(f"    {label}: {predicted[key]}")

    # 确认是否使用推算值
    print()
    choice = input("  使用以上推算值进行预测？(y=使用 / n=手动修改): ").strip().lower()

    if choice == "n":
        print("\n  请输入要修改的指标（直接回车保留推算值）：")
        for label, key, desc in INDICATOR_FIELDS:
            val = input(f"    {label}（当前: {predicted[key]}，{desc}）: ").strip()
            if val:
                try:
                    predicted[key] = float(val)
                except ValueError:
                    print(f"    ⚠️ 输入无效，保留推算值 {predicted[key]}")

    # 发送预测请求
    print(f"\n  ⏳ AI 正在分析 {city} {target_year} 年的财政风险...")
    result = send_request("predict_custom", {"indicators": predicted})
    print_result(result)


def print_result(result):
    """格式化打印预测结果"""
    if result.get("status") != "ok":
        print(f"\n❌ 错误: {result.get('message', '未知错误')}")
        return

    print("\n" + "=" * 50)
    print("  预测结果")
    print("=" * 50)

    fiscal = result.get("fiscal_risk", {})
    finance = result.get("finance_risk", {})
    overall = result.get("overall_risk", {})
    warning = result.get("warning", {})

    print(f"\n  财政风险: {fiscal.get('level', 'N/A')}  "
          f"(置信度 {fiscal.get('confidence', 0):.0%})")
    print(f"  金融风险: {finance.get('level', 'N/A')}  "
          f"(置信度 {finance.get('confidence', 0):.0%})")
    print(f"  综合风险: {overall.get('level', 'N/A')}")
    print(f"  预警等级: {warning.get('level', 'N/A')}")
    print(f"  推理耗时: {result.get('performance', {}).get('inference_time_ms', 0):.1f} ms")

    report = result.get("ai_report", "")
    if report:
        print("\n" + "=" * 50)
        print("  AI 分析报告")
        print("=" * 50)
        print(report)


def mode_city():
    """城市+年份模式（数据不存在时自动切换趋势外推）"""
    print("\n" + "=" * 50)
    print("  🏙️ 城市+年份预测模式")
    print("=" * 50)
    print(f"\n  支持的城市: {', '.join(SUPPORTED_CITIES)}")

    while True:
        city = input("\n  请输入城市名称: ").strip()
        if city in SUPPORTED_CITIES:
            break
        print(f"  ❌ 「{city}」不在支持列表中，请重新输入")

    while True:
        try:
            year = int(input("  请输入年份 (如 2026): ").strip())
            break
        except ValueError:
            print("  ❌ 请输入有效的年份数字")

    print(f"\n  ⏳ 正在查询 {city} {year} 年的数据...")
    result = send_request("predict", {"city": city, "year": year})

    if result.get("status") == "ok":
        print_result(result)
    else:
        # 数据不存在，进入趋势外推
        print(f"\n  ⚠️ {city} {year} 年的数据不存在")
        print(f"  🔄 自动切换到趋势外推模式")
        trend_extrapolate(city, year)


def mode_custom():
    """自定义指标模式"""
    print("\n" + "=" * 50)
    print("  📊 自定义指标预测模式")
    print("=" * 50)

    indicators = get_input_indicators()
    print("\n  ⏳ AI 正在分析中...")
    result = send_request("predict_custom", {"indicators": indicators})
    print_result(result)


def main():
    while True:
        print("\n" + "=" * 50)
        print("  「财智哨兵」交互式测试")
        print("=" * 50)
        print("\n  请选择模式：")
        print(f"  1. 城市+年份预测（支持: {', '.join(SUPPORTED_CITIES)}）")
        print("  2. 自定义指标预测（手动输入9个指标）")
        print("  3. 退出")

        choice = input("\n  请输入选项 (1/2/3): ").strip()

        if choice == "1":
            mode_city()
        elif choice == "2":
            mode_custom()
        elif choice == "3":
            print("\n  再见！")
            break
        else:
            print("  ❌ 无效选项，请重新输入")
            continue

        print()
        again = input("  继续测试？(y/n): ").strip().lower()
        if again != "y":
            print("\n  再见！")
            break


if __name__ == "__main__":
    main()
