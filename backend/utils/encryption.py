"""
数据脱敏工具
"""

import re


def mask_phone(phone: str) -> str:
    """手机号脱敏: 138****8000"""
    if not phone or len(phone) < 7:
        return phone
    return phone[:3] + "****" + phone[-4:]


def mask_id_card(id_card: str) -> str:
    """身份证脱敏: 110***********1234"""
    if not id_card or len(id_card) < 8:
        return id_card
    return id_card[:3] + "*" * (len(id_card) - 7) + id_card[-4:]


def mask_email(email: str) -> str:
    """邮箱脱敏: t***@example.com"""
    if not email or "@" not in email:
        return email
    local, domain = email.split("@", 1)
    if len(local) <= 1:
        return email
    return local[0] + "***@" + domain


def mask_name(name: str) -> str:
    """姓名脱敏: 张*明 / 张*"""
    if not name or len(name) < 2:
        return name
    if len(name) == 2:
        return name[0] + "*"
    return name[0] + "*" * (len(name) - 2) + name[-1]


def mask_dict(data: dict, fields: list[str]) -> dict:
    """批量脱敏字典中的指定字段"""
    result = data.copy()
    for field in fields:
        if field in result and result[field]:
            val = str(result[field])
            if "@" in val:
                result[field] = mask_email(val)
            elif len(val) == 11 and val.isdigit():
                result[field] = mask_phone(val)
            elif len(val) in (15, 18):
                result[field] = mask_id_card(val)
            else:
                result[field] = mask_name(val)
    return result
