# AGENTS.md

## 部署

运行 Weasel 安装目录下的 `WeaselDeployer.exe /deploy`。

- 改 Lua 文件后需要部署以触发模块重载
- 改 schema.yaml/dict.yaml 文件后需要部署以触发重编译
- `node RunScripts.js` 仅用于下载/转换外部数据，日常改代码不需要

## Lua 调试

Rime Lua 运行时限制：
- `require 'log'` **不可用**（无此模块，会导致崩溃）
- `print()` 输出到 Weasel 控制台，**不写文件**
- `io.open()` **可用**，但工作目录是 Weasel 安装目录

Rime 自身日志：`$env:TEMP\rime.weasel\`，按 INFO/WARNING/ERROR 分级