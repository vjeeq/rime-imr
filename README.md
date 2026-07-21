# IMR Rime 配置

## 部署

**环境要求：** 已安装小狼毫输入法（Weasel），配置目录指向本项目。

### 步骤

1. **下载/同步词库 & 转换**

```powershell
node RunScripts.js
```

从上游拉取词库、辅助码、英文词库、符号、Emoji 等文件，并转换为 Rime 可用格式（执行 `scripts/download.js` → `scripts/transform.js`）。

2. **部署**

```powershell
& "......\weasel-x.x.x\WeaselDeployer.exe" /deploy
```

小狼毫会读取配置目录、编译所有 schema 和 dict，输出到 `build/`。

### 本地工具文件来源

以下文件从 npm 包提取，存放于 `scripts/utils/`，无需运行时 `npm install`：

| 本地路径 | 来源 npm 包 | 原始路径 |
|---|---|---|
| `scripts/utils/js-yaml.js` | `npm install js-yaml` | `node_modules/js-yaml/dist/js-yaml.cjs.js` |
| `scripts/utils/csv-parse.js` | `npm install csv` | `node_modules/csv-parse/dist/cjs/sync.cjs` |