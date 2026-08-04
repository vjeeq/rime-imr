import path from 'path';
import { fileURLToPath } from 'url';
import { loadDictFile, type Dict } from './rime.ts';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BASE_DIR = path.join(__dirname, '..', 'dicts', 'keytao');
const SINGLE_DICT = path.join(BASE_DIR, 'keytao.single.dict.yaml');
const PHRASE_DICT = path.join(BASE_DIR, 'keytao.phrase.dict.yaml');
type DictLookup = Record<string, string[]>;
type DictIndex = {
  text2codes: DictLookup;
  code2texts: DictLookup;
};
type CharColumn = 'text' | 'pinyin' | 'code' | 'scode' | 'bcode';
type Char<C extends CharColumn[]> = { [K in C[number]]: string };
const S1_MAP: Record<string, string> = {
  '': 'x',
  // zh: 'f', zh: 'q',
  // ch: 'j', ch: 'w',
  sh: 'e',
}
const S2_MAP: Record<string, string> = {
  iu: 'q', ua: 'q',
  ei: 'w', un: 'w',
  e: 'e',
  eng: 'r',
  uan: 't',
  ong: 'y', iong: 'y',
  ang: 'p',
  a: 's', ia: 's',
  ie: 'd', ou: 'd',
  an: 'f',
  ing: 'g', uai: 'g',
  ai: 'h', ue: 'h', ve: 'h',
  u: 'j', er: 'j',
  i: 'k',
  o: 'l', uo: 'l', v: 'l',
  ao: 'z',
  iang: 'x', // uang: 'x',
  iao: 'c',
  in: 'b',
  ui: 'b',
  en: 'n',
  ian: 'm', // uang: 'm',
};

const ZH_Q = new Set(['an', 'ang', 'ei', 'en', 'eng', 'u', 'un']);
const ZH_F = new Set(['a', 'i', 'ong', 'ou', 'ua', 'uai', 'uan', 'uang', 'ui', 'uo']);
const ZH_QF = new Set(['ai', 'ao', 'e']);

const CH_J = new Set(['ai', 'an', 'ang', 'en', 'eng', 'u', 'un']);
const CH_W = new Set(['a', 'i', 'ong', 'ou', 'ua', 'uai', 'uan', 'uang', 'ui', 'uo']);
const CH_JW = new Set(['ao', 'e']);

function pinyin2scode(pinyin: string): string[] {
  if (pinyin.match(/^[jqxy]u$/)) {
    pinyin = pinyin.replace('u', 'v');
  }
  const [_, s1, s2] = pinyin.match(/^([zcs]h|[bpmfdtnlgkhjqxrzcsyw]?)(.*)/) as RegExpMatchArray;
  const s1_code = S1_MAP[s1] ?? s1;
  const s2_code = S2_MAP[s2] ?? s2;
  switch (s1) {
    case 'zh':
      if (ZH_Q.has(s2)) {
        return ['q' + s2_code];
      }
      if (ZH_F.has(s2)) {
        if (s2 === 'uang') {
          return ['fm', 'fx'];
        } else {
          return ['f' + s2_code];
        }
      }
      return ['f' + s2_code, 'q' + s2_code];
    case 'ch':
      if (CH_J.has(s2)) {
        return ['j' + s2_code];
      }
      if (CH_W.has(s2)) {
        if (s2 === 'uang') {
          return ['wm', 'wx'];
        } else {
          return ['w' + s2_code];
        }
      }
      return ['j' + s2_code, 'w' + s2_code];
    default:
      if (s2 === 'uang') {
        return [s1_code + 'm', s1_code + 'x'];
      } else {
        return [s1_code + s2_code];
      }
  }
}

function buildLookup(data: Dict<['text', 'code']>['data']): DictIndex {
  const textToCodes: DictLookup = {};
  const codeToTexts: DictLookup = {};
  for (const entry of data) {
    (textToCodes[entry.text] ||= []).push(entry.code);
    (codeToTexts[entry.code] ||= []).push(entry.text);
  }
  for (const text of Object.keys(textToCodes)) {
    const maxLen = Math.max(...textToCodes[text].map(c => c.length));
    textToCodes[text] = textToCodes[text].filter(c => c.length === maxLen);
  }
  for (const code of Object.keys(codeToTexts)) {
    codeToTexts[code] = [...new Set(codeToTexts[code])];
  }
  return { text2codes: textToCodes, code2texts: codeToTexts };
}

function findCharShapeCodes(text2codes: DictLookup, text: string, scode: string[]) {
  const codes = text2codes[text] || [];
  const result = [];
  for (const s_code of scode) {
    let longest = '';
    for (const code of codes) {
      if (code.startsWith(s_code) && code.length > longest.length) longest = code;
    }
    if (longest) result.push(longest);
  }
  return result;
}

