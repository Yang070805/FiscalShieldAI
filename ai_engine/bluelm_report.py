"""
bluelm_report.py
vivo蓝心大模型报告生成模块（AIGC比赛官方AI能力）

三-tier 调用策略：
  1. 离线 → 本地模板引擎（无网也能用）
  2. 在线默认 → vivo蓝心大模型（比赛官方提供）
  3. 用户自选 → DeepSeek / Qwen / 豆包 / ChatGPT / Claude / Kimi / MiMo

API文档：https://aigc.vivo.com.cn/#/document/index?id=1746

修改记录：
- 2024-04-03: 初始版本，MiMo-V2-Pro
- 2024-04-10: 增加 OpenAI/Anthropic 双协议支持
- 2026-06-01: 重构为 vivo蓝心大模型优先，接入比赛官方API
"""

import json
import os
import sys
import uuid
from typing import Dict, Any, Optional

# requests 延迟导入，减少启动时间


# ============================================================
# 模型配置表
# ============================================================
MODEL_PROVIDERS = {
    # ---- vivo 蓝心（比赛官方） ----
    "bluelm-deepseek": {
        "name": "vivo蓝心 · DeepSeek-V3.2",
        "base_url": "https://api-ai.vivo.com.cn/v1",
        "model": "Volc-DeepSeek-V3.2",
        "auth_type": "bearer",
        "description": "比赛官方，最强推理能力",
    },
    "bluelm-doubao-mini": {
        "name": "vivo蓝心 · 豆包Mini",
        "base_url": "https://api-ai.vivo.com.cn/v1",
        "model": "Doubao-Seed-2.0-mini",
        "auth_type": "bearer",
        "description": "比赛官方，轻量快速",
    },
    "bluelm-doubao-pro": {
        "name": "vivo蓝心 · 豆包Pro",
        "base_url": "https://api-ai.vivo.com.cn/v1",
        "model": "Doubao-Seed-2.0-pro",
        "auth_type": "bearer",
        "description": "比赛官方，均衡性能",
    },
    "bluelm-qwen": {
        "name": "vivo蓝心 · 通义千问",
        "base_url": "https://api-ai.vivo.com.cn/v1",
        "model": "qwen3.5-plus",
        "auth_type": "bearer",
        "description": "比赛官方，中文能力强",
    },
    # ---- 第三方模型（用户自选） ----
    "deepseek": {
        "name": "DeepSeek",
        "base_url": "https://api.deepseek.com/v1",
        "model": "deepseek-chat",
        "auth_type": "bearer",
        "description": "深度求索，性价比高",
    },
    "qwen": {
        "name": "通义千问",
        "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "model": "qwen-plus",
        "auth_type": "bearer",
        "description": "阿里云，中文能力强",
    },
    "doubao": {
        "name": "豆包",
        "base_url": "https://ark.cn-beijing.volces.com/api/v3",
        "model": "doubao-pro-256k",
        "auth_type": "bearer",
        "description": "字节跳动",
    },
    "chatgpt": {
        "name": "ChatGPT",
        "base_url": "https://api.openai.com/v1",
        "model": "gpt-4o",
        "auth_type": "bearer",
        "description": "OpenAI",
    },
    "claude": {
        "name": "Claude",
        "base_url": "https://api.anthropic.com/v1",
        "model": "claude-sonnet-4-20250514",
        "auth_type": "x-api-key",
        "description": "Anthropic",
    },
    "kimi": {
        "name": "Kimi",
        "base_url": "https://api.moonshot.cn/v1",
        "model": "moonshot-v1-8k",
        "auth_type": "bearer",
        "description": "月之暗面",
    },
    "mimo": {
        "name": "小米MiMo",
        "base_url": "https://token-plan-cn.xiaomimimo.com/v1",
        "model": "mimo-v2-pro",
        "auth_type": "bearer",
        "description": "小米大模型",
    },
}

# 环境变量名映射
ENV_KEY_MAP = {
    "bluelm-deepseek": "BLUELM_API_KEY",
    "bluelm-doubao-mini": "BLUELM_API_KEY",
    "bluelm-doubao-pro": "BLUELM_API_KEY",
    "bluelm-qwen": "BLUELM_API_KEY",
    "deepseek": "DEEPSEEK_API_KEY",
    "qwen": "DASHSCOPE_API_KEY",
    "doubao": "DOUBAO_API_KEY",
    "chatgpt": "OPENAI_API_KEY",
    "claude": "ANTHROPIC_API_KEY",
    "kimi": "KIMI_API_KEY",
    "mimo": "MIMO_API_KEY",
}


