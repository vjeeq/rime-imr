const fs = require('fs');
const path = require('path');

const BASE_DIR = path.join(__dirname, '..', 'dicts', 'keytao');
const SINGLE_DICT = path.join(BASE_DIR, 'keytao.single.dict.yaml');
const PHRASE_DICT = path.join(BASE_DIR, 'keytao.phrase.dict.yaml');

const INITIAL_MAP = {
  b: 'b', p: 'p', m: 'm', f: 'f',
  d: 'd', t: 't', n: 'n', l: 'l',
  g: 'g', k: 'k', h: 'h',
  j: 'j', q: 'q', x: 'x',
  r: 'r', z: 'z', c: 'c', s: 's',
  y: 'y', w: 'w',
  sh: 'e',
};

const ZH_FINALS_OUTER = new Set(['an', 'ang', 'ei', 'en', 'eng', 'u', 'un']);
const ZH_FINALS_INNER = new Set(['a', 'i', 'ong', 'ou', 'ua', 'uai', 'uan', 'uang', 'ui', 'uo']);
const ZH_FINALS_BOTH  = new Set(['ai', 'ao', 'e']);

const CH_FINALS_OUTER = new Set(['ai', 'an', 'ang', 'en', 'eng', 'u', 'un']);
const CH_FINALS_INNER = new Set(['a', 'i', 'ong', 'ou', 'ua', 'uai', 'uan', 'uang', 'ui', 'uo']);
const CH_FINALS_BOTH  = new Set(['ao', 'e']);

const FINAL_MAP = {
  a: 's', ai: 'h', an: 'f', ang: 'p', ao: 'z',
  e: 'e', ei: 'w', en: 'n', eng: 'r', er: 'j',
  i: 'k', ia: 's', ian: 'm', iang: 'x', iao: 'c',
  ie: 'd', in: 'b', ing: 'g', iong: 'y', iu: 'q',
  o: 'l', ong: 'y', ou: 'd',
  u: 'j', ua: 'q', uai: 'g', uan: 't', uang: 'm',
  ue: 'h', ui: 'b', un: 'w', uo: 'l',
  v: 'l',
};

const UANG_ALT = 'x';

function resolveInitials(pinyin) {
  const initials = [];
  let initialPart, finalPart;

  if (pinyin.startsWith('zh')) { initialPart = 'zh'; finalPart = pinyin.slice(2); }
  else if (pinyin.startsWith('ch')) { initialPart = 'ch'; finalPart = pinyin.slice(2); }
  else if (pinyin.startsWith('sh')) { initialPart = 'sh'; finalPart = pinyin.slice(2); }
  else {
    const m = pinyin.match(/^([bpmfdtnlgkhjqxrzcsyw]?)(.*)/);
    initialPart = m[1] || '';
    finalPart = m[2];
  }

  if (initialPart === '') {
    initials.push({ key: 'x', final: finalPart, initial: initialPart });
    return initials;
  }

  if (initialPart === 'zh') {
    const fin = finalPart;
    const outerOk = ZH_FINALS_OUTER.has(fin);
    const innerOk = ZH_FINALS_INNER.has(fin);
    const bothOk  = ZH_FINALS_BOTH.has(fin);

    if (outerOk) {
      initials.push({ key: 'q', final: fin, initial: initialPart });
    }
    if (innerOk) {
      initials.push({ key: 'f', final: fin, initial: initialPart });
    }
    if (bothOk) {
      initials.push({ key: 'q', final: fin, initial: initialPart });
      initials.push({ key: 'f', final: fin, initial: initialPart });
    }
    return initials;
  }

  if (initialPart === 'ch') {
    const fin = finalPart;
    const outerOk = CH_FINALS_OUTER.has(fin);
    const innerOk = CH_FINALS_INNER.has(fin);
    const bothOk  = CH_FINALS_BOTH.has(fin);

    if (outerOk) {
      initials.push({ key: 'j', final: fin, initial: initialPart });
    }
    if (innerOk) {
      initials.push({ key: 'w', final: fin, initial: initialPart });
    }
    if (bothOk) {
      initials.push({ key: 'j', final: fin, initial: initialPart });
      initials.push({ key: 'w', final: fin, initial: initialPart });
    }
    return initials;
  }

  initials.push({ key: INITIAL_MAP[initialPart] || initialPart, final: finalPart, initial: initialPart });
  return initials;
}

function pinyinToShuangpin(pinyin) {
  const results = [];
  const initialOptions = resolveInitials(pinyin);

  for (const opt of initialOptions) {
    let finalKey = FINAL_MAP[opt.final];
    if (['j', 'q', 'x', 'y'].includes(opt.initial) && opt.final === 'u') {
      finalKey = 'l';
    }
    if (finalKey === undefined) {
      finalKey = opt.final;
    }

    const finals = [finalKey];
    if (finalKey === 'm' && opt.final === 'uang') {
      finals.push(UANG_ALT);
    }

    for (const fk of finals) {
      results.push(opt.key + fk);
    }
  }

  return [...new Set(results)];
}

