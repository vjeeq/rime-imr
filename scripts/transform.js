const fs = require('fs');
const path = require('path');
/** @type {string} */
const PROJECT_ROOT = path.join(__dirname, '..');
const YAML_JS = require(path.join(PROJECT_ROOT, 'scripts', 'utils', 'js-yaml'));
const { parse: csvParse } = require(path.join(PROJECT_ROOT, 'scripts', 'utils', 'csv-parse'));
/** @type {string} */
const AUX_TYPE = '墨奇';
/** @type {Record<string, [number, number]>} 九宫格字母→[行号, 列号] */
const T93_EN_NUM = {
    /**
      # |by*|kvc|qso|
      # |fnz|pix|gte|
      # |jml|ruw|hda|
     */
    'b': [1, 1], 'y': [1, 2],
    'k': [2, 1], 'v': [2, 2], 'c': [2, 3],
    'q': [3, 1], 's': [3, 2], 'o': [3, 3],
    'f': [4, 1], 'n': [4, 2], 'z': [4, 3],
    'p': [5, 1], 'i': [5, 2], 'x': [5, 3],
    'g': [6, 1], 't': [6, 2], 'e': [6, 3],
    'j': [7, 1], 'm': [7, 2], 'l': [7, 3],
    'r': [8, 1], 'u': [8, 2], 'w': [8, 3],
    'h': [9, 1], 'd': [9, 2], 'a': [9, 3],
}
// 声调表：调号字符→[去调拼音, 调值]
/** @type {Record<string, [string, number]>} */
const TONE_TABLE = {
    'ā': ['a', 1], 'á': ['a', 2], 'ǎ': ['a', 3], 'à': ['a', 4],
    'ē': ['e', 1], 'é': ['e', 2], 'ě': ['e', 3], 'è': ['e', 4],
    'ī': ['i', 1], 'í': ['i', 2], 'ǐ': ['i', 3], 'ì': ['i', 4],
    'ō': ['o', 1], 'ó': ['o', 2], 'ǒ': ['o', 3], 'ò': ['o', 4],
    'ū': ['u', 1], 'ú': ['u', 2], 'ǔ': ['u', 3], 'ù': ['u', 4],
    'ǖ': ['v', 1], 'ǘ': ['v', 2], 'ǚ': ['v', 3], 'ǜ': ['v', 4],
    'ń': ['n', 2], 'ň': ['n', 3], 'ǹ': ['n', 4],
    'ḿ': ['m', 2], 'm̀': ['m', 4],
};
// 全拼→自然码转换规则
/** @type {Array<[RegExp, string]>} */
const XFORM = [
    [/^([aoe])(ng)?$/, '$1$1$2'],
    [/iu$/, 'Q'],
    [/[iu]a$/, 'W'],
    [/[uv]an$/, 'R'],
    [/[uv]e$/, 'T'],
    [/ing$|uai$/, 'Y'],
    [/^sh/, 'U'],
    [/^ch/, 'I'],
    [/^zh/, 'V'],
    [/uo$/, 'O'],
    [/[uv]n$/, 'P'],
    [/(.)i?ong$/, '$1S'],
    [/[iu]ang$/, 'D'],
    [/(.)en$/, '$1F'],
    [/(.)eng$/, '$1G'],
    [/(.)ang$/, '$1H'],
    [/ian$/, 'M'],
    [/(.)an$/, '$1J'],
    [/iao$/, 'C'],
    [/(.)ao$/, '$1K'],
    [/(.)ai$/, '$1L'],
    [/(.)ei$/, '$1Z'],
    [/ie$/, 'X'],
    [/ui$/, 'V'],
    [/(.)ou$/, '$1B'],
    [/in$/, 'N'],
];
/**
 * 解析 zi.dict.yaml 内容，全拼→自然码双拼。
 * @param {string} content - zi.dict.yaml 文件内容
 * @returns {Array<{cn: string, codes: string[], tone: number}>}
 */