class ReportGenerator:
    """
    三-tier 大模型报告生成器

    调用顺序：
    1. 无网络 → 本地模板
    2. 有网络 + 蓝心key → vivo蓝心（比赛官方）
    3. 蓝心失败 → 用户配置的其他模型
    """

    def __init__(self,
                 provider: str = "bluelm-deepseek",
                 api_key: str = None,
                 base_url: str = None,
                 model: str = None):
        """
        参数：
            provider: 模型提供商
            api_key: API密钥（优先级高于环境变量）
            base_url: 自定义API地址（可选）
            model: 自定义模型名（可选）
        """
        self.provider = provider
        config = MODEL_PROVIDERS.get(provider, MODEL_PROVIDERS["bluelm-deepseek"])

        self.api_key = api_key or os.environ.get(ENV_KEY_MAP.get(provider, ""), "")
        self.base_url = base_url or config["base_url"]
        self.model = model or config["model"]
        self.auth_type = config["auth_type"]

        # 系统提示词
        self.system_prompt = (
            "你是一位资深的财政风险分析专家，拥有多年地方政府财政研究经验。"
            "你的任务是根据AI模型的预测结果，为用户生成专业、易懂、可操作的财政风险分析报告。\n\n"
            "报告撰写要求：\n"
            "1. 语言通俗易懂，避免过多专业术语，让非专业人士也能理解\n"
            "2. 结构清晰，包含以下部分：风险概况、详细分析、趋势研判、政策建议、重点关注\n"
            "3. 必须结合具体的指标数据给出有说服力的分析，不能泛泛而谈\n"
            "4. 政策建议要具体可行，不要空洞的口号\n"
            "5. 如果发现异常指标，要重点标注并解释其含义\n"
            "6. 使用中文撰写，语气专业但不生硬"
        )

    # ============================================================
    # Prompt 构建
    # ============================================================

    def build_prompt(self, prediction_result: Dict[str, Any]) -> str:
        """将模型预测结果转换为大模型输入 Prompt"""
        r = prediction_result
        city = r.get('city', '目标城市')
        year = r.get('year', 2024)
        fiscal = r.get('fiscal_risk', {})
        metrics = r.get('metrics', {})

        probs = fiscal.get('probability_distribution', [0] * 5)
        risk_labels = ['低风险', '中等偏低', '中等', '中等偏高', '高风险']
        prob_text = "\n".join([
            f"  - {label}：{prob:.1%}"
            for label, prob in zip(risk_labels, probs)
        ])

        # 指标表格
        metric_refs = {
            '负债率(%)': '< 60%',
            '债务率(%)': '< 100%',
            '赤字率(%)': '< 3%',
            '现金短期债务比': '> 1.0',
            '短期债务占比(%)': '< 30%',
            '存贷比(%)': '< 100%',
            '不良贷款率(%)': '< 2%',
            '拨备覆盖率(%)': '> 150%',
            '资本充足率(%)': '> 10.5%',
        }
        metric_lines = []
        for key, ref in metric_refs.items():
            val = metrics.get(key)
            if val is not None:
                metric_lines.append(f"| {key} | {val} | {ref} |")
        metrics_table = "\n".join(metric_lines) if metric_lines else "| （暂无数据） | - | - |"

        prompt = f"""请根据以下AI模型预测结果，为{city}生成一份详细的{year}年财政风险分析报告。

## 一、AI模型预测结果

**基本信息：**
- 城市：{city}
- 预测年份：{year}
- 模型架构：ST-GNN（教师）+ LightTCN（学生，知识蒸馏）

**财政风险预测：**
- 风险等级：{fiscal.get('level', '未知')}
- 置信度：{fiscal.get('confidence', 0):.1%}
- 概率分布：
{prob_text}

## 二、核心财政指标（{year}年）

| 指标 | 数值 | 参考安全线 |
|------|------|-----------|
{metrics_table}

## 三、报告格式要求

请严格按照以下结构输出报告：

### 📊 风险概况
（用2-3句话总结当前风险状态）

### 📈 详细分析
（结合具体指标分析风险成因，至少分析3个关键指标）

### 🔮 趋势研判
（基于历史趋势数据判断未来走向）

### 💡 政策建议
（提出3-5条具体可行的应对措施，每条需要说明理由）

### ⚠️ 重点关注
（指出1-2个最需要特别关注的风险点）"""

        return prompt

    # ============================================================
    # API 调用（vivo蓝心 OpenAI 兼容格式）
    # ============================================================

    def _call_api(self, prompt: str) -> Optional[str]:
        """
        调用 vivo蓝心 API（OpenAI 兼容格式）

        关键点：
        - Endpoint: https://api-ai.vivo.com.cn/v1/chat/completions
        - Auth: Authorization: Bearer <AppKey>
        - Query: request_id=<uuid>
        """
        import requests

        headers = {
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": f"Bearer {self.api_key}"
        }

        # vivo蓝心要求 request_id 作为 query 参数
        request_id = str(uuid.uuid4())
        params = {
            "request_id": request_id
        }

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": self.system_prompt},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 2048,
            "stream": False
        }

        url = f"{self.base_url.rstrip('/')}/chat/completions"

        response = requests.post(
            url,
            headers=headers,
            params=params,
            json=payload,
            timeout=60
        )
        response.raise_for_status()
        result = response.json()

        # 提取回复内容
        content = result["choices"][0]["message"]["content"]
        usage = result.get("usage", {})
        print(f"[Report] Token消耗: 输入{usage.get('prompt_tokens', 0)} / 输出{usage.get('completion_tokens', 0)}")

        return content

    # ============================================================
    # 三-tier 调用策略
    # ============================================================

    def generate_report(self, prediction_result: Dict[str, Any]) -> str:
        """
        三-tier 报告生成：
        1. 无网络 → 本地模板
        2. 有网络 + 有key → 调用vivo蓝心
        3. 蓝心失败 → fallback到其他模型或本地模板
        """
        prompt = self.build_prompt(prediction_result)

        # 检查网络
        has_network = self._check_network()

        if not has_network:
            print("[Report] 无网络连接，使用本地模板")
            return self._fallback_report(prediction_result)

        # 有网络，尝试调用大模型
        # 策略1: 使用当前配置的模型
        if self.api_key:
            try:
                report = self._call_api(prompt)
                if report:
                    print(f"[Report] {self.provider} 调用成功")
                    return report
            except Exception as e:
                print(f"[Report] {self.provider} 失败: {e}")

        # 策略2: 尝试vivo蓝心其他模型
        bluelm_providers = ["bluelm-deepseek", "bluelm-doubao-mini", "bluelm-doubao-pro", "bluelm-qwen"]
        for bp in bluelm_providers:
            if bp == self.provider:
                continue
            try:
                old_provider = self.provider
                old_model = self.model
                config = MODEL_PROVIDERS[bp]
                self.provider = bp
                self.model = config["model"]
                self.base_url = config["base_url"]

                report = self._call_api(prompt)
                if report:
                    print(f"[Report] {config['name']} 调用成功")
                    return report
            except Exception as e:
                print(f"[Report] {bp} 失败: {e}")
            finally:
                self.provider = old_provider
                self.model = old_model

        # 所有API都失败，用本地模板
        print("[Report] 所有API均不可用，使用本地模板")
        return self._fallback_report(prediction_result)

    def _check_network(self) -> bool:
        """快速检查网络连通性"""
        try:
            import requests
            requests.get("https://www.baidu.com", timeout=3)
            return True
        except Exception:
            return False

    # ============================================================
    # 本地 fallback 报告
    # ============================================================

    def _fallback_report(self, prediction_result: Dict[str, Any]) -> str:
        """本地模板报告（离线可用）"""
        r = prediction_result
        fiscal = r.get('fiscal_risk', {})
        city = r.get('city', '目标城市')
        year = r.get('year', 2024)
        level = fiscal.get('level', '未知')
        confidence = fiscal.get('confidence', 0)
        metrics = r.get('metrics', {})

        level_info = {
            '低风险':     {'emoji': '🟢', 'summary': '财政状况健康，各项指标均处于安全范围内。',
                          'advice': ['继续保持审慎的财政管理策略', '利用当前窗口期推进结构性改革', '建立常态化的风险监测机制']},
            '中等偏低':   {'emoji': '🟡', 'summary': '财政状况总体良好，但部分指标需要持续关注。',
                          'advice': ['关注债务率与赤字率的变化趋势', '适当控制新增债务规模', '优化债务期限结构，降低短期偿债压力']},
            '中等':       {'emoji': '🟠', 'summary': '财政状况处于可控范围，但存在一定压力，需要加强监测。',
                          'advice': ['加强财政与金融数据的联动监测', '对高风险领域进行压力测试', '适度收紧财政支出，优先保障重点领域']},
            '中等偏高':   {'emoji': '🔴', 'summary': '财政压力较为明显，需要立即采取预防措施。',
                          'advice': ['立即召开财政风险研判会议', '严格控制新增政府债务', '加快存量债务置换和化解', '建立跨部门风险应对机制']},
            '高风险':     {'emoji': '🚨', 'summary': '财政风险较高，需要立即启动应急响应机制。',
                          'advice': ['立即启动财政应急响应机制', '暂停非必要的财政支出项目', '向上级财政部门报告并寻求支持', '制定专项债务化解方案', '建立每日风险监测和报告制度']},
        }

        info = level_info.get(level, level_info['中等'])

        report = f"""
{'='*50}
   「财智哨兵」{city} {year}年财政风险分析报告
{'='*50}

{info['emoji']} 风险等级：{level}（置信度 {confidence:.1%}）

【风险概况】
{info['summary']}

【核心指标分析】
"""
        debt_ratio = metrics.get('负债率(%)', 0)
        report += f"  {'⚠️' if debt_ratio > 60 else '✅'} 负债率 {debt_ratio}% {'超过60%安全线' if debt_ratio > 60 else '处于安全范围内'}\n"

        cash_ratio = metrics.get('现金短期债务比', 0)
        report += f"  {'⚠️' if cash_ratio < 1.0 else '✅'} 现金短期债务比 {cash_ratio} {'低于1.0，短期流动性偏紧' if cash_ratio < 1.0 else '处于合理水平'}\n"

        deficit_ratio = metrics.get('赤字率(%)', 0)
        report += f"  {'⚠️' if deficit_ratio > 3.0 else '✅'} 赤字率 {deficit_ratio}% {'超过3%国际警戒线' if deficit_ratio > 3.0 else '处于可控范围'}\n"

        report += "\n【政策建议】\n"
        for i, advice in enumerate(info['advice'], 1):
            report += f"  {i}. {advice}\n"

        report += f"""
{'='*50}
  报告由「财智哨兵」AI 系统自动生成
  模型架构：ST-GNN + LightTCN（知识蒸馏）
  报告引擎：本地模板（{self.provider} 在线备选）
{'='*50}"""

        return report