/**
 * 
 * @param codes 词的字全码 codes[i] = [第i+1个字的全码]
 * @returns 词的所有编码
 */
function generateCodes(codes: string[][]): string[] {
  const combos: string[][] = codes.reduce<string[][]>(
    (acc, curr) => acc.flatMap((c) => curr.map((v) => [...c, v])),
    [[]]
  );
  return [... new Set(combos.flatMap(combo => {
    switch (codes.length) {
      case 2:
        const base2: string = combo[0].slice(0, 2) + combo[1].slice(0, 2);
        return [
          base2,
          base2 + combo[0].charAt(2),
          base2 + combo[0].charAt(2) + combo[1].charAt(2),
        ];
      case 3:
        const base3: string = combo[0].charAt(0) + combo[1].charAt(0) + combo[2].charAt(0);
        return [
          base3,
          base3 + combo[0].charAt(2),
          base3 + combo[0].charAt(2) + combo[1].charAt(2),
          base3 + combo[0].charAt(2) + combo[1].charAt(2) + combo[2].charAt(2),
        ];
      default:
        const base4: string = combo[0].charAt(0) + combo[1].charAt(0) + combo[2].charAt(0) + combo[combo.length - 1].charAt(0);
        return [
          base4,
          base4 + combo[0].charAt(2),
          base4 + combo[0].charAt(2) + combo[1].charAt(2),
        ];
    }
  }))];
}

function lookupCharInfos(chars: Char<['text', 'pinyin']>[], text2codes: DictLookup) {
  const charInfos = [];
  for (let i = 0; i < chars.length; i++) {
    const { text, pinyin } = chars[i];
    const variants = findCharShapeCodes(text2codes, text, pinyin2scode(pinyin));
    if (variants.length === 0) {
      throw Object.assign(new Error('CHAR_NOT_FOUND'), {
        char: text, pinyin, index: i + 1,
      });
    }
    charInfos.push(variants);
  }
  return charInfos;
}

function getAllValidCodes(text, lookup) {
  const chars = [...text];
  const charVariants = [];
  for (const ch of chars) {
    const codes = lookup[ch];
    if (!codes) return [];
    charVariants.push(codes);
  }
  return generateCodes(charVariants);
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
  for (let i = 0; i < chars.length; i++) {
    const spCodes = pinyin2scode(pinyins[i]);
    console.log(`  ${chars[i]} (${pinyins[i]}) -> ${spCodes.join(', ')}`);
  }

  const singleDict = loadDictFile(SINGLE_DICT);
  const singleIdx = buildLookup(singleDict.data);
  const phraseIdx = buildLookup(loadDictFile(PHRASE_DICT).data);

  const charList = chars.map((text, i) => ({ text, pinyin: pinyins[i] }));
  let charInfos;
  try {
    charInfos = lookupCharInfos(charList, singleIdx.text2codes);
  } catch (err) {
    if (err.message === 'CHAR_NOT_FOUND') {
      console.error(`  [错误] 未找到 "${err.char}" 对应拼音 ${err.pinyin} 的条目`);
      process.exit(1);
    }
    throw err;
  }

  console.log('\n=== 步骤2: 查单字字典取形码 ===');
  console.log(`  单字字典条目数: ${singleDict.data.length}`);
  for (let i = 0; i < chars.length; i++) {
    for (const fc of charInfos[i]) {
      const sp = fc.slice(0, 2);
      const shape = fc.slice(2);
      console.log(`  ${chars[i]}: sp="${sp}", 最长码="${fc}", 形码="${shape}", 首形码="${shape[0] || ''}"`);
    }
  }

  const codes = generateCodes(charInfos);

  console.log('\n=== 步骤3: 生成候选编码 ===');
  console.log(`  候选编码 (${codes.length}个): ${codes.join(', ')}`);

  console.log('\n=== 步骤4: 查词组字典 ===');
  console.log(`  词组字典条目数: ${Object.keys(phraseIdx.code2texts).length}`);

  const conflicts = [];
  const available = [];
  for (const code of codes) {
    const texts = phraseIdx.code2texts[code];
    if (texts) {
      conflicts.push({ code, texts });
    } else {
      available.push(code);
    }
  }

  if (conflicts.length > 0) {
    console.log('\n[冲突] 以下编码已存在于词组字典:');
    for (const c of conflicts) {
      console.log(`  ${c.code} -> ${c.texts.join(', ')}`);
    }
  }

  if (available.length > 0) {
    console.log('\n[可用] 以下编码不存在于词组字典:');
    for (const c of available) {
      console.log(`  ${c}`);
    }
  }

  if (conflicts.length === 0 && available.length === 0) {
    console.log('\n[结果] 无候选编码生成');
  }
}

export {
  buildLookup,
  lookupCharInfos,
  generateCodes,
  getAllValidCodes,
  pinyin2scode as pinyinToShuangpin,
};

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
