# Lua 展平迁移

将 `lua/imr/` 下所有文件提至 `lua/`，删 `imr.` 前缀。

## 安全网

```bash
git add -A && git commit -m "checkpoint: before lua flatten"
```

出问题：`git reset --hard HEAD` 回到此点。

---

## 步骤清单

### [ ] 1. Git 存档

```bash
git add -A && git commit -m "checkpoint: before lua flatten"
```

### [ ] 2. 移动 `lua/imr/*.lua` 单文件 → `lua/`

```
lua/imr/aux_code.lua              → lua/aux_code.lua
lua/imr/DPY_processor.lua         → lua/DPY_processor.lua
lua/imr/gc.lua                    → lua/gc.lua
lua/imr/hub.lua                   → lua/hub.lua
lua/imr/imr_script_translator.lua → lua/imr_script_translator.lua
lua/imr/select_char.lua           → lua/select_char.lua
lua/imr/tatata.lua                → lua/tatata.lua
lua/imr/T93_filter.lua            → lua/T93_filter.lua
lua/imr/T93_processor.lua         → lua/T93_processor.lua
```

### [ ] 3. 移动 `lua/imr/hub/` → `lua/hub/`

```
lua/imr/hub/ → lua/hub/
```

### [ ] 4. 清理

```
删除 lua/imr/（空目录）
删除 lua/select_character.lua（仅被备份 schema 引用）
```

### [ ] 5. `lua/hub.lua` — require 路径修正（6 处）

```
require("imr.hub.date")       → require("hub.date")
require("imr.hub.lunar")      → require("hub.lunar")
require("imr.hub.uuid")       → require("hub.uuid")
require("imr.hub.unicode")    → require("hub.unicode")
require("imr.hub.number")     → require("hub.number")
require("imr.hub.calculator") → require("hub.calculator")
```

### [ ] 6. `lua/hub/date.lua` — require 路径修正

```
require("imr.hub._util") → require("hub._util")
```

### [ ] 7. `lua/hub/lunar.lua` — require 路径修正

```
require("imr.hub._util") → require("hub._util")
```

### [ ] 8. `imr_DPY.schema.yaml` — `imr.` 前缀删除

```
imr.imr_script_translator@translator → imr_script_translator@translator
imr.hub                               → hub
imr.gc                                → gc
imr.tatata                            → tatata
imr.aux_code                          → aux_code
imr.DPY_processor                     → DPY_processor
```

### [ ] 9. `imr_T93.schema.yaml` — `imr.` 前缀删除

```
imr.imr_script_translator@translator → imr_script_translator@translator
imr.select_char*Translator            → select_char*Translator
imr.select_char*Filter                → select_char*Filter
imr.hub                               → hub
imr.gc                                → gc
imr.tatata                            → tatata
imr.aux_code                          → aux_code
imr.T93_filter                        → T93_filter
imr.T93_processor                     → T93_processor
```

### [ ] 10. 验证无残留

```bash
grep -r "imr\." *.yaml lua/*.lua lua/hub/*.lua
```

应无输出（除 `imr_script_translator.lua` 文件名本身）。

### [ ] 11. 重新部署测试

在小狼毫输入法设定里重新部署，测试：
- 普通打字（拼音候选正常）
- `date` / `time` / `lunar` / `uuid` / `cC1+1`
- 辅助码注释正常

### [ ] 12. Git 提交

```bash
git add -A && git commit -m "flatten lua/imr to lua/"
```

---

## 最终 `lua/` 结构

```
lua/
  hub.lua                  gc.lua
  aux_code.lua             DPY_processor.lua
  imr_script_translator.lua
  select_char.lua          tatata.lua
  T93_filter.lua           T93_processor.lua
  autocap_filter.lua       corrector.lua
  pin_cand_filter.lua      reduce_english_filter.lua
  librime.lua
  hub/
    _util.lua      date.lua
    lunar.lua      uuid.lua
    unicode.lua    number.lua
    calculator.lua
```

共 19 个文件 + `hub/` 目录（7 个文件）。
