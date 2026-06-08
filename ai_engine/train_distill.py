"""
知识蒸馏训练模块
将STGNN教师模型的知识迁移到LightTCN学生模型
包含软目标蒸馏、注意力转移和硬标签训练
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import DataLoader
from tqdm import tqdm
import numpy as np
from sklearn.metrics import accuracy_score, f1_score, classification_report
import matplotlib.pyplot as plt
import os
import json
from datetime import datetime


class DistillationTrainer:
    """
    知识蒸馏训练器

    核心功能：
    1. 使用教师模型的软目标指导学生模型训练
    2. 结合注意力转移损失
    3. 支持多任务学习（财政和金融风险）
    4. 提供完整的训练、验证、评估流程
    """

    def __init__(self,
                 teacher_model: nn.Module,
                 student_model: nn.Module,
                 device: torch.device,
                 temperature: float = 3.0,
                 alpha: float = 0.7,
                 beta: float = 0.3):
        """
        初始化蒸馏训练器

        参数说明：
        ----------
        teacher_model : nn.Module
            预训练好的教师模型（STGNN）
        student_model : nn.Module
            待训练的学生模型（LightTCN）
        device : torch.device
            训练设备（cpu或cuda）
        temperature : float, 默认=3.0
            蒸馏温度，用于软化概率分布
        alpha : float, 默认=0.7
            软目标损失权重
        beta : float, 默认=0.3
            硬目标损失权重
        """
        self.teacher = teacher_model
        self.student = student_model
        self.device = device
        self.temperature = temperature
        self.alpha = alpha
        self.beta = beta

        # 冻结教师模型参数（不参与训练）
        for param in self.teacher.parameters():
            param.requires_grad = False

        # 损失函数定义
        self.kl_loss = nn.KLDivLoss(reduction='batchmean')  # KL散度，用于软目标
        self.ce_loss = nn.CrossEntropyLoss()  # 交叉熵，用于硬目标
        self.mse_loss = nn.MSELoss()  # 均方误差，用于注意力转移

        # 训练历史记录
        self.history = {
            'train_loss': [], 'val_loss': [],
            'train_acc_fiscal': [], 'val_acc_fiscal': [],
            'train_acc_finance': [], 'val_acc_finance': []
        }

    def _slice_first_city(self, tensor):
        """从5个城市的tensor中提取第1个城市的数据"""
        if tensor.size(0) >= 5:
            return tensor[::5]
        return tensor[:1]

    def distill_loss(self,
                     student_fiscal_logits,
                     student_finance_logits,
                     teacher_fiscal_logits,
                     teacher_finance_logits,
                     labels_fiscal,
                     labels_finance,
                     student_features=None,
                     teacher_features=None):
        """
        计算知识蒸馏损失

        损失组成：
        1. 软目标损失: KL散度，让学生模仿教师的概率分布
        2. 硬目标损失: 交叉熵，让学生学习真实标签
        3. 注意力转移损失: MSE，让学生特征与教师特征对齐

        返回：
        ------
        total_loss : torch.Tensor
            总损失
        loss_dict : Dict
            各损失分量的字典
        """
        # ==================== 软目标损失 ====================
        # 财政风险软目标损失
        soft_target_loss_fiscal = self.kl_loss(
            F.log_softmax(student_fiscal_logits / self.temperature, dim=1),
            F.softmax(teacher_fiscal_logits / self.temperature, dim=1)
        ) * (self.temperature ** 2)

        # 金融风险软目标损失
        soft_target_loss_finance = self.kl_loss(
            F.log_softmax(student_finance_logits / self.temperature, dim=1),
            F.softmax(teacher_finance_logits / self.temperature, dim=1)
        ) * (self.temperature ** 2)

        # ==================== 硬目标损失 ====================
        hard_target_loss_fiscal = self.ce_loss(student_fiscal_logits, labels_fiscal)
        hard_target_loss_finance = self.ce_loss(student_finance_logits, labels_finance)

        # ==================== 总损失 ====================
        total_loss = (self.alpha * (soft_target_loss_fiscal + soft_target_loss_finance) +
                     self.beta * (hard_target_loss_fiscal + hard_target_loss_finance))

        # ==================== 注意力转移损失 ====================
        attention_loss = 0.0
        if student_features is not None and teacher_features is not None:
            adapter = nn.Linear(teacher_features.size(1), student_features.size(1)).to(self.device)
            teacher_features_adapted = adapter(teacher_features)
            attention_loss = self.mse_loss(student_features, teacher_features_adapted)
            total_loss += 0.2 * attention_loss

        loss_dict = {
            'total': total_loss.item(),
            'soft_fiscal': soft_target_loss_fiscal.item(),
            'soft_finance': soft_target_loss_finance.item(),
            'hard_fiscal': hard_target_loss_fiscal.item(),
            'hard_finance': hard_target_loss_finance.item(),
            'attention': attention_loss if isinstance(attention_loss, float) else attention_loss.item()
        }

        return total_loss, loss_dict

    def train_epoch(self, train_loader, optimizer, epoch, print_freq=10):
        """
        训练一个epoch

        训练步骤：
        1. 前向传播：教师和学生模型分别推理
        2. 计算损失：知识蒸馏损失
        3. 反向传播：更新学生模型参数
        4. 记录指标：损失、准确率、F1分数

        返回：
        ------
        epoch_loss : float
            平均训练损失
        metrics : Dict
            训练指标字典
        """
        self.student.train()
        total_loss = 0
        all_preds_fiscal = []
        all_labels_fiscal = []
        all_preds_finance = []
        all_labels_finance = []

        pbar = tqdm(train_loader, desc=f'Epoch {epoch}')

        for batch_idx, data in enumerate(pbar):
            data = data.to(self.device)

            # 获取学生模型输入（单城市时序数据）
            # data.x形状: [batch_size*5, 54] -> 重塑为[batch_size, 5, 3, 18]
            # 取第一个城市（索引0），基础特征（前9个）
            student_input = data.x.view(-1, 5, 3, 18)[:, 0, :, :9]

            # 教师模型推理（不计算梯度）
            with torch.no_grad():
                teacher_fiscal_logits, teacher_finance_logits = self.teacher(data)
                # 只取第1个城市的输出，匹配学生模型
                teacher_fiscal_logits = self._slice_first_city(teacher_fiscal_logits)
                teacher_finance_logits = self._slice_first_city(teacher_finance_logits)

            # 学生模型推理
            student_fiscal_logits, student_finance_logits = self.student(student_input)

            # 只取第1个城市的标签
            labels_fiscal = self._slice_first_city(data.y_fiscal)
            labels_finance = self._slice_first_city(data.y_finance)

            # 计算知识蒸馏损失
            loss, loss_dict = self.distill_loss(
                student_fiscal_logits, student_finance_logits,
                teacher_fiscal_logits, teacher_finance_logits,
                labels_fiscal, labels_finance
            )

            # 反向传播
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            total_loss += loss.item()

            # 计算预测类别
            _, preds_fiscal = torch.max(student_fiscal_logits, 1)
            _, preds_finance = torch.max(student_finance_logits, 1)

            # 收集预测和标签用于评估
            all_preds_fiscal.extend(preds_fiscal.cpu().numpy())
            all_labels_fiscal.extend(labels_fiscal.cpu().numpy())
            all_preds_finance.extend(preds_finance.cpu().numpy())
            all_labels_finance.extend(labels_finance.cpu().numpy())

            if batch_idx % print_freq == 0:
                pbar.set_postfix({
                    'loss': loss.item(),
                    'soft_f': loss_dict['soft_fiscal'],
                    'hard_f': loss_dict['hard_fiscal']
                })

        # 计算评估指标
        acc_fiscal = accuracy_score(all_labels_fiscal, all_preds_fiscal)
        acc_finance = accuracy_score(all_labels_finance, all_preds_finance)
        f1_fiscal = f1_score(all_labels_fiscal, all_preds_fiscal, average='weighted')
        f1_finance = f1_score(all_labels_finance, all_preds_finance, average='weighted')

        epoch_loss = total_loss / len(train_loader)

        metrics = {
            'loss': epoch_loss,
            'acc_fiscal': acc_fiscal,
            'acc_finance': acc_finance,
            'f1_fiscal': f1_fiscal,
            'f1_finance': f1_finance
        }

        return epoch_loss, metrics

    def validate(self, val_loader):
        """
        验证学生模型

        验证步骤：
        1. 设置模型为评估模式
        2. 不计算梯度，进行前向传播
        3. 计算验证损失和指标
        4. 生成分类报告

        返回：
        ------
        val_loss : float
            验证损失
        metrics : Dict
            验证指标字典，包含详细分类报告
        """
        self.student.eval()
        total_loss = 0
        all_preds_fiscal = []
        all_labels_fiscal = []
        all_preds_finance = []
        all_labels_finance = []

        with torch.no_grad():
            for data in tqdm(val_loader, desc='Validating'):
                data = data.to(self.device)

                # 获取学生模型输入
                student_input = data.x.view(-1, 5, 3, 18)[:, 0, :, :9]

                # 教师模型推理
                teacher_fiscal_logits, teacher_finance_logits = self.teacher(data)
                # 只取第1个城市的输出，匹配学生模型
                teacher_fiscal_logits = self._slice_first_city(teacher_fiscal_logits)
                teacher_finance_logits = self._slice_first_city(teacher_finance_logits)

                # 学生模型推理
                student_fiscal_logits, student_finance_logits = self.student(student_input)

                # 只取第1个城市的标签
                labels_fiscal = self._slice_first_city(data.y_fiscal)
                labels_finance = self._slice_first_city(data.y_finance)

                # 计算损失
                loss, _ = self.distill_loss(
                    student_fiscal_logits, student_finance_logits,
                    teacher_fiscal_logits, teacher_finance_logits,
                    labels_fiscal, labels_finance
                )

                total_loss += loss.item()

                # 计算预测
                _, preds_fiscal = torch.max(student_fiscal_logits, 1)
                _, preds_finance = torch.max(student_finance_logits, 1)

                all_preds_fiscal.extend(preds_fiscal.cpu().numpy())
                all_labels_fiscal.extend(labels_fiscal.cpu().numpy())
                all_preds_finance.extend(preds_finance.cpu().numpy())
                all_labels_finance.extend(labels_finance.cpu().numpy())

        # 计算评估指标
        acc_fiscal = accuracy_score(all_labels_fiscal, all_preds_fiscal)
        acc_finance = accuracy_score(all_labels_finance, all_preds_finance)
        f1_fiscal = f1_score(all_labels_fiscal, all_preds_fiscal, average='weighted')
        f1_finance = f1_score(all_labels_finance, all_preds_finance, average='weighted')

        val_loss = total_loss / len(val_loader)

        # 生成详细的分类报告
        report_fiscal = classification_report(
            all_labels_fiscal, all_preds_fiscal,
            labels=[0, 1, 2, 3, 4],
            target_names=['低风险', '中等偏低', '中等', '中等偏高', '高风险'],
            zero_division=0
        )
        report_finance = classification_report(
            all_labels_finance, all_preds_finance,
            labels=[0, 1, 2, 3, 4],
            target_names=['低风险', '中等偏低', '中等', '中等偏高', '高风险'],
            zero_division=0
        )

        metrics = {
            'loss': val_loss,
            'acc_fiscal': acc_fiscal,
            'acc_finance': acc_finance,
            'f1_fiscal': f1_fiscal,
            'f1_finance': f1_finance,
            'report_fiscal': report_fiscal,
            'report_finance': report_finance
        }

        return val_loss, metrics

    def train(self, train_loader, val_loader,
              num_epochs=50, lr=0.001, weight_decay=1e-4,
              patience=10, save_dir='./checkpoints'):
        """
        完整的训练循环

        训练流程：
        1. 初始化优化器和学习率调度器
        2. 循环训练每个epoch
        3. 每个epoch后验证模型
        4. 使用早停防止过拟合
        5. 保存最佳模型和训练历史

        返回：
        ------
        history : Dict
            训练历史记录
        best_model_path : str
            最佳模型保存路径
        """
        os.makedirs(save_dir, exist_ok=True)

        # 优化器：Adam优化器
        optimizer = optim.Adam(
            self.student.parameters(),
            lr=lr,
            weight_decay=weight_decay
        )

        # 学习率调度器：基于验证损失调整学习率
        scheduler = optim.lr_scheduler.ReduceLROnPlateau(
            optimizer, mode='min', factor=0.5, patience=5
        )

        # 早停设置
        best_val_loss = float('inf')
        patience_counter = 0
        best_model_path = None

        print("开始知识蒸馏训练...")

        for epoch in range(1, num_epochs + 1):
            print(f"\n{'='*50}")
            print(f"Epoch {epoch}/{num_epochs}")
            print('='*50)

            # 训练一个epoch
            train_loss, train_metrics = self.train_epoch(train_loader, optimizer, epoch)

            # 验证
            val_loss, val_metrics = self.validate(val_loader)

            # 更新学习率
            scheduler.step(val_loss)

            # 记录训练历史
            self.history['train_loss'].append(train_loss)
            self.history['val_loss'].append(val_loss)
            self.history['train_acc_fiscal'].append(train_metrics['acc_fiscal'])
            self.history['val_acc_fiscal'].append(val_metrics['acc_fiscal'])
            self.history['train_acc_finance'].append(train_metrics['acc_finance'])
            self.history['val_acc_finance'].append(val_metrics['acc_finance'])

            # 打印训练结果
            print(f"\n训练结果:")
            print(f"  训练损失: {train_loss:.4f}, 验证损失: {val_loss:.4f}")
            print(f"  财政风险准确率: 训练 {train_metrics['acc_fiscal']:.4f}, 验证 {val_metrics['acc_fiscal']:.4f}")
            print(f"  金融风险准确率: 训练 {train_metrics['acc_finance']:.4f}, 验证 {val_metrics['acc_finance']:.4f}")

            # 保存最佳模型
            if val_loss < best_val_loss:
                best_val_loss = val_loss
                patience_counter = 0

                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                best_model_path = os.path.join(save_dir, f'best_model_epoch{epoch}_{timestamp}.pth')

                torch.save({
                    'epoch': epoch,
                    'student_state_dict': self.student.state_dict(),
                    'teacher_state_dict': self.teacher.state_dict(),
                    'optimizer_state_dict': optimizer.state_dict(),
                    'val_loss': val_loss,
                    'val_metrics': val_metrics,
                    'history': self.history
                }, best_model_path)

                print(f"  保存最佳模型到: {best_model_path}")
            else:
                patience_counter += 1
                print(f"  早停计数器: {patience_counter}/{patience}")

                if patience_counter >= patience:
                    print(f"\n早停触发! 在epoch {epoch}停止训练")
                    break

        # 保存最终模型
        final_model_path = os.path.join(save_dir, 'best_student_model.pth')
        torch.save(self.student.state_dict(), final_model_path)
        print(f"保存最终模型到: {final_model_path}")

        # 保存训练历史为JSON文件
        history_path = os.path.join(save_dir, 'training_history.json')
        with open(history_path, 'w', encoding='utf-8') as f:
            json.dump({k: [float(v) for v in vals] for k, vals in self.history.items()}, f)

        # 加载最佳模型
        if best_model_path:
            checkpoint = torch.load(best_model_path, map_location=self.device)
            self.student.load_state_dict(checkpoint['student_state_dict'])
            print(f"加载最佳模型 (epoch {checkpoint['epoch']})")

        return self.history, best_model_path

    def plot_training_history(self, save_dir='./results'):
        """
        绘制训练历史图表

        绘制内容：
        1. 训练和验证损失曲线
        2. 财政风险准确率曲线
        3. 金融风险准确率曲线
        4. 损失对比曲线
        """
        os.makedirs(save_dir, exist_ok=True)

        fig, axes = plt.subplots(2, 2, figsize=(12, 10))

        # 1. 损失曲线
        axes[0, 0].plot(self.history['train_loss'], label='训练损失', linewidth=2)
        axes[0, 0].plot(self.history['val_loss'], label='验证损失', linewidth=2)
        axes[0, 0].set_xlabel('Epoch', fontsize=12)
        axes[0, 0].set_ylabel('损失', fontsize=12)
        axes[0, 0].set_title('训练和验证损失', fontsize=14, fontweight='bold')
        axes[0, 0].legend(fontsize=10)
        axes[0, 0].grid(True, alpha=0.3)

        # 2. 财政风险准确率
        axes[0, 1].plot(self.history['train_acc_fiscal'], label='训练准确率', linewidth=2)
        axes[0, 1].plot(self.history['val_acc_fiscal'], label='验证准确率', linewidth=2)
        axes[0, 1].set_xlabel('Epoch', fontsize=12)
        axes[0, 1].set_ylabel('准确率', fontsize=12)
        axes[0, 1].set_title('财政风险分类准确率', fontsize=14, fontweight='bold')
        axes[0, 1].legend(fontsize=10)
        axes[0, 1].grid(True, alpha=0.3)

        # 3. 金融风险准确率
        axes[1, 0].plot(self.history['train_acc_finance'], label='训练准确率', linewidth=2)
        axes[1, 0].plot(self.history['val_acc_finance'], label='验证准确率', linewidth=2)
        axes[1, 0].set_xlabel('Epoch', fontsize=12)
        axes[1, 0].set_ylabel('准确率', fontsize=12)
        axes[1, 0].set_title('金融风险分类准确率', fontsize=14, fontweight='bold')
        axes[1, 0].legend(fontsize=10)
        axes[1, 0].grid(True, alpha=0.3)

        # 4. 损失对比
        epochs_range = range(1, len(self.history['train_loss']) + 1)
        axes[1, 1].plot(epochs_range, self.history['train_loss'], 'b-', label='训练损失', linewidth=2)
        axes[1, 1].plot(epochs_range, self.history['val_loss'], 'r-', label='验证损失', linewidth=2)
        axes[1, 1].set_xlabel('Epoch', fontsize=12)
        axes[1, 1].set_ylabel('损失', fontsize=12)
        axes[1, 1].set_title('损失曲线对比', fontsize=14, fontweight='bold')
        axes[1, 1].legend(fontsize=10)
        axes[1, 1].grid(True, alpha=0.3)

        plt.tight_layout()

        save_path = os.path.join(save_dir, 'training_history.png')
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"训练历史图表已保存到: {save_path}")

        plt.show()


def main():
    """
    知识蒸馏训练入口

    使用方式：
        python train_distill.py --teacher_checkpoint ./checkpoints/best_teacher_model.pth
                                --data_dir ./data
                                --epochs 50
                                --temperature 3.0
                                --alpha 0.7
    """
    import argparse

    parser = argparse.ArgumentParser(description='知识蒸馏训练: STGNN → LightTCN')
    parser.add_argument('--teacher_checkpoint', type=str, required=True,
                        help='教师模型检查点路径 (e.g. ./checkpoints/best_teacher_model.pth)')
    parser.add_argument('--data_dir', type=str, default='./data',
                        help='数据目录，包含各城市的 xlsx/csv 文件')
    parser.add_argument('--epochs', type=int, default=50, help='训练轮数')
    parser.add_argument('--batch_size', type=int, default=8, help='批次大小')
    parser.add_argument('--lr', type=float, default=0.001, help='学习率')
    parser.add_argument('--temperature', type=float, default=3.0, help='蒸馏温度')
    parser.add_argument('--alpha', type=float, default=0.7, help='软目标损失权重')
    parser.add_argument('--beta', type=float, default=0.3, help='硬目标损失权重')
    parser.add_argument('--patience', type=int, default=10, help='早停耐心值')
    parser.add_argument('--weight_decay', type=float, default=1e-4, help='权重衰减')
    parser.add_argument('--save_dir', type=str, default='./checkpoints', help='模型保存目录')
    parser.add_argument('--results_dir', type=str, default='./results', help='结果保存目录')
    parser.add_argument('--hidden_dim', type=int, default=64, help='教师模型隐藏层维度')
    parser.add_argument('--gat_heads', type=int, default=4, help='GAT注意力头数')
    parser.add_argument('--gru_hidden', type=int, default=32, help='GRU隐藏层维度')
    parser.add_argument('--student_hidden', type=int, default=32, help='学生模型隐藏层维度')
    parser.add_argument('--student_output_dim', type=int, default=64, help='学生模型输出维度')
    args = parser.parse_args()

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"使用设备: {device}")
    os.makedirs(args.save_dir, exist_ok=True)

    # 1. 加载数据
    print("[1/5] 加载数据...")
    from data_loader import create_data_loaders
    loaders = create_data_loaders(args.data_dir, batch_size=args.batch_size)
    train_loader = loaders['train']
    val_loader = loaders['val']
    test_loader = loaders['test']
    print(f"  训练集: {len(train_loader.dataset)} 样本")
    print(f"  验证集: {len(val_loader.dataset)} 样本")
    print(f"  测试集: {len(test_loader.dataset)} 样本")

    # 2. 初始化教师模型并加载权重
    print("[2/5] 初始化教师模型 (STGNN)...")
    train_dataset = train_loader.dataset
    input_dim = train_dataset.time_window * train_dataset.num_base_features * 2  # 3 * 18 = 54
    from models.stgnn import STGNN
    teacher = STGNN(
        input_dim=input_dim,
        hidden_dim=args.hidden_dim,
        gat_heads=args.gat_heads,
        gru_hidden=args.gru_hidden,
        num_classes=5,
        dropout=0.2
    ).to(device)

    # 加载教师模型检查点
    print(f"  加载教师权重: {args.teacher_checkpoint}")
    checkpoint = torch.load(args.teacher_checkpoint, map_location=device)
    if isinstance(checkpoint, dict) and 'model_state_dict' in checkpoint:
        teacher.load_state_dict(checkpoint['model_state_dict'])
    elif isinstance(checkpoint, dict) and 'state_dict' in checkpoint:
        teacher.load_state_dict(checkpoint['state_dict'])
    else:
        teacher.load_state_dict(checkpoint)
    teacher.eval()
    print(f"  教师模型加载完成")

    # 3. 初始化学生模型
    print("[3/5] 初始化学生模型 (LightTCN)...")
    from models.stgnn import LightTCN
    student = LightTCN(
        input_channels=9,
        hidden_channels=args.student_hidden,
        output_dim=args.student_output_dim,
        num_classes=5,
        dropout=0.1
    ).to(device)
    total_params = sum(p.numel() for p in student.parameters())
    print(f"  学生模型参数量: {total_params:,}")

    # 4. 创建蒸馏训练器
    print("[4/5] 创建蒸馏训练器...")
    trainer = DistillationTrainer(
        teacher_model=teacher,
        student_model=student,
        device=device,
        temperature=args.temperature,
        alpha=args.alpha,
        beta=args.beta
    )

    # 5. 开始训练
    print("[5/5] 开始知识蒸馏训练...")
    history, best_model_path = trainer.train(
        train_loader=train_loader,
        val_loader=val_loader,
        num_epochs=args.epochs,
        lr=args.lr,
        weight_decay=args.weight_decay,
        patience=args.patience,
        save_dir=args.save_dir
    )

    # 在测试集上评估
    print("\n" + "="*50)
    print("测试集评估:")
    print("="*50)
    test_loss, test_metrics = trainer.validate(test_loader)
    print(f"  测试损失: {test_loss:.4f}")
    print(f"  财政风险准确率: {test_metrics['acc_fiscal']:.4f}")
    print(f"  金融风险准确率: {test_metrics['acc_finance']:.4f}")
    print(f"  财政风险F1: {test_metrics['f1_fiscal']:.4f}")
    print(f"  金融风险F1: {test_metrics['f1_finance']:.4f}")
    print(f"\n财政风险分类报告:\n{test_metrics['report_fiscal']}")
    print(f"\n金融风险分类报告:\n{test_metrics['report_finance']}")

    # 绘制训练历史
    trainer.plot_training_history(save_dir=args.results_dir)

    print(f"\n训练完成! 最佳模型: {best_model_path}")


if __name__ == '__main__':
    main()
