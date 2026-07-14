const fs = require('fs');
const path = require('path');
const PROJECT_ROOT = path.join(__dirname, '..');
const YAML_JS = require(path.join(PROJECT_ROOT, 'scripts', 'utils', 'js-yaml.min'));
// [1]万象 [2]墨奇 [3]小鹤 [4]自然码 [5]虎码 [6]五笔 [7]汉心 [8]首右 [9]首右+
const AUX_INDEX = require(path.join(PROJECT_ROOT, 'scripts', 'aux_code')).AUX_INDEX;
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
const TRANSFORMER = {
    wanxiang_auxcode({ txt: source_context }) {
        return source_context.split('\n')
            .map(line => line.trim())
            .filter(line => line)
            .filter(line => line.charAt(0) != '#')
            .map(line => line.split('\t', 2))
            .filter(arr => arr.length === 2)
            .map(([cn, code_str]) => [cn, code_str.split(';')])
            .filter(([cn, code_arr]) => code_arr.length >= AUX_INDEX + 1)
            .map(([cn, code_arr]) => [cn, code_arr[AUX_INDEX]])
            // code包含','
            .filter(([cn, code]) => code)
            .flatMap(([cn, code]) => code.split(',').map(code => [cn, code]))
            .filter(([cn, code]) => code)
            .map(([cn, code]) => {
                if (code.length >= 2) {
                    const en1 = code.charAt(0);
                    const en2 = code.charAt(1);
                    const p1 = T93_EN_NUM[en1], p2 = T93_EN_NUM[en2];
                    if (!p1 || !p2) return [cn, code, undefined];
                    const number1 = p1[0];
                    const number2 = p2[0];
                    const number3 = (p1[1] - 1) * 3 + p2[1];
                    return [cn, code, [`${number1}${number2}${number3}`, `${number1}${number2}0`]]
                }
                return [cn, code, undefined]
            })
            .reduce((result, [cn, DPY, T93]) => {
                result.DPY += `${cn}\t${DPY}\n`;
                if (T93) {
                    result.T93 += `${cn}\t${T93[0]}\n${cn}\t${T93[1]}\n`;
                }
                return result;
            }, { DPY: '', T93: '' })
    },
    wanxiang_auxcode_comment({ txt: source_context }) {
        return source_context.split('\n')
            .map(line => line.trim())
            .filter(line => line)
            .filter(line => line.charAt(0) != '#')
            .map(line => line.split('\t', 2))
            .filter(arr => arr.length === 2)
            .flatMap(([cn, comments]) => comments.replaceAll(' ', '').split('｜').map(comment => [cn, comment]))
            .filter(([cn, comment]) => comment)
            .reduce((result, [cn, comment]) => {
                result.comment += `${cn}\t${comment}\n`
                return result
            }, { comment: '' })
    },
    wanxiang_pro(source_map) {
        const aux_map = source_map.aux_txt.split('\n')
            .map(line => line.trim())
            .filter(line => line)
            .filter(line => line.charAt(0) != '#')
            .map(line => line.split('\t', 2))
            .filter(arr => arr.length === 2)
            .map(([cn, en_str]) => [cn, en_str.split(';')])
            .filter(([_, en_arr]) => en_arr.length >= AUX_INDEX + 1)
            .map(([cn, en_arr]) => [cn, en_arr[AUX_INDEX]])
            .filter(([cn, code]) => code)
            .reduce((aux_map, [cn, code]) => {
                aux_map[cn] = code;
                return aux_map;
            }, {})
        return Object.keys(source_map).filter(key => key != 'aux_txt')
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
    wanxiang_source(source_map) {
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
        const TONE_RE = /ā|á|ǎ|à|ē|é|ě|è|ī|í|ǐ|ì|ō|ó|ǒ|ò|ū|ú|ǔ|ù|ǖ|ǘ|ǚ|ǜ|ń|ň|ǹ|ḿ|m̀/;
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
        const toNaturalCode = sp => XFORM.reduce((s, [p, r]) => s.replace(p, r), sp).toLowerCase();
        const TONE_DPY = { 1: '1', 2: '2', 3: '3', 4: '4', 5: '5' };
        const TONE_T93 = { 1: 'a', 2: 'b', 3: 'c', 4: 'd', 5: 'e' };

        const lines = source_map.zi.split('\n');
        let DPY = '', T93 = '';

        for (const line of lines) {
            const parts = line.trim().split('\t');
            if (parts.length < 2 || parts[0].startsWith('#')) {
                continue;
            }
            const cn = parts[0];
            let pinyin = parts[1];

            // 提取声调
            let tone = 5;
            const tm = pinyin.match(TONE_RE);
            if (tm) {
                const [b, t] = TONE_TABLE[tm[0]];
                tone = t;
                pinyin = pinyin.replace(tm[0], b);
            }

            pinyin = pinyin.replace(/^ng$/, 'eng').replace(/^n$/, 'en').replace(/^m$/, 'me');

            // 全拼 → 自然码 (algebra)
            const d1 = /^([jqxy])u$/.exec(pinyin);
            const d2 = /^([aoe])([ioun])$/.exec(pinyin);
            const codes = [...new Set(
                [pinyin, d1 && d1[1] + 'v', d2 && d2[1] + d2[1] + d2[2]].filter(Boolean).map(toNaturalCode)
            )];

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
            txt: 'downloads/wanxiang/aux_code.txt',
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
            txt: 'downloads/wanxiang/aux_chaifen.txt',
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
            aux_txt: 'downloads/wanxiang/aux_code.txt',
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

// 读取ZRM_wanxiang.dict.yaml文件并处理

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
