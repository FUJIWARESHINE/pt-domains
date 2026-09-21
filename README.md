# pt-domains

一份自己维护的私有 PT / BT 站点域名集合，用于代理工具的分流规则。

域名去重后按 ASCII 字典序排序，并同时输出多种客户端可直接引用的规则格式。

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `domains.txt` | **唯一维护入口**，一行一个域名；它本身也是可直接订阅的产物 |
| `clash.yaml` | Mihomo / Clash rule-provider（`behavior: domain`），脚本生成，勿手改 |
| `singbox.json` | sing-box rule-set（version 2），脚本生成，勿手改 |
| `tools/build.ps1` | 归一化 `domains.txt` 并生成上面两个规则文件 |
| `tools/update.ps1` | 一键完成「构建 + 提交 + 推送」 |

## 订阅地址

```
https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/domains.txt
https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/clash.yaml
https://raw.githubusercontent.com/FUJIWARESHINE/pt-domains/main/singbox.json
```

## 日常维护

只需要动 `domains.txt` 一个文件，其他都交给脚本。

### 加域名

打开 `domains.txt`，在**任意位置**加一行：

```
example.com
```

顺序不用管、大小写不用管、重复了也没关系。也可以直接写 `+.example.com`、`https://example.com/`、`example.com:443`，脚本会自动整理成 `example.com`。

### 删失效域名

在 `domains.txt` 里删掉对应那一行即可。

### 生成并推送

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\update.ps1
```

这一条命令会依次完成：整理 `domains.txt` → 重新生成 `clash.yaml` 和 `singbox.json` → 提交推送。

想自定义提交信息：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\update.ps1 -Message "add example.com"
```

如果习惯手动操作，等价的两步是：

```powershell
# 1. 整理清单 + 重新生成规则文件
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1

# 2. 提交推送
git add -A
git commit -m "update: refresh domain list"
git push
```

> 注意：本机 `git` 没有加进 PATH，直接敲 `git` 会提示找不到命令。用 `tools\update.ps1` 最省事，它内置了本机 PortableGit 的路径；若要手动执行 git，需写完整路径或用 `-GitExe` 指定。

脚本会自动完成的清理：

- 去空行、跳过 `#` 注释行
- 去掉 `http://`、`https://` 等协议前缀
- 去掉端口、路径、查询串
- 去掉开头的 `+.`、`*.` 通配前缀
- 去掉结尾多余的点
- 统一转小写
- 去重
- 按 ASCII 字典序（ordinal）排序

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

若需要严格精确匹配（只匹配列出的域名本身），构建时加 `-Exact`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1 -Exact
```