function parseZiDict(content) {
    const lines = content.split('\n');
    const result = [];
    for (const line of lines) {
        const parts = line.trim().split('\t');
        if (parts.length < 2 || parts[0].startsWith('#')) continue;
        const cn = parts[0];
        let pinyin = parts[1];
        let tone = 5;
        const tm = pinyin.match(new RegExp(Object.keys(TONE_TABLE).join('|')));
        if (tm) {
            const [b, t] = TONE_TABLE[tm[0]];
            tone = t;
            pinyin = pinyin.replace(tm[0], b);
        }
        pinyin = pinyin.replace(/^ng$/, 'eng').replace(/^n$/, 'en').replace(/^m$/, 'me');
        const d1 = /^([jqxy])u$/.exec(pinyin);
        const d2 = /^([aoe])([ioun])$/.exec(pinyin);
        const codes = [...new Set(
            [pinyin, d1 && d1[1] + 'v', d2 && d2[1] + d2[1] + d2[2]].filter(Boolean).map(
                sp => XFORM.reduce((s, [p, r]) => s.replace(p, r), sp).toLowerCase()
            )
        )];
        result.push({ cn, codes, tone });
    }
    return result;
}
/** @type {Record<string, (source_map: Record<string, string>) => Record<string, string>>} */
const TRANSFORMER = {
    /**
     * 万象辅助码 → 辅助码字典（DPY + T93）
     * @param {{csv: string}} source_map
     * @returns {{DPY: string, T93: string}}
     */
    wanxiang_auxcode({ csv: content }) {
        const rows = csvParse(content, { bom: true, skip_empty_lines: true, columns: false, relax_column_count: true });
        const header = rows[0];
        const colIdx = header.indexOf(AUX_TYPE);
        const cnIdx = 0;
        let DPY = '', T93 = '';
        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            const cn = (row[cnIdx] || '').trim();
            const field = (row[colIdx] || '').trim();
            if (!cn || !field) continue;
            const parts = field.split('|').map(p => p.trim());
            const codes = [];
            for (const part of parts) {
                const raw = part.includes(' ') ? part.split(' ').pop() : part;
                raw.split(',').map(c => c.trim()).filter(c => c && /^[a-z]+$/.test(c)).forEach(c => codes.push(c));
            }
            for (const code of codes) {
                DPY += `${cn}\t${code}\n`;
                if (code.length >= 2) {
                    const en1 = code.charAt(0);
                    const en2 = code.charAt(1);
                    const p1 = T93_EN_NUM[en1], p2 = T93_EN_NUM[en2];
                    if (!p1 || !p2) continue;
                    const n1 = p1[0], n2 = p2[0], n3 = (p1[1] - 1) * 3 + p2[1];
                    T93 += `${cn}\t${n1}${n2}${n3}\n${cn}\t${n1}${n2}0\n`;
                }
            }
        }
        return { DPY, T93 };
    },
    /**
     * 万象辅助码注释 → 注释字典
     * @param {{csv: string}} source_map
     * @returns {{comment: string}}
     */
    wanxiang_auxcode_comment({ csv: content }) {
        const rows = csvParse(content, { bom: true, skip_empty_lines: true, columns: false, relax_column_count: true });
        const header = rows[0];
        const colIdx = header.indexOf(AUX_TYPE);
        const cnIdx = 0;
        let comment = '';
        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            const cn = (row[cnIdx] || '').trim();
            const field = (row[colIdx] || '').trim();
            if (!cn || !field) continue;
            comment += `${cn}\t${field.replace(/ /g, '')}\n`;
        }
        return { comment };
    },
    /**
     * 万象 pro：给每个词条的拼音加辅助码后缀。
     * @param {Record<string, string>} source_map - aux_csv, zi, jichu, lianxiang 等
     * @returns {Record<string, string>}
     */
    wanxiang_pro(source_map) {
        const rows = csvParse(source_map.aux_csv, { bom: true, skip_empty_lines: true, columns: false, relax_column_count: true });
        const header = rows[0];
        const colIdx = header.indexOf(AUX_TYPE);
        const cnIdx = 0;
        const aux_map = {};
        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            const cn = (row[cnIdx] || '').trim();
            const field = (row[colIdx] || '').trim();
            if (!cn || !field) continue;
            const parts = field.split('|').map(p => p.trim());
            const codes = [];
            for (const part of parts) {
                const raw = part.includes(' ') ? part.split(' ').pop() : part;
                raw.split(',').map(c => c.trim()).filter(c => c && /^[a-z]+$/.test(c)).forEach(c => codes.push(c));
            }
            if (codes.length > 0) {
                aux_map[cn] = codes.join(',');
            }
        }
        return Object.keys(source_map).filter(key => key != 'aux_csv')
            .map(key => ({ key, context: source_map[key] }))
            .map(({ key, context }) => {
                let source_lines = context.split('\n');
                let shift = undefined;
                while ((shift = source_lines.shift()) !== '...' && shift !== undefined);
                return {
                    key, context: source_lines
                        .map(line => line.trim())
                        .filter(line => line)
                        .filter(line => line.charAt(0) != '#')
                        .map(line => line.split('\t'))
                        .map(([cn, en, ...other]) => [[...cn], en.split(' '), other])
                        .map(([cn_arr, en_arr, other_arr]) => [cn_arr.join(''), en_arr.map((en, index) => `${en};${aux_map[cn_arr[index]] ?? ''}`).join(' '), other_arr])
                        .reduce((context, [cn, en, other_arr]) => {
                            context += [cn, en, ...other_arr].join('\t')
                            context += '\n';
                            return context
                        }, '')
                }
            })
            .reduce((result, { key, context }) => {
                result[key] = context;
                return result;
            }, {})
    },
    /**
     * 雾凇英文 + 中英混输三合一。用 zi.dict 的合法自然码前缀过滤短词。
     * @param {{en_dict: string, en_ext_dict: string, cn_en_txt: string}} source_map
     * @returns {{english: string}}
     */
    ice_english_merge(source_map) {
        const { en_dict, en_ext_dict, cn_en_txt } = source_map;

        // 从 zi.dict.yaml 提取所有合法自然码 2 字母前缀
        const ziContent = fs.readFileSync(path.join(__dirname, '..', 'dicts/wanxiang/zi.dict.yaml'), 'utf8');
        const ziChars = parseZiDict(ziContent);
        const valid2Letter = new Set(ziChars.flatMap(zc => zc.codes.map(c => c.substring(0, 2))));

        const parseDict = (txt) => txt.split('\n')
            .map(l => l.trim())
            .filter(l => l && l[0] !== '#' && l !== '---' && l !== '...')
            .map(l => l.split('\t'))
            .filter(p => p.length >= 1 && p[0])
            .filter(p => /^[a-zA-Z0-9]+$/.test(p[0]))
            .filter(p => {
                const code = p[0];
                if (code.length <= 3 && code === code.toLowerCase()) {
                    // 前2字母不是自然码 → 不可能有中文冲突 → 保留
                    return !valid2Letter.has(code.substring(0, 2));
                }
                return true;
            })
            .map(p => `${p[0]}\t${p[1] || p[0]}`);

        const enWords = [...new Set(parseDict(en_dict))];
        const enExtWords = [...new Set(parseDict(en_ext_dict))];

        const cnEnLines = cn_en_txt.split('\n')
            .map(l => l.trim())
            .filter(l => l && l[0] !== '#')
            .map(l => l.split('\t'))
            .filter(p => p.length >= 2 && p[1])
            .map(([cn, code]) => `${cn}\t${code.toLowerCase()}`);

        const merged = [
            ...enWords,
            ...enExtWords,
            ...cnEnLines,
        ].map(s => s + '\n').join('');

        return { english: merged };
    },
    /**
     * 万象方案 → 语法模型参数
     * @param {{schema: string}} source_map
     * @returns {{grammar: string}}
     */
    grammar(source_map) {
        const source = source_map.schema
        const source_json = YAML_JS.load(source)
        const target_json = {}
        target_json.grammar = source_json.grammar
        target_json.translator = {
            contextual_suggestions: false,
            max_homophones: source_json.translator?.max_homophones,
            max_homographs: source_json.translator?.max_homographs,
        }
        const target = YAML_JS.dump(target_json)
        return { grammar: target }
    },
    /**
     * 万象字表 → 拼音源字典（DPY 双拼 + T93 九键）
     * @param {{zi: string}} source_map
     * @returns {{DPY: string, T93: string}}
     */
    wanxiang_source(source_map) {
        const TONE_DPY = { 1: '1', 2: '2', 3: '3', 4: '4', 5: '5' };
        const TONE_T93 = { 1: 'a', 2: 'b', 3: 'c', 4: 'd', 5: 'e' };

        const chars = parseZiDict(source_map.zi);
        let DPY = '', T93 = '';

        for (const { cn, codes, tone } of chars) {
            codes.forEach(sp => {
                DPY += `${cn}\t${sp}${TONE_DPY[tone]}\n`;
                const [r1, c1] = T93_EN_NUM[sp[0]] || [], [r2, c2] = T93_EN_NUM[sp[1]] || [];
                const t93 = r1 && r2 ? '' + r1 + r2 + ((c1 - 1) * 3 + c2) : '';
                T93 += `${cn}\t${t93}${TONE_T93[tone]}\n`;
            });
        }
        return { DPY, T93 };
    }
}

