"""
训练 Pipeline 服务 — 自动训练 LightTCNCompact 模型

功能：
- 读取数据库中 role='gov' 的上传数据
- 调用 ai_engine/train_compact.py 的 LightTCNCompact 模型
- 支持增量训练（在已有模型基础上继续训练）
- 训练完成后更新 checkpoints/best_student_model.pth
- 记录训练日志（loss, accuracy, epoch数）
"""

import asyncio
import json
import sys
import threading
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any

import torch
import torch.nn as nn
import numpy as np
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import async_session
from models.prediction import Prediction
from models.training import TrainingRecord

# AI Engine 路径
AI_ENGINE_DIR = Path(__file__).resolve().parent.parent.parent / "ai_engine"
if str(AI_ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(AI_ENGINE_DIR))


# ==================== 全局训练状态 ====================

_training_state = {
    "status": "idle",  # idle / training / completed / failed
    "current_epoch": 0,
    "total_epochs": 0,
    "loss": None,
    "accuracy": None,
    "started_at": None,
    "message": "",
}


def get_training_status() -> dict:
    """获取当前训练状态"""
    return dict(_training_state)


def _update_state(**kwargs):
    """更新训练状态"""
    _training_state.update(kwargs)


# ==================== 训练执行 ====================

def _run_training_sync(epochs: int = 50, incremental: bool = True):
    """
    同步训练函数（在后台线程执行）

    Args:
        epochs: 训练轮数
        incremental: 是否增量训练（加载已有模型继续训练）
    """
    try:
        _update_state(
            status="training",
            current_epoch=0,
            total_epochs=epochs,
            started_at=datetime.now().isoformat(),
            message="正在准备训练数据...",
        )

        # 1. 加载训练数据
        from train_compact import LightTCNCompact, load_city_data

        data_dir = AI_ENGINE_DIR / "data"
        samples, base_features = load_city_data(str(data_dir))

        if len(samples) == 0:
            _update_state(status="failed", message="没有找到有效的训练数据")
            return

        _update_state(message=f"加载了 {len(samples)} 个样本，开始训练...")

        # 2. 数据准备
        np.random.seed(42)
        np.random.shuffle(samples)

        n = len(samples)
        n_train = int(n * 0.8)
        train_samples = samples[:n_train]
        val_samples = samples[n_train:]

        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

        # 3. 初始化/加载模型
        model = LightTCNCompact(
            input_channels=9,
            hidden_channels=12,
            output_dim=24,
            num_classes=5,
            dropout=0.1,
        ).to(device)

        checkpoint_path = AI_ENGINE_DIR / "checkpoints" / "best_student_model.pth"
        if incremental and checkpoint_path.exists():
            try:
                checkpoint = torch.load(str(checkpoint_path), map_location=device, weights_only=False)
                if 'model_state_dict' in checkpoint:
                    model.load_state_dict(checkpoint['model_state_dict'], strict=False)
                    _update_state(message="已加载现有模型，开始增量训练...")
                elif 'state_dict' in checkpoint:
                    model.load_state_dict(checkpoint['state_dict'], strict=False)
                    _update_state(message="已加载现有模型，开始增量训练...")
            except Exception as e:
                _update_state(message=f"加载旧模型失败({e})，从头训练...")

        # 4. 训练
        optimizer = torch.optim.Adam(model.parameters(), lr=0.001, weight_decay=1e-4)
        scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=8, factor=0.5)
        ce_loss = nn.CrossEntropyLoss()

        best_val_acc = 0
        patience_counter = 0
        patience = 15
        best_state = None
        best_epoch = 0
        history = {'train_loss': [], 'val_loss': [], 'train_acc': [], 'val_acc': []}

        for epoch in range(1, epochs + 1):
            # 训练
            model.train()
            total_loss = 0
            correct = 0
            total = 0

            for X, y_fiscal, y_finance, _, _ in train_samples:
                x_tensor = torch.FloatTensor(X).unsqueeze(0).to(device)
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
            avg_loss = total_loss / len(train_samples) if train_samples else 0

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

            val_acc = val_correct / val_total if val_total > 0 else 0
            scheduler.step(val_loss)

            history['train_loss'].append(avg_loss)
            history['val_loss'].append(val_loss / len(val_samples) if val_samples else 0)
            history['train_acc'].append(train_acc)
            history['val_acc'].append(val_acc)

            _update_state(
                current_epoch=epoch,
                loss=round(avg_loss, 4),
                accuracy=round(val_acc, 4),
            )

            if val_acc > best_val_acc:
                best_val_acc = val_acc
                patience_counter = 0
                best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
                best_epoch = epoch
            else:
                patience_counter += 1

            if patience_counter >= patience:
                _update_state(message=f"早停触发！最佳 Epoch: {best_epoch}")
                break

        # 5. 保存模型
        if best_state:
            model.load_state_dict(best_state)

        save_dir = AI_ENGINE_DIR / "checkpoints"
        save_dir.mkdir(exist_ok=True)

        model_data = {
            'model_state_dict': best_state or model.state_dict(),
            'config': {
                'input_channels': 9,
                'hidden_channels': 12,
                'output_dim': 24,
                'num_classes': 5,
                'dropout': 0.1,
            },
            'best_epoch': best_epoch,
            'val_acc': best_val_acc,
            'train_date': datetime.now().isoformat(),
        }

        # 保存为 best_student_model.pth（覆盖更新）
        torch.save(model_data, str(checkpoint_path))

        # 保存历史记录
        history_path = save_dir / 'compact_training_history.json'
        with open(history_path, 'w', encoding='utf-8') as f:
            json.dump(history, f, indent=2)

        _update_state(
            status="completed",
            message=f"训练完成！最佳Epoch: {best_epoch}, 验证准确率: {best_val_acc:.4f}",
        )

        # 6. 记录到数据库
        asyncio.run(_save_training_record(
            status="completed",
            epochs=best_epoch,
            best_loss=min(history['val_loss']) if history['val_loss'] else 0,
            best_accuracy=best_val_acc,
            data_count=len(samples),
            log=json.dumps(history, ensure_ascii=False),
            model_path=str(checkpoint_path),
        ))

    except Exception as e:
        _update_state(status="failed", message=f"训练失败: {str(e)}")
        asyncio.run(_save_training_record(
            status="failed",
            epochs=0,
            data_count=0,
            log=json.dumps({"error": str(e)}, ensure_ascii=False),
        ))


