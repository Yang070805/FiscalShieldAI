"""
计算5个城市的平均同比变化率
在Windows上运行: python ai_engine/compute_avg_change_rates.py
"""
import pandas as pd
import numpy as np
from pathlib import Path

data_dir = Path('ai_engine/data')
features = [
    '负债率(%)', '债务率(%)', '赤字率(%)',
    '现金短期债务比', '短期债务占比(%)',
    '存贷比(%)',
    '不良贷款率(%)', '拨备覆盖率(%)', '资本充足率(%)'
]

all_change_rates = []

for f in data_dir.glob('*_data.xlsx'):
    city = f.stem.replace('_data', '')
    df = pd.read_excel(str(f))
    df = df.sort_values('年份').reset_index(drop=True)

    for i in range(1, len(df)):
        prev = df.iloc[i-1]
        curr = df.iloc[i]
        changes = []
        for feat in features:
            prev_val = prev[feat]
            curr_val = curr[feat]
            if pd.notna(prev_val) and pd.notna(curr_val) and prev_val != 0:
                rate = (curr_val - prev_val) / abs(prev_val)
            else:
                rate = 0.0
            changes.append(rate)
        all_change_rates.append(changes)

avg_rates = np.mean(all_change_rates, axis=0)

print("=" * 60)
print("5城平均同比变化率")
print("=" * 60)
for feat, rate in zip(features, avg_rates):
    print(f"  {feat}: {rate:.6f}")

print()
print("复制以下代码粘贴到 inference.py 的 predict_from_indicators 方法中：")
print()
print("DEFAULT_AVG_CHANGE_RATES = [")
for i, rate in enumerate(avg_rates):
    comma = "," if i < len(avg_rates) - 1 else ""
    print(f"    {rate:.6f}{comma}  # {features[i]}")
print("]")