/**
 * 转换流水线配置：每个条目定义了一组 源文件→变形函数→目标文件。
 * @type {Array<{source: Record<string,string>, target: Record<string,any>, transform: Function}>}
 */
const files = [
    {
        // 万象原始字拼音
        source: {
            zi: 'dicts/wanxiang/zi.dict.yaml',
        },
        target: {
            DPY: {
                file: 'dicts/lookup/SOURCE_DPY.dict.yaml',
                name: 'SOURCE_DPY',
            },
            T93: {
                file: 'dicts/lookup/SOURCE_T93.dict.yaml',
                name: 'SOURCE_T93',
            },
        },
        transform: TRANSFORMER.wanxiang_source,
    },
    {  // 万象辅助码 => 辅助码字典
        source: {
            csv: 'downloads/wanxiang/aux_code.csv',
        },
        target: {
            DPY: {
                file: 'dicts/lookup/AUX_DPY.dict.yaml',
                name: 'AUX_DPY',
            },
            T93: {
                file: 'dicts/lookup/AUX_T93.dict.yaml',
                name: 'AUX_T93',
            }
        },
        transform: TRANSFORMER.wanxiang_auxcode,
    },
    {  // 万象辅助码注释 => 注释字典
        source: {
            csv: 'downloads/wanxiang/aux_code.csv',
        },
        target: {
            comment: {
                file: 'dicts/lookup/AUX_comment.dict.yaml',
                name: 'AUX_comment'
            },
        },
        transform: TRANSFORMER.wanxiang_auxcode_comment,
    },
    { // 万象pro
        source: {
            aux_csv: 'downloads/wanxiang/aux_code.csv',
            zi: 'dicts/wanxiang/zi.dict.yaml',
            jichu: 'dicts/wanxiang/jichu.dict.yaml',
            lianxiang: 'dicts/wanxiang/lianxiang.dict.yaml',
            cuoyin: 'dicts/wanxiang/cuoyin.dict.yaml',
            duoyin: 'dicts/wanxiang/duoyin.dict.yaml',
            shici: 'dicts/wanxiang/shici.dict.yaml',
            diming: 'dicts/wanxiang/diming.dict.yaml',
        },
        target: {
            zi: { file: 'dicts/wanxiang/zi.pro.dict.yaml', name: 'zi' },
            jichu: { file: 'dicts/wanxiang/jichu.pro.dict.yaml', name: 'jichu' },
            lianxiang: { file: 'dicts/wanxiang/lianxiang.pro.dict.yaml', name: 'lianxiang' },
            cuoyin: { file: 'dicts/wanxiang/cuoyin.pro.dict.yaml', name: 'cuoyin' },
            duoyin: { file: 'dicts/wanxiang/duoyin.pro.dict.yaml', name: 'duoyin' },
            shici: { file: 'dicts/wanxiang/shici.pro.dict.yaml', name: 'shici' },
            diming: { file: 'dicts/wanxiang/diming.pro.dict.yaml', name: 'diming' },
        },
        transform: TRANSFORMER.wanxiang_pro,
    },
    {
        // 雾凇混输
        source: {
            en_dict: 'downloads/ice/en.dict.yaml',
            en_ext_dict: 'downloads/ice/en_ext.dict.yaml',
            cn_en_txt: 'downloads/ice/cn_en_double_pinyin.txt',
        },
        target: {
            english: {
                file: 'dicts/ice/english.dict.yaml',
                name: 'english',
            },
        },
        transform: TRANSFORMER.ice_english_merge,
    },
    {   // 万象方案 => 万象模型参数
        source: {
            schema: 'downloads/wanxiang/wanxiang.schema.yaml',
        },
        target: {
            grammar: {
                file: 'imr_grammar.yaml',
                is_dict: false,
            },
        },
        transform: TRANSFORMER.grammar,
    }
]