# ============================================================
# 便捷函数
# ============================================================

def generate_report(prediction_result: Dict[str, Any],
                    provider: str = "bluelm-deepseek",
                    api_key: str = None) -> str:
    """快捷调用：一行代码生成报告"""
    gen = ReportGenerator(provider=provider, api_key=api_key)
    return gen.generate_report(prediction_result)


# ============================================================
# 测试入口
# ============================================================

def test_with_mock_data():
    """使用模拟数据测试报告生成"""
    print("=" * 60)
    print("测试: vivo蓝心大模型报告生成")
    print("=" * 60)

    gen = ReportGenerator(provider="bluelm-deepseek")
    print(f"  Provider: {gen.provider}")
    print(f"  Base URL: {gen.base_url}")
    print(f"  Model: {gen.model}")
    print(f"  API Key: {'已配置' if gen.api_key else '未配置（将使用本地模板）'}")
    print()

    mock_result = {
        'city': '镇江',
        'year': 2024,
        'fiscal_risk': {
            'level': '中等偏低',
            'level_index': 1,
            'confidence': 0.72,
            'probability_distribution': [0.05, 0.72, 0.20, 0.03, 0.00]
        },
        'metrics': {
            '负债率(%)': 15.1,
            '债务率(%)': 71.0,
            '赤字率(%)': 2.8,
            '现金短期债务比': 1.07,
            '短期债务占比(%)': 25.8
        }
    }

    report = gen.generate_report(mock_result)
    print(report)


if __name__ == "__main__":
    test_with_mock_data()