function parseDict(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const entries = [];
  let inBody = false;

  for (const line of lines) {
    if (!inBody) {
      if (line.trim() === '...') { inBody = true; }
      continue;
    }
    if (line.trim() === '') continue;
    if (line.trim().startsWith('#')) continue;
    const parts = line.split('\t');
    if (parts.length >= 2) {
      entries.push({ text: parts[0].trim(), code: parts[1].trim() });
    }
  }

  return entries;
}

function buildSingleIndex(singleEntries) {
  const index = new Map();
  for (const e of singleEntries) {
    const sp = e.code.slice(0, 2);
    const shape = e.code.slice(2);
    if (!index.has(e.text)) index.set(e.text, new Map());
    const charMap = index.get(e.text);
    const prev = charMap.get(sp);
    if (!prev || e.code.length > prev.fullCode.length) {
      charMap.set(sp, {
        sp,
        fullCode: e.code,
        shape,
        firstShape: shape.length > 0 ? shape[0] : '',
      });
    }
  }
  return index;
}

function findCharShapeCodes(singleEntries, char, spCodes, index) {
  if (index) {
    const charMap = index.get(char);
    if (!charMap) return [];
    const result = [];
    for (const sp of spCodes) {
      const info = charMap.get(sp);
      if (info) result.push({ ...info });
    }
    return result;
  }

  const groups = new Map();

  for (const entry of singleEntries) {
    if (entry.text !== char) continue;
    for (const sp of spCodes) {
      if (entry.code.startsWith(sp)) {
        const shapePart = entry.code.slice(sp.length);
        if (!groups.has(sp)) {
          groups.set(sp, []);
        }
        groups.get(sp).push({ sp, code: entry.code, shape: shapePart });
      }
    }
  }

  const result = [];
  for (const [, entries] of groups) {
    entries.sort((a, b) => b.code.length - a.code.length);
    const longest = entries[0];
    result.push({
      sp: longest.sp,
      fullCode: longest.code,
      shape: longest.shape,
      firstShape: longest.shape.length > 0 ? longest.shape[0] : '',
    });
  }
  return result;
}

function cartesian(arrays) {
  if (arrays.length === 0) return [[]];
  const [first, ...rest] = arrays;
  const restProduct = cartesian(rest);
  const result = [];
  for (const item of first) {
    for (const combo of restProduct) {
      result.push([item, ...combo]);
    }
  }
  return result;
}

function generateCodes(wordLen, charVariants) {
  const combos = cartesian(charVariants);
  const results = new Set();

  for (const chars of combos) {
    const sp = chars.map(c => c.sp);
    const s1 = chars.map(c => c.firstShape);

    if (wordLen === 2) {
      results.add(sp[0] + sp[1]);
      results.add(sp[0] + sp[1] + s1[0]);
      results.add(sp[0] + sp[1] + s1[0] + s1[1]);
    } else if (wordLen === 3) {
      const base = sp[0][0] + sp[1][0] + sp[2][0];
      results.add(base);
      results.add(base + s1[0]);
      results.add(base + s1[0] + s1[1]);
      results.add(base + s1[0] + s1[1] + s1[2]);
    } else if (wordLen === 4) {
      const base = sp[0][0] + sp[1][0] + sp[2][0] + sp[3][0];
      results.add(base);
      results.add(base + s1[0]);
      results.add(base + s1[0] + s1[1]);
      results.add(base + s1[0] + s1[1] + s1[2]);
      results.add(base + s1[0] + s1[1] + s1[2] + s1[3]);
    } else {
      const base = sp[0][0] + sp[1][0] + sp[2][0] + sp[wordLen - 1][0];
      results.add(base);
      results.add(base + s1[0]);
      results.add(base + s1[0] + s1[1]);
      results.add(base + s1[0] + s1[1] + s1[2]);
      results.add(base + s1[0] + s1[1] + s1[2] + s1[3]);
    }
  }

  return [...results];
}

function buildPhraseLookup(phraseEntries) {
  const map = new Map();
  for (const entry of phraseEntries) {
    if (!map.has(entry.code)) {
      map.set(entry.code, []);
    }
    map.get(entry.code).push(entry.text);
  }
  for (const [k, v] of map) {
    map.set(k, [...new Set(v)]);
  }
  return map;
}

