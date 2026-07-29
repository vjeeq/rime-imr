const fs = require('fs');
const path = require('path');

const {
  parseDict,
  buildPhraseLookup,
  checkPhrase,
  getAllValidCodes,
  pinyinToShuangpin,
} = require('./keytao');

const ZI_DICT = path.join(__dirname, '..', 'dicts', 'keytao', 'keytao.single.dict.yaml');
const PHRASE_DICT = path.join(__dirname, '..', 'dicts', 'keytao', 'keytao.phrase.dict.yaml');
const USER_DIR = path.join(__dirname, '..', 'dicts', 'keytao', 'imr');
const OUT_DICT = path.join(__dirname, '..', 'dicts', 'keytao', 'keytao.extended.dict.yaml');

function readDictFull(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');

  let headerEnd = 0;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === '...') {
      headerEnd = i + 1;
      break;
    }
  }
  const header = lines.slice(0, headerEnd).join('\n');

  const entries = [];
  for (let i = headerEnd; i < lines.length; i++) {
    const line = lines[i];
    if (line.trim() === '' || line.trim().startsWith('#')) continue;
    const parts = line.split('\t');
    if (parts.length >= 2) {
      entries.push({
        text: parts[0].trim(),
        code: parts[1].trim(),
        weight: parts.length >= 3 ? parts[2].trim() : '100',
      });
    }
  }

  return { header, entries };
}

function parseMyDict(filePath, warnings, errors) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const entries = [];
  let inBody = false;
  const fileName = path.basename(filePath);

  for (let lineno = 0; lineno < lines.length; lineno++) {
    const line = lines[lineno];
    if (!inBody) {
      if (line.trim() === '...') { inBody = true; }
      continue;
    }
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.startsWith('#')) continue;

    const parts = line.split('\t');
    if (parts.length < 4) {
      errors.push({ summary: `${fileName}:${lineno + 1} 格式不正确 (缺字段, 需4列)` });
      continue;
    }

    const text = parts[0].trim();
    const pinyins = parts[1].trim().split(/\s+/);
    const code = parts[2].trim();
    const weight = parseInt(parts[3].trim(), 10);

    if (pinyins.length < 1 || pinyins[0] === '') {
      errors.push({ summary: `${fileName}:${lineno + 1} "${text}" stem 列为空` });
      continue;
    }

    if (weight === 0) {
      const chars = [...text];
      entries.push({ text, chars, pinyins: chars.map(() => ''), code, weight: 0, file: fileName, line: lineno + 1 });
      continue;
    }

    if (weight !== 100 && weight !== 1000) {
      errors.push({ summary: `${fileName}:${lineno + 1} "${text}" 权重不是0/100/1000` });
      continue;
    }

    const chars = [...text];

    if (pinyins.length !== chars.length) {
      errors.push({
        summary: `${fileName}:${lineno + 1} "${text}" 拼音数量(${pinyins.length})与字数(${chars.length})不匹配`,
      });
      continue;
    }

    entries.push({ text, chars, pinyins, code, weight, file: fileName, line: lineno + 1 });
  }

  return entries;
}

function formatLine(entry) {
  return `${entry.text}\t${entry.code}\t${entry.weight}`;
}

function getSpPos(charIdx, wordLen) {
  if (wordLen === 2) return charIdx * 2;
  if (charIdx < 3) return charIdx;
  return 3;
}

function variantUsedInCodes(codes, charIdx, wordLen, variant) {
  const pos = getSpPos(charIdx, wordLen);
  if (wordLen === 2) {
    return codes.some(c => c.length > pos + 1 && c.slice(pos, pos + 2) === variant);
  }
  return codes.some(c => c.length > pos && c[pos] === variant[0]);
}

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { outDict: OUT_DICT };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--output' && i + 1 < args.length) {
      opts.outDict = path.resolve(args[++i]);
    }
  }
  return opts;
}