/**
 * 主函数：按 files 配置逐条执行转换。
 * @returns {void}
 */
function work() {
    files.forEach(file => {
        const source = file.source;
        const target = file.target;
        const transform = file.transform;
        const source_map = {}
        Object.keys(source).forEach(source_key => {
            const source_file = path.join(__dirname, '..', source[source_key]);
            try {
                source_map[source_key] = fs.readFileSync(source_file, 'utf8');
            } catch (err) {
                console.error(`读取源文件失败: ${source_file}`);
                throw err;
            }
        })
        const target_map = transform(source_map)
        Object.keys(target_map).forEach(target_key => {
            const target_file = path.join(__dirname, '..', target[target_key].file);
            const dir = path.dirname(target_file);
            if (!fs.existsSync(dir)) { fs.mkdirSync(dir, { recursive: true }); }
            fs.writeFileSync(target_file, ((target[target_key].is_dict ?? true) ? [
                `# Rime dictionary`,
                `# encoding: utf-8`,
                `#`,
                ``,
                `---`,
                `name: ${target[target_key].name}`,
                `version: ${target[target_key].version ?? 'zzz'}`,
                `...`
            ].join('\n') : '') + '\n' + target_map[target_key], 'utf8');
            console.log('文件已成功写入', target_file)
        })
    })
}

module.exports = work;
if (require.main === module) {
    work();
}
