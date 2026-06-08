"""
add_data.py — 向 Excel 数据文件追加新年份的数据
用法：python add_data.py
"""
import pandas as pd

city = input("城市名（如 南京）: ").strip()
year = int(input("年份: ").strip())

file_path = f"data/{city}_data.xlsx"

# 读取现有数据
df = pd.read_excel(file_path)

# 输入新数据
new_data = {"年份": year}
columns = [
    ("负债率(%)", "负债率"),
    ("债务率(%)", "债务率"),
    ("赤字率(%)", "赤字率"),
    ("现金短期债务比", "现金短期债务比"),
    ("短期债务占比(%)", "短期债务占比"),
    ("存贷比(%)", "存贷比"),
    ("不良贷款率(%)", "不良贷款率"),
    ("拨备覆盖率(%)", "拨备覆盖率"),
    ("资本充足率(%)", "资本充足率"),
]

for col_name, desc in columns:
    val = float(input(f"  {col_name}: ").strip())
    new_data[col_name] = val

# 追加并保存
df = pd.concat([df, pd.DataFrame([new_data])], ignore_index=True)
df.to_excel(file_path, index=False)
print(f"✅ 已将 {year} 年数据添加到 {file_path}")
