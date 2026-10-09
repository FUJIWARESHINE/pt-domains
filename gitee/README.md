# pt-domains

一份用于代理客户端的分流规则集合，同时提供多种客户端可直接引用的规则格式。

域名去重后按 ASCII 字典序排序。**本仓库为自动同步的镜像仓库，文件由上游规则库推送生成，请勿直接修改。**

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `pt-domains.list` | `DOMAIN-SUFFIX` 纯文本规则列表（软路由 / classical 格式） |
| `pt-domains.yaml` | Mihоmo / Clаsh rule-provider（`behavior: domain`） |
| `singbox.json` | sing-box rule-set（version 2） |
| `pt-domains.mrs` | Mihоmo 二进制规则集（MRS） |

## 订阅地址

```
https://gitee.com/xu-ruzhen/pt-domains/raw/main/pt-domains.list
https://gitee.com/xu-ruzhen/pt-domains/raw/main/pt-domains.yaml
https://gitee.com/xu-ruzhen/pt-domains/raw/main/singbox.json
https://gitee.com/xu-ruzhen/pt-domains/raw/main/pt-domains.mrs
```

## 在软路由中使用（`pt-domains.list`）

文件每行形如：

```
DOMAIN-SUFFIX,example.com
```

`DOMAIN-SUFFIX` 表示同时命中该域名及其所有子域名。把文件下载到软路由，按设备自带的分流 / 规则列表功能导入即可。

如果软路由跑的是 Mihоmo 内核，也可以直接当 `classical` 规则集引用：

```yaml
rule-providers:
  pt-list:
    type: http
    behavior: classical
    format: text
    interval: 86400
    url: "https://gitee.com/xu-ruzhen/pt-domains/raw/main/pt-domains.list"
    path: ./ruleset/pt.list
```

## 在 Mihоmo / Clаsh 中使用

```yaml
rule-providers:
  pt:
    type: http
    behavior: domain
    format: yaml
    interval: 86400
    url: "https://gitee.com/xu-ruzhen/pt-domains/raw/main/pt-domains.yaml"
    path: ./ruleset/pt.yaml

rules:
  - RULE-SET,pt,PROXY
```

## 使用二进制规则集（`pt-domains.mrs`）

`pt-domains.mrs` 是 Mihоmo 的二进制规则集格式（MRS）。它和 `pt-domains.yaml` 表达的是**完全相同的规则**，但加载更快、内存占用更低，规则条目多时优势明显。

引用时把 `format` 改成 `mrs` 即可（`behavior` 仍然是 `domain`）：

```yaml
rule-providers:
  pt:
    type: http
    behavior: domain
    format: mrs
    interval: 86400
    url: "https://gitee.com/xu-ruzhen/pt-domains/raw/main/pt-domains.mrs"
    path: ./ruleset/pt.mrs

rules:
  - RULE-SET,pt,PROXY
```

> MRS 需要 **Mihоmo v1.17.0 及以上**内核；原版 Clаsh Premium 不支持，请继续用 `pt-domains.yaml`。

## 在 sing-box 中使用

```json
{
  "route": {
    "rule_set": [
      {
        "type": "remote",
        "tag": "pt",
        "format": "source",
        "url": "https://gitee.com/xu-ruzhen/pt-domains/raw/main/singbox.json",
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

- `pt-domains.yaml`：每条域名加 `+.` 前缀（`+.example.com` 同时匹配 `example.com` 与 `www.example.com`）
- `pt-domains.mrs`：从 `pt-domains.yaml` 编译而来，所以语义和它完全一致
- `singbox.json`：使用 `domain_suffix`
- `pt-domains.list`：使用 `DOMAIN-SUFFIX`

## 更新说明

本仓库内容随上游规则库自动同步，通常在域名变更提交后十余秒内完成。订阅端按各自的 `interval` / `update_interval` 拉取即可，无需手动干预。
