"""
LightTCN 调参对比脚本

测试不同模型配置，对比：
- 参数量
- 训练/验证准确率
- 推理速度
- 模型大小

用法：
    cd ai_engine
    python tune_lighttcn.py
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
import time
import json
from pathlib import Path
from datetime import datetime


# ============================================================
# 候选配置
# ============================================================
CONFIGS = {
    "current": {
        "desc": "当前模型（基线）",
        "hidden_channels": 32,
        "output_dim": 64,
        "dropout": 0.1,
        "kernel_size": 3,
    },
    "tiny": {
        "desc": "超小模型（极致压缩）",
        "hidden_channels": 16,
        "output_dim": 32,
        "dropout": 0.1,
        "kernel_size": 3,
    },
    "small": {
        "desc": "小模型（平衡压缩）",
        "hidden_channels": 24,
        "output_dim": 48,
        "dropout": 0.15,
        "kernel_size": 3,
    },
    "wide": {
        "desc": "宽模型（提升表达力）",
        "hidden_channels": 48,
        "output_dim": 96,
        "dropout": 0.2,
        "kernel_size": 3,
    },
    "deep_kernel": {
        "desc": "大卷积核（更大感受野）",
        "hidden_channels": 32,
        "output_dim": 64,
        "dropout": 0.15,
        "kernel_size": 5,
    },
    "high_dropout": {
        "desc": "高dropout（防过拟合）",
        "hidden_channels": 32,
        "output_dim": 64,
        "dropout": 0.3,
        "kernel_size": 3,
    },
    "compact": {
        "desc": "紧凑版（参数最少）",
        "hidden_channels": 12,
        "output_dim": 24,
        "dropout": 0.1,
        "kernel_size": 3,
    },
}


class LightTCNVariant(nn.Module):
    """可配置的 LightTCN 变体"""

    def __init__(self, input_channels=9, hidden_channels=32, output_dim=64,
                 num_classes=5, dropout=0.1, kernel_size=3):
        super().__init__()

        padding1 = kernel_size // 2
        padding2 = kernel_size // 2

        self.conv1 = nn.Conv1d(input_channels, hidden_channels,
                               kernel_size=kernel_size, dilation=1, padding=padding1)
        self.bn1 = nn.BatchNorm1d(hidden_channels)

        self.conv2 = nn.Conv1d(hidden_channels, output_dim,
                               kernel_size=kernel_size, dilation=2, padding=padding2 * 2)
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


def count_parameters(model):
    """统计可训练参数量"""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)


def measure_inference_speed(model, input_tensor, n_runs=100):
    """测量推理速度"""
    model.eval()
    with torch.no_grad():
        # 预热
        for _ in range(10):
            model(input_tensor)

        # 正式测量
        start = time.time()
        for _ in range(n_runs):
            model(input_tensor)
        elapsed = (time.time() - start) / n_runs * 1000  # ms
    return elapsed


def train_and_evaluate(config_name, config, train_data, val_data, test_data, epochs=30):
    """训练并评估一个配置"""
    print(f"\n{'='*50}")
    print(f"  配置: {config_name} — {config['desc']}")
    print(f"{'='*50}")

    model = LightTCNVariant(
        input_channels=9,
        hidden_channels=config['hidden_channels'],
        output_dim=config['output_dim'],
        num_classes=5,
        dropout=config['dropout'],
        kernel_size=config['kernel_size']
    )

    param_count = count_parameters(model)
    print(f"  参数量: {param_count:,}")

    # 训练
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=5, factor=0.5)
    ce_loss = nn.CrossEntropyLoss()

    best_val_acc = 0
    best_epoch = 0

    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0
        correct_fiscal = 0
        correct_finance = 0
        total = 0

        for batch in train_data:
            x, y_fiscal, y_finance = batch
            optimizer.zero_grad()
            fiscal_logits, finance_logits = model(x)
            loss = ce_loss(fiscal_logits, y_fiscal) + ce_loss(finance_logits, y_finance)
            loss.backward()
            optimizer.step()

            total_loss += loss.item()
            correct_fiscal += (fiscal_logits.argmax(1) == y_fiscal).sum().item()
            correct_finance += (finance_logits.argmax(1) == y_finance).sum().item()
            total += y_fiscal.size(0)

        train_acc_fiscal = correct_fiscal / total
        train_acc_finance = correct_finance / total
        avg_loss = total_loss / len(train_data)

        # 验证
        model.eval()
        val_correct_fiscal = 0
        val_correct_finance = 0
        val_total = 0
        val_loss = 0

        with torch.no_grad():
            for batch in val_data:
                x, y_fiscal, y_finance = batch
                fiscal_logits, finance_logits = model(x)
                val_loss += ce_loss(fiscal_logits, y_fiscal).item() + ce_loss(finance_logits, y_finance).item()
                val_correct_fiscal += (fiscal_logits.argmax(1) == y_fiscal).sum().item()
                val_correct_finance += (finance_logits.argmax(1) == y_finance).sum().item()
                val_total += y_fiscal.size(0)

        val_acc_fiscal = val_correct_fiscal / val_total
        val_acc_finance = val_correct_finance / val_total
        val_acc = (val_acc_fiscal + val_acc_finance) / 2
        scheduler.step(val_loss)

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_epoch = epoch
            best_state = model.state_dict().copy()

        if epoch % 10 == 0 or epoch == 1:
            print(f"  Epoch {epoch:3d} | Loss: {avg_loss:.4f} | "
                  f"Val Acc: Fiscal={val_acc_fiscal:.4f} Fin={val_acc_finance:.4f}")

    # 加载最佳模型测试
    model.load_state_dict(best_state)
    model.eval()

    test_correct_fiscal = 0
    test_correct_finance = 0
    test_total = 0

    with torch.no_grad():
        for batch in test_data:
            x, y_fiscal, y_finance = batch
            fiscal_logits, finance_logits = model(x)
            test_correct_fiscal += (fiscal_logits.argmax(1) == y_fiscal).sum().item()
            test_correct_finance += (finance_logits.argmax(1) == y_finance).sum().item()
            test_total += y_fiscal.size(0)

    test_acc_fiscal = test_correct_fiscal / test_total
    test_acc_finance = test_correct_finance / test_total

    # 推理速度
    dummy_input = torch.randn(1, 3, 9)
    speed_ms = measure_inference_speed(model, dummy_input)

    # 模型大小
    import tempfile
    tmp_path = Path(tempfile.gettempdir()) / 'temp_model.pth'
    torch.save(model.state_dict(), tmp_path)
    model_size_kb = tmp_path.stat().st_size / 1024
    tmp_path.unlink()

    result = {
        "config": config_name,
        "desc": config['desc'],
        "hidden_channels": config['hidden_channels'],
        "output_dim": config['output_dim'],
        "dropout": config['dropout'],
        "kernel_size": config['kernel_size'],
        "param_count": param_count,
        "best_epoch": best_epoch,
        "val_acc_fiscal": round(best_val_acc if best_val_acc > 0 else val_acc_fiscal, 4),
        "val_acc_finance": round(val_acc_finance, 4),
        "test_acc_fiscal": round(test_acc_fiscal, 4),
        "test_acc_finance": round(test_acc_finance, 4),
        "inference_ms": round(speed_ms, 3),
        "model_size_kb": round(model_size_kb, 2),
    }

    print(f"\n  📊 结果:")
    print(f"     参数量: {param_count:,} ({'↓' if param_count < 8293 else '↑'}{abs(param_count - 8293):,})")
    print(f"     测试准确率: 财政={test_acc_fiscal:.4f} 金融={test_acc_finance:.4f}")
    print(f"     推理速度: {speed_ms:.3f} ms")
    print(f"     模型大小: {model_size_kb:.2f} KB")

    return result


def generate_synthetic_data(n_samples=200):
    """生成合成数据用于快速对比（真实数据需要pandas，这里用随机数据演示）"""
    torch.manual_seed(42)

    # 生成3年9指标的时序数据
    X = torch.randn(n_samples, 3, 9) * 10 + 5  # 模拟财政指标
    # 风险标签（基于简单规则）
    risk_score = X[:, -1, :].sum(dim=1) / 9
    y_fiscal = torch.clamp((risk_score / 3).long(), 0, 4)
    y_finance = torch.clamp((risk_score / 3 + 0.5).long(), 0, 4)

    # 划分训练/验证/测试
    n_train = int(n_samples * 0.6)
    n_val = int(n_samples * 0.2)

    train_data = [(X[i:i+8], y_fiscal[i:i+8], y_finance[i:i+8])
                  for i in range(0, n_train, 8)]
    val_data = [(X[i:i+8], y_fiscal[i:i+8], y_finance[i:i+8])
                for i in range(n_train, n_train + n_val, 8)]
    test_data = [(X[i:i+8], y_fiscal[i:i+8], y_finance[i:i+8])
                 for i in range(n_train + n_val, n_samples, 8)]

    return train_data, val_data, test_data


def main():
    print("=" * 60)
    print("  LightTCN 调参对比实验")
    print("=" * 60)

    # 生成合成数据
    print("\n生成合成数据...")
    train_data, val_data, test_data = generate_synthetic_data(300)
    print(f"  训练: {len(train_data)} batches")
    print(f"  验证: {len(val_data)} batches")
    print(f"  测试: {len(test_data)} batches")

    # 跑所有配置
    results = []
    for name, config in CONFIGS.items():
        result = train_and_evaluate(name, config, train_data, val_data, test_data, epochs=30)
        results.append(result)

    # 汇总对比表
    print("\n" + "=" * 80)
    print("  📊 对比汇总")
    print("=" * 80)
    print(f"{'配置':<15} {'参数量':>8} {'测试财政':>8} {'测试金融':>8} {'速度ms':>8} {'大小KB':>8}")
    print("-" * 80)

    baseline_params = 8293
    for r in sorted(results, key=lambda x: x['param_count']):
        delta = r['param_count'] - baseline_params
        delta_str = f"({delta:+,})" if delta != 0 else "(基线)"
        print(f"{r['config']:<15} {r['param_count']:>7,} {r['test_acc_fiscal']:>8.4f} "
              f"{r['test_acc_finance']:>8.4f} {r['inference_ms']:>7.3f} {r['model_size_kb']:>7.2f} {delta_str}")

    # 保存结果
    save_path = Path('results/tune_results.json')
    save_path.parent.mkdir(exist_ok=True)
    with open(save_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"\n结果已保存到: {save_path}")

    # 推荐
    best_compact = min(results, key=lambda x: x['param_count'])
    best_acc = max(results, key=lambda x: (x['test_acc_fiscal'] + x['test_acc_finance']) / 2)
    best_speed = min(results, key=lambda x: x['inference_ms'])

    print(f"\n🏆 推荐:")
    print(f"  最小模型: {best_compact['config']} ({best_compact['param_count']:,} 参数)")
    print(f"  最高准确: {best_acc['config']} (财政{best_acc['test_acc_fiscal']:.4f} 金融{best_acc['test_acc_finance']:.4f})")
    print(f"  最快推理: {best_speed['config']} ({best_speed['inference_ms']:.3f} ms)")


if __name__ == "__main__":
    main()