function checkPhrase(chars, pinyins, dicts) {
  const singleEntries = (dicts && dicts.singleEntries) || parseDict(SINGLE_DICT);
  const phraseLookup = (dicts && dicts.phraseLookup) || buildPhraseLookup(parseDict(PHRASE_DICT));
  const index = dicts && dicts.index;

  const allSpOptions = [];
  for (let i = 0; i < chars.length; i++) {
    allSpOptions.push(pinyinToShuangpin(pinyins[i]));
  }

  const charInfos = [];
  for (let i = 0; i < chars.length; i++) {
    const variants = findCharShapeCodes(singleEntries, chars[i], allSpOptions[i], index);
    if (variants.length === 0) {
      const err = new Error('CHAR_NOT_FOUND');
      err.char = chars[i];
      err.pinyin = pinyins[i];
      err.index = i + 1;
      throw err;
    }
    charInfos.push(variants);
  }

  const codes = generateCodes(chars.length, charInfos);

  const conflicts = [];
  const available = [];
  for (const code of codes) {
    if (phraseLookup.has(code)) {
      conflicts.push({ code, texts: phraseLookup.get(code) });
    } else {
      available.push(code);
    }
  }

  return {
    phrase: chars.join(''),
    wordLen: chars.length,
    charInfos,
    codes,
    conflicts,
    available,
    dictStats: {
      singleEntries: singleEntries.length,
      phraseEntries: phraseLookup.size,
    },
  };
}

function getAllValidCodes(text, singleEntries, index) {
  const chars = [...text];
  const charVariants = [];
  for (const ch of chars) {
    if (index) {
      const charMap = index.get(ch);
      if (!charMap) return [];
      charVariants.push([...charMap.values()]);
    } else {
      const spSet = new Set();
      for (const entry of singleEntries) {
        if (entry.text === ch) {
          spSet.add(entry.code.slice(0, 2));
        }
      }
      const variants = findCharShapeCodes(singleEntries, ch, [...spSet]);
      if (variants.length === 0) return [];
      charVariants.push(variants);
    }
  }
  return generateCodes(chars.length, charVariants);
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('用法: node keytao.js <词组> <拼音1> <拼音2> [<拼音3> ...]');
    console.error('示例: node keytao.js 策视 ce shi');
    console.error('      node keytao.js 不以为然 bu yi wei ran');
    process.exit(1);
  }

  const chars = [...args[0]];
  const pinyins = args.slice(1);

  if (chars.length !== pinyins.length) {
    console.error(`错误: 词组 "${args[0]}" 有 ${chars.length} 字, 但提供了 ${pinyins.length} 个拼音`);
    process.exit(1);
  }

  console.log(`词组: ${args[0]}`);
  console.log(`拼音: ${pinyins.join(' ')}`);
  console.log(`字数: ${chars.length}`);
  console.log('');

  console.log('=== 步骤1: 拼音转键道双拼 ===');
  const allSpOptions = [];
  for (let i = 0; i < chars.length; i++) {
    const spCodes = pinyinToShuangpin(pinyins[i]);
    allSpOptions.push(spCodes);
    console.log(`  ${chars[i]} (${pinyins[i]}) -> ${spCodes.join(', ')}`);
  }

  let result;
  try {
    result = checkPhrase(chars, pinyins);
  } catch (err) {
    if (err.message === 'CHAR_NOT_FOUND') {
      console.error(`  [错误] 未找到 "${err.char}" 对应拼音 ${err.pinyin} 的条目`);
      process.exit(1);
    }
    throw err;
  }

  console.log('\n=== 步骤2: 查单字字典取形码 ===');
  console.log(`  单字字典条目数: ${result.dictStats.singleEntries}`);
  for (let i = 0; i < chars.length; i++) {
    for (const v of result.charInfos[i]) {
      console.log(`  ${chars[i]}: sp="${v.sp}", 最长码="${v.fullCode}", 形码="${v.shape}", 首形码="${v.firstShape}"`);
    }
  }

  console.log('\n=== 步骤3: 生成候选编码 ===');
  console.log(`  候选编码 (${result.codes.length}个): ${result.codes.join(', ')}`);

  console.log('\n=== 步骤4: 查词组字典 ===');
  console.log(`  词组字典条目数: ${result.dictStats.phraseEntries}`);

  if (result.conflicts.length > 0) {
    console.log('\n[冲突] 以下编码已存在于词组字典:');
    for (const c of result.conflicts) {
      console.log(`  ${c.code} -> ${c.texts.join(', ')}`);
    }
  }

  if (result.available.length > 0) {
    console.log('\n[可用] 以下编码不存在于词组字典:');
    for (const c of result.available) {
      console.log(`  ${c}`);
    }
  }

  if (result.conflicts.length === 0 && result.available.length === 0) {
    console.log('\n[结果] 无候选编码生成');
  }
}

module.exports = {
  parseDict,
  buildPhraseLookup,
  buildSingleIndex,
  pinyinToShuangpin,
  findCharShapeCodes,
  generateCodes,
  checkPhrase,
  getAllValidCodes,
};

if (require.main === module) {
  main();
}