async def _save_training_record(
    status: str,
    epochs: int = 0,
    best_loss: float = 0,
    best_accuracy: float = 0,
    data_count: int = 0,
    log: str = "",
    model_path: str = "",
):
    """保存训练记录到数据库"""
    async with async_session() as db:
        record = TrainingRecord(
            status=status,
            epochs=epochs,
            best_loss=best_loss,
            best_accuracy=best_accuracy,
            data_count=data_count,
            log=log,
            model_path=model_path,
        )
        db.add(record)
        await db.commit()


def start_training(epochs: int = 50, incremental: bool = True) -> dict:
    """
    启动训练（后台线程）

    Args:
        epochs: 训练轮数
        incremental: 是否增量训练
    Returns:
        训练状态
    """
    current = get_training_status()
    if current["status"] == "training":
        return {"status": "training", "message": "训练正在进行中，请稍候"}

    # 后台线程执行训练
    thread = threading.Thread(
        target=_run_training_sync,
        args=(epochs, incremental),
        daemon=True,
    )
    thread.start()

    return {"status": "training", "message": "训练已启动", "total_epochs": epochs}


async def get_training_history(db: AsyncSession, limit: int = 20) -> list:
    """获取训练历史"""
    result = await db.execute(
        select(TrainingRecord)
        .order_by(TrainingRecord.created_at.desc())
        .limit(limit)
    )
    records = result.scalars().all()
    return [
        {
            "id": r.id,
            "status": r.status,
            "epochs": r.epochs,
            "best_loss": r.best_loss,
            "best_accuracy": r.best_accuracy,
            "data_count": r.data_count,
            "created_at": r.created_at.isoformat() if r.created_at else "",
        }
        for r in records
    ]
