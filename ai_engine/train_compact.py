"""
LightTCN Compact 模型训练脚本

使用真实数据训练 compact 版本（2,026参数）
替换当前 11,786 参数的基线模型

用法：
    cd ai_engine
    python train_compact.py
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
import pandas as pd
from pathlib import Path
from datetime import datetime
import json
import warnings
warnings.filterwarnings('ignore')


class LightTCNCompact(nn.Module):
    """Compact LightTCN — 2,026 参数"""

    def __init__(self, input_channels=9, hidden_channels=12, output_dim=24,
                 num_classes=5, dropout=0.1):
        super().__init__()

        self.conv1 = nn.Conv1d(input_channels, hidden_channels,
                               kernel_size=3, dilation=1, padding=1)
        self.bn1 = nn.BatchNorm1d(hidden_channels)

        self.conv2 = nn.Conv1d(hidden_channels, output_dim,
                               kernel_size=3, dilation=2, padding=2)
        self.bn2 = nn.BatchNorm1d(output_dim)

        self.global_pool = nn.AdaptiveAvgPool1d(1)
        self.dropout = nn.Dropout(dropout)

        self.fiscal_head = nn.Sequential(
            nn.Linear(output_dim, output_dim // 2),
            nn.ReLU(), self.dropout,
            nn.Linear(output_dim // 2, num_classes)
        )
        self.finance_head = nn.Sequential(
            nn.Linear(output_dim, output_dim // 2),
            nn.ReLU(), self.dropout,
            nn.Linear(output_dim // 2, num_classes)
        )

    def forward(self, x):
        x = x.transpose(1, 2)
        x = self.conv1(x)
        x = self.bn1(x)
        x = F.relu(x)
        x = self.dropout(x)
        x = self.conv2(x)
        x = self.bn2(x)
        x = F.relu(x)
        x = self.dropout(x)
        x = self.global_pool(x)
        x = x.squeeze(-1)
        return self.fiscal_head(x), self.finance_head(x)


def load_city_data(data_dir, cities=None):
    """加载所有城市数据，生成3年窗口样本"""
    data_dir = Path(data_dir)
    if cities is None:
        cities = [f.stem.replace('_data', '') for f in data_dir.glob('*_data.xlsx')]

    base_features = [
        '负债率(%)', '债务率(%)', '赤字率(%)',
        '现金短期债务比', '短期债务占比(%)',
        '存贷比(%)',
        '不良贷款率(%)', '拨备覆盖率(%)', '资本充足率(%)'
    ]

    # 风险等级 → 数字映射
    risk_map = {'低风险': 0, '中等偏低': 1, '中等': 2, '中等偏高': 3, '高风险': 4}

    all_samples = []

    for city in cities:
        data_file = data_dir / f'{city}_data.xlsx'
        label_file = data_dir / f'{city}_labels.xlsx'

        if not data_file.exists() or not label_file.exists():
            print(f"  跳过 {city}: 数据文件不完整")
            continue

        df = pd.read_excel(str(data_file))
        labels = pd.read_excel(str(label_file))

        if '年份' not in df.columns:
            continue

        df = df.sort_values('年份').reset_index(drop=True)
        years = sorted(df['年份'].unique())

        # 生成3年窗口样本
        for i in range(2, len(years)):
            window_years = years[i-2:i+1]
            window_data = df[df['年份'].isin(window_years)]

            if len(window_data) < 3:
                continue

            # 提取特征
            features_list = []
            for y in window_years:
                row = window_data[window_data['年份'] == y]
                if row.empty:
                    break
                feats = []
                for feat in base_features:
                    if feat in row.columns:
                        val = row[feat].iloc[0]
                        feats.append(float(val) if pd.notna(val) else 0.0)
                    else:
                        feats.append(0.0)
                features_list.append(feats)

            if len(features_list) < 3:
                continue

            # 标签：用目标年份（第3年）的标签
            target_year = years[i]
            target_label = labels[labels['年份'] == target_year] if '年份' in labels.columns else labels.iloc[:1]

            if target_label.empty:
                continue

            # 获取财政和金融风险标签
            fiscal_col = [c for c in labels.columns if '财政' in c or 'fiscal' in c.lower()]
            finance_col = [c for c in labels.columns if '金融' in c or 'finance' in c.lower()]

            if fiscal_col and finance_col:
                f_raw = target_label[fiscal_col[0]].iloc[0]
                fi_raw = target_label[finance_col[0]].iloc[0]
                # 如果是中文标签，转数字；如果是数字，直接用
                if isinstance(f_raw, str):
                    fiscal_label = risk_map.get(f_raw, 2)
                else:
                    fiscal_label = int(f_raw)
                if isinstance(fi_raw, str):
                    finance_label = risk_map.get(fi_raw, 2)
                else:
                    finance_label = int(fi_raw)
            else:
                # 如果没有分列标签，用第一个和第二个数值列
                num_cols = labels.select_dtypes(include=[np.number]).columns.tolist()
                if len(num_cols) >= 2:
                    fiscal_label = int(target_label[num_cols[0]].iloc[0])
                    finance_label = int(target_label[num_cols[1]].iloc[0])
                else:
                    continue

            # 限制标签范围 [0, 4]
            fiscal_label = max(0, min(4, fiscal_label))
            finance_label = max(0, min(4, finance_label))

            X = np.array(features_list, dtype=np.float32)  # (3, 9)
            all_samples.append((X, fiscal_label, finance_label, city, int(target_year)))

    print(f"  共生成 {len(all_samples)} 个样本（来自 {len(cities)} 个城市）")
    return all_samples, base_features


def train_compact_model():
    """训练 compact 模型"""
    print("=" * 60)
    print("  LightTCN Compact 训练")
    print("=" * 60)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"设备: {device}")

    # 1. 加载数据
    print("\n[1/4] 加载数据...")
    data_dir = Path('data')
    samples, base_features = load_city_data(data_dir)

    if len(samples) == 0:
        print("❌ 没有找到有效数据！请检查 data/ 目录下的 xlsx 文件")
        return

    # 打乱数据
    np.random.seed(42)
    np.random.shuffle(samples)

    # 划分训练/验证/测试
    n = len(samples)
    n_train = int(n * 0.7)
    n_val = int(n * 0.15)

    train_samples = samples[:n_train]
    val_samples = samples[n_train:n_train + n_val]
    test_samples = samples[n_train + n_val:]

    print(f"  训练: {len(train_samples)} 样本")
    print(f"  验证: {len(val_samples)} 样本")
    print(f"  测试: {len(test_samples)} 样本")

    # 2. 初始化模型
    print("\n[2/4] 初始化 Compact 模型...")
    model = LightTCNCompact(
        input_channels=9,
        hidden_channels=12,
        output_dim=24,
        num_classes=5,
        dropout=0.1
    ).to(device)

    param_count = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"  参数量: {param_count:,}")

    # 3. 训练
    print("\n[3/4] 开始训练...")
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=8, factor=0.5)
    ce_loss = nn.CrossEntropyLoss()

    epochs = 100
    patience = 15
    best_val_acc = 0
    patience_counter = 0
    best_state = None
    history = {'train_loss': [], 'val_loss': [], 'train_acc': [], 'val_acc': []}

    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0
        correct = 0
        total = 0

        for X, y_fiscal, y_finance, _, _ in train_samples:
            x_tensor = torch.FloatTensor(X).unsqueeze(0).to(device)  # (1, 3, 9)
            y_f = torch.LongTensor([y_fiscal]).to(device)
            y_i = torch.LongTensor([y_finance]).to(device)

            optimizer.zero_grad()
            fiscal_logits, finance_logits = model(x_tensor)
            loss = ce_loss(fiscal_logits, y_f) + ce_loss(finance_logits, y_i)
            loss.backward()
            optimizer.step()

            total_loss += loss.item()
            correct += (fiscal_logits.argmax(1) == y_f).sum().item()
            correct += (finance_logits.argmax(1) == y_i).sum().item()
            total += 2

        train_acc = correct / total
        avg_loss = total_loss / len(train_samples)

        # 验证
        model.eval()
        val_correct = 0
        val_total = 0
        val_loss = 0

        with torch.no_grad():
            for X, y_fiscal, y_finance, _, _ in val_samples:
                x_tensor = torch.FloatTensor(X).unsqueeze(0).to(device)
                y_f = torch.LongTensor([y_fiscal]).to(device)
                y_i = torch.LongTensor([y_finance]).to(device)

                fiscal_logits, finance_logits = model(x_tensor)
                val_loss += ce_loss(fiscal_logits, y_f).item() + ce_loss(finance_logits, y_i).item()
                val_correct += (fiscal_logits.argmax(1) == y_f).sum().item()
                val_correct += (finance_logits.argmax(1) == y_i).sum().item()
                val_total += 2

        val_acc = val_correct / val_total
        scheduler.step(val_loss)

        history['train_loss'].append(avg_loss)
        history['val_loss'].append(val_loss / len(val_samples))
        history['train_acc'].append(train_acc)
        history['val_acc'].append(val_acc)

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            patience_counter = 0
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            best_epoch = epoch
        else:
            patience_counter += 1

        if epoch % 10 == 0 or epoch == 1:
            print(f"  Epoch {epoch:3d} | Loss: {avg_loss:.4f} | Train Acc: {train_acc:.4f} | Val Acc: {val_acc:.4f}")

        if patience_counter >= patience:
            print(f"\n  早停触发！最佳 Epoch: {best_epoch}, Val Acc: {best_val_acc:.4f}")
            break

    # 4. 测试
    print("\n[4/4] 测试集评估...")
    model.load_state_dict(best_state)
    model.eval()

    test_correct = 0
    test_total = 0
    city_results = {}

    with torch.no_grad():
        for X, y_fiscal, y_finance, city, year in test_samples:
            x_tensor = torch.FloatTensor(X).unsqueeze(0).to(device)
            y_f = torch.LongTensor([y_fiscal]).to(device)
            y_i = torch.LongTensor([y_finance]).to(device)

            fiscal_logits, finance_logits = model(x_tensor)
            test_correct += (fiscal_logits.argmax(1) == y_f).sum().item()
            test_correct += (finance_logits.argmax(1) == y_i).sum().item()
            test_total += 2

            # 记录每个城市的预测
            if city not in city_results:
                city_results[city] = []
            city_results[city].append({
                'year': year,
                'fiscal_pred': fiscal_logits.argmax(1).item(),
                'fiscal_true': y_fiscal,
                'finance_pred': finance_logits.argmax(1).item(),
                'finance_true': y_finance,
            })

    test_acc = test_correct / test_total
    print(f"  测试准确率: {test_acc:.4f}")

    # 城市维度结果
    print(f"\n  各城市预测结果:")
    for city, results in city_results.items():
        fiscal_correct = sum(1 for r in results if r['fiscal_pred'] == r['fiscal_true'])
        finance_correct = sum(1 for r in results if r['finance_pred'] == r['finance_true'])
        n = len(results)
        print(f"    {city}: 财政={fiscal_correct}/{n}({fiscal_correct/n:.0%}) 金融={finance_correct}/{n}({finance_correct/n:.0%})")

    # 5. 保存
    save_dir = Path('checkpoints')
    save_dir.mkdir(exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 保存模型
    model_path = save_dir / f'compact_model_{timestamp}.pth'
    torch.save({
        'model_state_dict': best_state,
        'config': {
            'input_channels': 9,
            'hidden_channels': 12,
            'output_dim': 24,
            'num_classes': 5,
            'dropout': 0.1,
        },
        'param_count': param_count,
        'best_epoch': best_epoch,
        'val_acc': best_val_acc,
        'test_acc': test_acc,
    }, model_path)
    print(f"\n  模型已保存: {model_path}")

    # 保存训练历史
    history_path = save_dir / 'compact_training_history.json'
    with open(history_path, 'w', encoding='utf-8') as f:
        json.dump(history, f, indent=2)

    # 保存测试结果
    results_path = save_dir / 'compact_test_results.json'
    with open(results_path, 'w', encoding='utf-8') as f:
        json.dump({
            'test_acc': test_acc,
            'val_acc': best_val_acc,
            'best_epoch': best_epoch,
            'param_count': param_count,
            'city_results': city_results,
        }, f, ensure_ascii=False, indent=2)

    print(f"\n{'='*60}")
    print(f"  ✅ 训练完成！")
    print(f"  参数量: {param_count:,}（比基线少 {11786 - param_count:,}）")
    print(f"  测试准确率: {test_acc:.4f}")
    print(f"  模型文件: {model_path}")
    print(f"{'='*60}")

    return model_path


if __name__ == "__main__":
    train_compact_model()