function printSummary(warnings, errors) {
  if (warnings.length > 0) {
    console.log('\n--- 警告 ---');
    for (const w of warnings) {
      console.log(`  ${w}`);
    }
  }
  if (errors.length > 0) {
    console.log('\n' + '='.repeat(50));
    console.log('  错误/冲突汇总');
    console.log('='.repeat(50));
    for (let i = 0; i < errors.length; i++) {
      const err = errors[i];
      console.log(`\n[${i + 1}] ${err.summary}`);
      if (err.detail) {
        console.log(`    ${err.detail}`);
      }
    }
    console.log('\n请解决以上问题后重试。');
  }
}

function copyPhraseDict(outPath) {
  const outPhrase = readDictFull(PHRASE_DICT);
  const outBody = outPhrase.entries.map(formatLine).join('\n');
  fs.writeFileSync(outPath, outPhrase.header + '\n' + outBody + '\n', 'utf-8');
}

function main() {
  const opts = parseArgs();
  const errors = [];
  const warnings = [];

  console.log('=== 步骤1: 读取用户词典 ===');
  if (!fs.existsSync(USER_DIR)) {
    fs.mkdirSync(USER_DIR, { recursive: true });
  }
  const myDictFiles = fs.readdirSync(USER_DIR).filter(f => /.*\.dict\.yaml$/.test(f)).map(f => path.join(USER_DIR, f));
  if (myDictFiles.length === 0) {
    console.log('  未找到用户词典文件，直接复制官方词典');
    copyPhraseDict(opts.outDict);
    console.log(`  已写入: ${opts.outDict}`);
    process.exit(0);
  }
  console.log(`  目录: ${USER_DIR}`);
  console.log(`  文件: ${myDictFiles.length} 个`);
  const myEntries = [];
  for (const f of myDictFiles) {
    const entries = parseMyDict(f, warnings, errors);
    myEntries.push(...entries);
    console.log(`    ${path.basename(f)} (${entries.length} 条)`);
  }
  if (errors.length > 0) {
    console.log(`  格式错误: ${errors.length} 条`);
    printSummary(warnings, errors);
    console.log('用户词典格式错误，终止。');
    process.exit(1);
  }
  if (myEntries.length === 0) {
    console.log('  无有效用户条目，直接复制官方词典');
    copyPhraseDict(opts.outDict);
    console.log(`  已写入: ${opts.outDict}`);
    process.exit(0);
  }
  console.log(`  有效条目总计: ${myEntries.length}`);
  for (const e of myEntries) {
    if (e.weight === 0) {
      console.log(`  [删除] ${e.text} (${e.code})`);
    } else {
      console.log(`  [${e.weight === 1000 ? '新增' : '修改'}] ${e.text} (${e.code})`);
    }
  }

  console.log('\n=== 步骤2: 加载官方词典 ===');
  const phraseFull = readDictFull(PHRASE_DICT);
  console.log(`  词组词典条目: ${phraseFull.entries.length}`);

  const singleEntries = parseDict(ZI_DICT);
  const dicts = { singleEntries, phraseLookup: buildPhraseLookup(phraseFull.entries) };

  console.log('\n=== 步骤3: 校验编码合法性 ===');
  let hasError = false;
  for (const e of myEntries) {
    if (e.weight === 0) continue;
    try {
      const result = checkPhrase(e.chars, e.pinyins, dicts);
      if (!result.codes.includes(e.code)) {
        const msg = `${e.file}:${e.line} "${e.text}" 编码 "${e.code}" 不符合规则`;
        console.error(`  [错误] ${msg}`);
        console.error(`         合法候选: ${result.codes.join(', ')}`);
        errors.push({ summary: msg, detail: `合法候选: ${result.codes.join(', ')}` });
        hasError = true;
      }
    } catch (err) {
      if (err.message === 'CHAR_NOT_FOUND') {
        const msg = `${e.file}:${e.line} "${e.text}" 第${err.index}字 "${err.char}" (拼音 "${err.pinyin}") 在单字字典中未找到`;
        console.error(`  [错误] ${msg}`);
        errors.push({ summary: msg });
        hasError = true;
      } else {
        throw err;
      }
    }
  }

  const codesByText = new Map();
  for (const e of myEntries) {
    if (e.weight === 0) continue;
    if (!codesByText.has(e.text)) codesByText.set(e.text, []);
    codesByText.get(e.text).push(e.code);
  }

  for (const e of myEntries) {
    if (e.weight === 0) continue;
    const myCodes = codesByText.get(e.text) || [];
    for (let i = 0; i < e.chars.length; i++) {
      const variants = pinyinToShuangpin(e.pinyins[i]);
      if (variants.length <= 1) continue;
      const uncovered = variants.filter(v => !variantUsedInCodes(myCodes, i, e.chars.length, v));
      if (uncovered.length > 0) {
        warnings.push(`[提示] ${e.file}:${e.line} "${e.text}" 第${i + 1}字 "${e.chars[i]}" (${e.pinyins[i]}) 双拼变体: ${variants.join(', ')} (未覆盖: ${uncovered.join(', ')})`);
      }
    }
  }

  const codeCount = new Map();
  for (const e of myEntries) {
    if (e.weight === 0) continue;
    if (!codeCount.has(e.code)) codeCount.set(e.code, []);
    codeCount.get(e.code).push(e);
  }
  for (const [code, entries] of codeCount) {
    if (entries.length > 1) {
      const names = entries.map(e => `"${e.text}"(${e.file}:${e.line})`).join(', ');
      warnings.push(`编码 "${code}" 在用户词典中重复: ${names}`);
    }
  }

  if (hasError) {
    printSummary(warnings, errors);
    console.log('编码校验未通过，终止。');
    process.exit(1);
  }
  console.log('  全部编码合法');

  console.log('\n=== 步骤4: 检查 text 同时出现在100和1000中 ===');
  const texts100 = new Set(myEntries.filter(e => e.weight === 100).map(e => e.text));
  const texts1000 = new Set(myEntries.filter(e => e.weight === 1000).map(e => e.text));
  for (const t of texts100) {
    if (texts1000.has(t)) {
      const msg = `"${t}" 同时出现在100-weight和1000-weight条目中, 语义矛盾`;
      console.error(`  [错误] ${msg}`);
      errors.push({ summary: msg });
      hasError = true;
    }
  }
  if (hasError) {
    printSummary(warnings, errors);
    console.log('终止。');
    process.exit(1);
  }
  console.log('  通过');

  console.log('\n=== 步骤5: 删除显式100-weight对应的旧条目 ===');
  const allUserCodeSet = new Set(myEntries.map(e => e.code));
  const workingEntries = [];
  const removed = [];

  for (const entry of phraseFull.entries) {
    let shouldRemove = false;
    for (const me of myEntries) {
      if (me.weight === 100 && entry.text === me.text && allUserCodeSet.has(entry.code)) {
        shouldRemove = true;
        break;
      }
    }
    if (shouldRemove) {
      removed.push(entry);
    } else {
      workingEntries.push(entry);
    }
  }

  if (removed.length > 0) {
    console.log('  删除的旧条目:');
    for (const r of removed) {
      console.log(`    ${r.text}\t${r.code}\t${r.weight}`);
    }
  } else {
    console.log('  (无需删除)');
  }

  const remove0Entries = myEntries.filter(e => e.weight === 0);
  if (remove0Entries.length > 0) {
    console.log('  删除的旧条目 (权重0):');
    for (const e of remove0Entries) {
      for (let i = workingEntries.length - 1; i >= 0; i--) {
        if (workingEntries[i].text === e.text && workingEntries[i].code === e.code) {
          console.log(`    ${workingEntries[i].text}\t${workingEntries[i].code}\t${workingEntries[i].weight}`);
          workingEntries.splice(i, 1);
        }
      }
    }
  }

  console.log('\n=== 步骤6: 自动推导100-weight (解决1000条目冲突) ===');
  const auto100 = [];
  const implicitRemoved = [];
  let cannotResolve = false;

  const entries1000 = myEntries.filter(e => e.weight === 1000);
  const codes1000Set = new Set(entries1000.map(e => e.code));

  for (let i = workingEntries.length - 1; i >= 0; i--) {
    if (texts1000.has(workingEntries[i].text)) {
      implicitRemoved.push(workingEntries[i]);
      workingEntries.splice(i, 1);
    }
  }

  for (const me of entries1000) {
    const workCodeSet = new Set(workingEntries.map(e => e.code));

    if (!workCodeSet.has(me.code)) continue;

    const conflictedOldEntries = workingEntries.filter(e => e.code === me.code);
    const uniqueTexts = [...new Set(conflictedOldEntries.map(e => e.text))];

    console.log(`  1000条目 "${me.text}" (${me.code}) 冲突 -> ${uniqueTexts.map(t => `"${t}"`).join(', ')}`);

    for (const conflictText of uniqueTexts) {
      if (texts1000.has(conflictText)) {
        console.log(`    -> "${conflictText}" 已有1000条目, 跳过自动推导`);
        continue;
      }

      const allCodes = getAllValidCodes(conflictText, singleEntries);
      if (allCodes.length === 0) {
        const msg = `"${conflictText}" 在单字字典中无匹配条目 (因 "${me.text}" 冲突)`;
        console.error(`    [错误] ${msg}`);
        errors.push({ summary: msg, detail: `冲突编码: ${me.code}` });
        cannotResolve = true;
        continue;
      }

      const candidates = allCodes
        .filter(c => c.startsWith(me.code) && c.length > me.code.length)
        .sort((a, b) => a.length - b.length);

      if (candidates.length === 0) {
        const msg = `"${conflictText}" 无可用的更长编码 (当前 ${me.code}, 因 "${me.text}" 冲突)`;
        console.error(`    [错误] ${msg}`);
        errors.push({ summary: msg, detail: `冲突编码: ${me.code}` });
        cannotResolve = true;
        continue;
      }

      let resolved = false;
      const blockedBy = [];
      for (const cand of candidates) {
        const unresolvable = [...new Set(
          phraseFull.entries
            .filter(e => e.code === cand)
            .filter(e => !codes1000Set.has(e.code))
            .filter(e => !texts1000.has(e.text))
            .map(e => e.text)
        )];

        if (unresolvable.length > 0) {
          if (unresolvable.length === 1 && unresolvable[0] === conflictText) {
            continue;
          }
          blockedBy.push({ cand, occupier: unresolvable.join(', ') });
          continue;
        }

        auto100.push({
          text: conflictText,
          code: cand,
          weight: '100',
          cause: me.text,
        });
        console.log(`    -> "${conflictText}" 自动改为 ${cand}`);
        resolved = true;
        break;
      }

      if (!resolved) {
        if (blockedBy.length > 0) {
          for (const b of blockedBy) {
            const errMsg = `候选编码 "${b.cand}" 在官方词典中被 "${b.occupier}" 占用, 无法自动解决`;
            console.error(`    [错误] ${errMsg}`);
            errors.push({ summary: errMsg, detail: `因 "${me.text}" 冲突, 尝试将 "${conflictText}" 改为 ${b.cand}` });
          }
        } else {
          const msg = `"${conflictText}" 所有候选编码 (${candidates.join(', ')}) 均被占用 (因 "${me.text}" 冲突)`;
          console.error(`    [错误] ${msg}`);
          errors.push({ summary: msg, detail: `冲突编码: ${me.code}` });
        }
        cannotResolve = true;
      }
    }

    if (!cannotResolve) {
      for (const old of conflictedOldEntries) {
        const idx = workingEntries.indexOf(old);
        if (idx >= 0) {
          workingEntries.splice(idx, 1);
          implicitRemoved.push(old);
        }
      }
    }
  }

  if (implicitRemoved.length > 0) {
    console.log('\n  隐式删除的旧条目 (为自动100让位):');
    for (const r of implicitRemoved) {
      console.log(`    ${r.text}\t${r.code}\t${r.weight}`);
    }
  }

  if (auto100.length > 0) {
    console.log('\n  自动生成的100-weight条目:');
    for (const a of auto100) {
      console.log(`    ${a.text}\t${a.code}\t${a.weight}  (因 "${a.cause}" 占用原编码)`);
    }
  } else {
    console.log('  (无需自动推导)');
  }

  if (cannotResolve) {
    printSummary(warnings, errors);
    console.log('存在无法自动解决的冲突，终止。请手动添加100-weight条目。');
    process.exit(1);
  }

  console.log('\n=== 步骤7: 最终冲突检查 ===');
  const finalCodeSet = new Set(workingEntries.map(e => e.code));
  const plannedEntries = new Map();
  const codeToText = new Map();

  for (const me of myEntries) {
    if (me.weight === 0) continue;
    const prev = codeToText.get(me.code);
    if (prev !== undefined && prev !== me.text) {
      const msg = `编码 "${me.code}" 被 "${me.text}"(${me.file}:${me.line}) 与 "${prev}" 重复使用`;
      console.error(`  [冲突] ${msg}`);
      errors.push({ summary: msg });
      hasError = true;
    }
    codeToText.set(me.code, me.text);
  }

  for (const me of myEntries) {
    if (me.weight === 0) continue;
    const key = `${me.text}\t${me.code}`;
    if (finalCodeSet.has(me.code)) {
      const existing = workingEntries.filter(e => e.code === me.code);
      const names = existing.map(ex => `"${ex.text}"`).join(', ');
      const msg = `编码 "${me.code}" 被 "${me.text}" 与工作集中的 ${names} 冲突`;
      console.error(`  [冲突] ${msg}`);
      for (const ex of existing) {
        console.error(`          ${ex.text}\t${ex.code}\t${ex.weight}`);
      }
      errors.push({ summary: msg });
      hasError = true;
    }
    if (plannedEntries.has(key)) {
      if (plannedEntries.get(key).weight === (me.weight === 1000 ? '1000' : '100')) {
        continue;
      }
      const msg = `"${me.code}" (${me.text}) 在用户词典中重复出现但权重不一致`;
      console.error(`  [冲突] ${msg}`);
      errors.push({ summary: msg });
      hasError = true;
    }
    plannedEntries.set(key, {
      text: me.text,
      code: me.code,
      weight: me.weight === 1000 ? '1000' : '100',
    });
  }

  for (const a of auto100) {
    const key = `${a.text}\t${a.code}`;
    if (finalCodeSet.has(a.code)) {
      const existing = workingEntries.filter(e => e.code === a.code);
      const names = existing.map(ex => `"${ex.text}"`).join(', ');
      const msg = `自动编码 "${a.code}" ("${a.text}" 自动推导) 与工作集中的 ${names} 冲突`;
      console.error(`  [冲突] ${msg}`);
      errors.push({ summary: msg });
      hasError = true;
    }
    if (plannedEntries.has(key)) {
      const msg = `自动编码 "${a.code}" ("${a.text}" 自动推导) 与用户词典重复`;
      console.error(`  [冲突] ${msg}`);
      errors.push({ summary: msg });
      hasError = true;
    }
    plannedEntries.set(key, a);
  }

  if (hasError) {
    printSummary(warnings, errors);
    console.log('存在冲突，不生成输出文件。请手动解决。');
    process.exit(1);
  }

  console.log('  无冲突');

  console.log('\n=== 步骤8: 生成合并词典 ===');
  const newEntries = [...plannedEntries.values()];

  const totalEntries = workingEntries.length + newEntries.length;
  console.log(`  原词典保留: ${workingEntries.length} 条`);
  console.log(`  删除 (显式): ${removed.length} 条`);
  console.log(`  删除 (隐式): ${implicitRemoved.length} 条`);
  console.log(`  新增/修改: ${newEntries.length} 条`);
  const userCount = myEntries.length;
  const autoCount = auto100.length;
  if (autoCount > 0) {
    console.log(`    (其中 ${userCount} 条来自用户词典, ${autoCount} 条为自动生成)`);
  }
  console.log(`  总计: ${totalEntries} 条`);

  const header = phraseFull.header.replace('name: keytao.phrase', 'name: keytao.extended');
  const body = workingEntries.map(formatLine).join('\n') +
    '\n' +
    newEntries.map(formatLine).join('\n');

  fs.writeFileSync(opts.outDict, header + '\n' + body + '\n', 'utf-8');
  console.log(`  已写入: ${opts.outDict}`);

  printSummary(warnings, errors);
}

module.exports = main;

if (require.main === module) {
  main();
}
