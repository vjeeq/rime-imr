const fs = require('fs');
const path = require('path');
const PROJECT_ROOT = path.join(__dirname, '..');
const YAML = require(path.join(PROJECT_ROOT, 'scripts', 'js-yaml.min'))
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
    wanxiang_aux_code({ txt: source_context }) {
        return source_context.split('\n')
            .map(line => line.trim())
            .filter(line => line)
            .filter(line => line.charAt(0) != '#')
            .map(line => line.split('\t', 2))
            .filter(arr => arr.length === 2)
            .map(([cn, code_str]) => [cn, code_str.split(';')])
            .filter(([cn, code_arr]) => code_arr.length >= 5)
            // [4] 是自然码
            .map(([cn, code_arr]) => [cn, code_arr[4]])
            // code包含','
            .filter(([cn, code]) => code)
            .flatMap(([cn, code]) => code.split(',').map(code => [cn, code]))
            .filter(([cn, code]) => code)
            .map(([cn, code]) => {
                if (code.length >= 2) {
                    const en1 = code.charAt(0);
                    const en2 = code.charAt(1);
                    const number1 = T93_EN_NUM[en1][0];
                    const number2 = T93_EN_NUM[en2][0];
                    const number3 = (T93_EN_NUM[en1][1] - 1) * 3 + (T93_EN_NUM[en2][1]);
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
    wanxiang_aux_code_comment({ txt: source_context }) {
        return source_context.split('\n')
            .map(line => line.trim())
            .filter(line => line)
            .filter(line => line.charAt(0) != '#')
            .map(line => line.split('\t', 2))
            .filter(arr => arr.length === 2)
            .flatMap(([cn, comments]) => comments.split('｜').map(comment => [cn, comment]))
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
            .filter(([_, en_arr]) => en_arr.length >= 5)
            .map(([cn, en_arr]) => [cn, en_arr[4]])
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
                while ((shift = source_lines.shift()) != '...' && shift != undefined);
                return {
                    key, context: source_lines
                        .map(line => line.trim())
                        .filter(line => line)
                        .filter(line => line.charAt(0) != '#')
                        .map(line => line.split('\t', 3))
                        .map(([cn, en, other]) => [cn.split(''), en.split(' '), other])
                        .map(([cn_arr, en_arr, other]) => [cn_arr.join(''), en_arr.map((en, index) => en_arr[index] + ';' + aux_map[cn_arr[index]]), other])
                        .reduce((context, [cn, en, other]) => {
                            context += `${cn}\t${en}`;
                            context += other ? `\t${other}` : '';
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
        const source_json = YAML.load(source)
        const target_json = {}
        target_json.grammar = source_json.grammar
        target_json['translator/contextual_suggestions'] = false
        target_json['translator/max_homophones'] = source_json.translator.max_homophones
        target_json['translator/max_homographs'] = source_json.translator.max_homographs
        const target = YAML.dump(target_json)
        return { grammar: target }
    }
}
const files = [
    {  // 万象辅助码 => 辅助码字典
        source: {
            txt: 'downloads/wanxiang/aux_code.txt',
        },
        target: {
            DPY: {
                file: 'dicts/lookup/AUX-wanxiang-ZRM_DPY.dict.yaml',
                name: 'AUX-wanxiang-ZRM_DPY',
            },
            T93: {
                file: 'dicts/lookup/AUX-wanxiang-ZRM_T93.dict.yaml',
                name: 'AUX-wanxiang-ZRM_T93',
            }
        },
        transform: TRANSFORMER.wanxiang_aux_code,
    },
    {  // 万象辅助码注释 => 注释字典
        source: {
            txt: 'downloads/wanxiang/zrm_chaifen.txt',
        },
        target: {
            comment: {
                file: 'dicts/lookup/AUX-wanxiang-ZRM_comment.dict.yaml',
                name: 'AUX-wanxiang-ZRM_comment'
            },
        },
        transform: TRANSFORMER.wanxiang_aux_code_comment,
    },
    /** 
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
    */
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
            source_map[source_key] = fs.readFileSync(source_file, 'utf8');
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
        //     const source_lineses = source_file.map(file => {
        //         const context = fs.readFileSync(file, 'utf8');
        //         return context.split('\n');
        //     })
        //     const target_lines = transform(source_lineses)
        //     // 写入新文件
    })
}

module.exports = work;
if (require.main === module) {
    work();
}
