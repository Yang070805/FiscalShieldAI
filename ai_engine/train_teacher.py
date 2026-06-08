"""
train_teacher.py
ST-GNN 教师模型训练脚本

使用方式：
    python train_teacher.py --data_dir ./data --epochs 100 --lr 0.001

训练完成后会生成：
    - checkpoints/best_teacher_model.pth
    - checkpoints/data_scaler.joblib
    - checkpoints/training_history.json
    - checkpoints/training_curves.png
"""

import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import os
import json
import argparse
import joblib
from datetime import datetime
from sklearn.metrics import accuracy_score, f1_score, classification_report

from models.stgnn import STGNN
from data_loader import create_data_loaders


def train_teacher(data_dir: str, epochs: int = 100, lr: float = 0.001,
                  hidden_dim: int = 64, gat_heads: int = 4,
                  gru_hidden: int = 32, patience: int = 15,
                  batch_size: int = 8, save_dir: str = './checkpoints'):
    """
    训练 ST-GNN 教师模型

    参数说明：
        data_dir: 数据目录，包含各城市的 xlsx/csv 文件
        epochs: 训练轮数
        lr: 学习率
        hidden_dim: GAT 隐藏层维度
        gat_heads: GAT 注意力头数
        gru_hidden: GRU 隐藏层维度
        patience: 早停耐心值
        batch_size: 批次大小
        save_dir: 模型保存目录
    """
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"使用设备: {device}")

    # 创建保存目录
    os.makedirs(save_dir, exist_ok=True)

    # 创建数据加载器
    print("[1/5] 加载数据...")
    loaders = create_data_loaders(data_dir, batch_size=batch_size)
    train_loader = loaders['train']
    val_loader = loaders['val']
    test_loader = loaders['test']

    # 保存标准化器（从训练数据集中获取）
    train_dataset = train_loader.dataset
    scaler_path = os.path.join(save_dir, 'data_scaler.joblib')
    joblib.dump(train_dataset.scaler, scaler_path)
    print(f"  标准化器已保存: {scaler_path}")

    # 初始化教师模型
    print("[2/5] 初始化 ST-GNN 教师模型...")
    input_dim = train_dataset.time_window * train_dataset.num_base_features * 2  # 3 * 18 = 54
    model = STGNN(
        input_dim=input_dim,
        hidden_dim=hidden_dim,
        gat_heads=gat_heads,
        gru_hidden=gru_hidden,
        num_classes=5,
        dropout=0.2
    ).to(device)

    total_params = sum(p.numel() for p in model.parameters())
    print(f"  模型参数量: {total_params:,}")

    # 优化器和调度器
    optimizer = optim.Adam(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='min', factor=0.5, patience=5
    )
    criterion = nn.CrossEntropyLoss()

    # 训练循环
    print("[3/5] 开始训练...")
    best_val_loss = float('inf')
    patience_counter = 0
    history = {
        'train_loss': [], 'val_loss': [],
        'train_acc_fiscal': [], 'val_acc_fiscal': [],
        'train_acc_finance': [], 'val_acc_finance': []
    }
    best_model_path = None

    for epoch in range(1, epochs + 1):
        # ---- 训练 ----
        model.train()
        train_loss = 0
        preds_fiscal, labels_fiscal = [], []
        preds_finance, labels_finance = [], []

        for batch in train_loader:
            batch = batch.to(device)
            optimizer.zero_grad()

            fiscal_logits, finance_logits = model(batch)

            # 财政风险标签
            loss_fiscal = criterion(fiscal_logits, batch.y_fiscal)
            # 金融风险标签
            loss_finance = criterion(finance_logits, batch.y_finance)
            # 多任务损失
            loss = loss_fiscal + loss_finance

            loss.backward()
            optimizer.step()

            train_loss += loss.item()
            _, pf = torch.max(fiscal_logits, 1)
            _, pfn = torch.max(finance_logits, 1)
            preds_fiscal.extend(pf.cpu().numpy())
            labels_fiscal.extend(batch.y_fiscal.cpu().numpy())
            preds_finance.extend(pfn.cpu().numpy())
            labels_finance.extend(batch.y_finance.cpu().numpy())

        train_loss /= len(train_loader)
        train_acc_f = accuracy_score(labels_fiscal, preds_fiscal)
        train_acc_fn = accuracy_score(labels_finance, preds_finance)

        # ---- 验证 ----
        model.eval()
        val_loss = 0
        v_preds_fiscal, v_labels_fiscal = [], []
        v_preds_finance, v_labels_finance = [], []

        with torch.no_grad():
            for batch in val_loader:
                batch = batch.to(device)
                fiscal_logits, finance_logits = model(batch)

                loss_fiscal = criterion(fiscal_logits, batch.y_fiscal)
                loss_finance = criterion(finance_logits, batch.y_finance)
                val_loss += (loss_fiscal + loss_finance).item()

                _, pf = torch.max(fiscal_logits, 1)
                _, pfn = torch.max(finance_logits, 1)
                v_preds_fiscal.extend(pf.cpu().numpy())
                v_labels_fiscal.extend(batch.y_fiscal.cpu().numpy())
                v_preds_finance.extend(pfn.cpu().numpy())
                v_labels_finance.extend(batch.y_finance.cpu().numpy())

        val_loss /= len(val_loader)
        val_acc_f = accuracy_score(v_labels_fiscal, v_preds_fiscal)
        val_acc_fn = accuracy_score(v_labels_finance, v_preds_finance)

        scheduler.step(val_loss)

        # 记录历史
        history['train_loss'].append(train_loss)
        history['val_loss'].append(val_loss)
        history['train_acc_fiscal'].append(train_acc_f)
        history['val_acc_fiscal'].append(val_acc_f)
        history['train_acc_finance'].append(train_acc_fn)
        history['val_acc_finance'].append(val_acc_fn)

        print(f"Epoch {epoch}/{epochs} | "
              f"Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | "
              f"Train Acc(F): {train_acc_f:.3f} | Val Acc(F): {val_acc_f:.3f}")

        # 保存最佳模型
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
            best_model_path = os.path.join(save_dir, 'best_teacher_model.pth')
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_loss': val_loss,
                'input_dim': input_dim,
                'hidden_dim': hidden_dim,
                'gat_heads': gat_heads,
                'gru_hidden': gru_hidden
            }, best_model_path)
            print(f"  ✅ 保存最佳模型 (val_loss={val_loss:.4f})")
        else:
            patience_counter += 1
            if patience_counter >= patience:
                print(f"\n⏹️  早停触发! 在 epoch {epoch} 停止")
                break

    # ---- 保存训练历史 ----
    print("\n[4/5] 保存训练历史...")
    history_path = os.path.join(save_dir, 'training_history.json')
    with open(history_path, 'w', encoding='utf-8') as f:
        json.dump({k: [float(v) for v in vals] for k, vals in history.items()}, f)

    # ---- 测试集评估 ----
    print("[5/5] 测试集评估...")
    if best_model_path:
        checkpoint = torch.load(best_model_path, map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])

    model.eval()
    t_preds_fiscal, t_labels_fiscal = [], []
    t_preds_finance, t_labels_finance = [],[]

    with torch.no_grad():
        for batch in test_loader:
            batch = batch.to(device)
            fiscal_logits, finance_logits = model(batch)
            _, pf = torch.max(fiscal_logits, 1)
            _, pfn = torch.max(finance_logits, 1)
            t_preds_fiscal.extend(pf.cpu().numpy())
            t_labels_fiscal.extend(batch.y_fiscal.cpu().numpy())
            t_preds_finance.extend(pfn.cpu().numpy())
            t_labels_finance.extend(batch.y_finance.cpu().numpy())

    risk_labels = ['低风险', '中等偏低', '中等', '中等偏高', '高风险']
    print("\n=== 财政风险分类报告 ===")
    print(classification_report(t_labels_fiscal, t_preds_fiscal, target_names=risk_labels, labels=[0, 1, 2, 3, 4], zero_division=0))
    print("\n=== 金融风险分类报告 ===")
    print(classification_report(t_labels_finance, t_preds_finance, target_names=risk_labels, labels=[0, 1, 2, 3, 4], zero_division=0))
    print(f"\n✅ 训练完成！最佳模型: {best_model_path}")
    return best_model_path


def main():
    parser = argparse.ArgumentParser(description='ST-GNN 教师模型训练')
    parser.add_argument('--data_dir', type=str, default='./data', help='数据目录')
    parser.add_argument('--epochs', type=int, default=100, help='训练轮数')
    parser.add_argument('--lr', type=float, default=0.001, help='学习率')
    parser.add_argument('--hidden_dim', type=int, default=64, help='隐藏层维度')
    parser.add_argument('--gat_heads', type=int, default=4, help='GAT注意力头数')
    parser.add_argument('--gru_hidden', type=int, default=32, help='GRU隐藏层维度')
    parser.add_argument('--patience', type=int, default=15, help='早停耐心值')
    parser.add_argument('--batch_size', type=int, default=8, help='批次大小')
    parser.add_argument('--save_dir', type=str, default='./checkpoints', help='保存目录')

    args = parser.parse_args()

    train_teacher(
        data_dir=args.data_dir,
        epochs=args.epochs,
        lr=args.lr,
        hidden_dim=args.hidden_dim,
        gat_heads=args.gat_heads,
        gru_hidden=args.gru_hidden,
        patience=args.patience,
        batch_size=args.batch_size,
        save_dir=args.save_dir
    )


if __name__ == '__main__':
    main()
