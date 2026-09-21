# pt-domains

一份自己维护的私有 PT / BT 站点域名集合，用于代理工具的分流规则。

原始列表去重后按 ASCII 字典序排序，并同时输出多种客户端可直接引用的规则格式。

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `source/raw.txt` | 原始域名列表，手工维护。一行一个，可留空行、可写 `#` 注释、顺序随意 |
| `domains.txt` | 去重排序后的纯域名列表，每行一个 |
| `clash.yaml` | Mihomo / Clash rule-provider（`behavior: domain`） |
| `singbox.json` | sing-box rule-set（version 2） |
| `tools/build.ps1` | 从 `source/raw.txt` 生成上面三个产物 |

## 订阅地址

```
https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/domains.txt
https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/clash.yaml
https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/singbox.json
```

## 在 Mihomo / Clash 中使用

```yaml
rule-providers:
  pt:
    type: http
    behavior: domain
    format: yaml
    interval: 86400
    url: "https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/clash.yaml"
    path: ./ruleset/pt.yaml

rules:
  - RULE-SET,pt,PROXY
```

## 在 sing-box 中使用

```json
{
  "route": {
    "rule_set": [
      {
        "type": "remote",
        "tag": "pt",
        "format": "source",
        "url": "https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/singbox.json",
        "update_interval": "24h"
      }
    ],
    "rules": [
      { "rule_set": "pt", "outbound": "proxy" }
    ]
  }
}
```

## 匹配语义

默认生成的是「域名 + 其子域名」语义：

- `clash.yaml`：每条域名加 `+.` 前缀（`+.example.com` 同时匹配 `example.com` 与 `www.example.com`）
- `singbox.json`：使用 `domain_suffix`

若需要严格精确匹配（只匹配列出的域名本身），构建时加 `-Exact` 参数，此时 Clash 不加前缀、sing-box 改用 `domain` 字段。

## 维护方式

```powershell
# 1. 编辑 source/raw.txt，把新域名追加进去
# 2. 重新生成产物
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1

# 3. 提交并推送
git add -A
git commit -m "update: add new domains"
git push
```

构建脚本会自动完成：去空白、跳过空行与 `#` 注释、去掉 `http://` 等协议前缀、去掉端口/路径/查询串、去掉结尾的点、统一转小写、去重、按 ordinal 字典序排序。
