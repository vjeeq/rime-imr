const fs = require('fs');
const path = require('path');
/** @type {string} */
const PROJECT_ROOT = path.join(__dirname, '..');

/** @type {Record<string, string>} 本地路径 → 远程下载地址 */
const pinyinFiles = {
    //// 拼音拆字
    'dicts/lookup/radical_pinyin.dict.yaml': 'https://cdn.jsdelivr.net/gh/mirtlecn/rime-radical-pinyin@master/radical_pinyin.dict.yaml',
    //// 笔画
    'dicts/lookup/stroke.dict.yaml': 'https://cdn.jsdelivr.net/gh/rime/rime-stroke@master/stroke.dict.yaml',
    //// 万象
    'dicts/wanxiang/zi.dict.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/dicts/zi.dict.yaml',
    'dicts/wanxiang/jichu.dict.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/dicts/jichu.dict.yaml',
    'dicts/wanxiang/lianxiang.dict.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/dicts/lianxiang.dict.yaml',
    'dicts/wanxiang/cuoyin.dict.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/dicts/cuoyin.dict.yaml',
    'dicts/wanxiang/duoyin.dict.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/dicts/duoyin.dict.yaml',
    'dicts/wanxiang/shici.dict.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/dicts/shici.dict.yaml',
    'dicts/wanxiang/diming.dict.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/dicts/diming.dict.yaml',
    //// 万象辅助码
    'downloads/wanxiang/aux_code.csv': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/aux_code.csv',
    //// 雾凇英文
    'downloads/ice/en.dict.yaml': 'https://cdn.jsdelivr.net/gh/iDvel/rime-ice@main/en_dicts/en.dict.yaml',
    'downloads/ice/en_ext.dict.yaml': 'https://cdn.jsdelivr.net/gh/iDvel/rime-ice@main/en_dicts/en_ext.dict.yaml',
    'downloads/ice/cn_en_double_pinyin.txt': 'https://cdn.jsdelivr.net/gh/iDvel/rime-ice@main/en_dicts/cn_en_double_pinyin.txt',
    //// 雾凇符号
    'symbols_caps_v.yaml': 'https://cdn.jsdelivr.net/gh/iDvel/rime-ice@main/symbols_caps_v.yaml',
    //// 雾凇emoji
    'opencc/emoji.txt': 'https://cdn.jsdelivr.net/gh/iDvel/rime-ice@main/opencc/emoji.txt',
    'opencc/others.txt': 'https://cdn.jsdelivr.net/gh/iDvel/rime-ice@main/opencc/others.txt',
    //// 万象模型
    'wanxiang-lts-zh-hans.gram': 'https://cnb.cool/amzxyz/rime-wanxiang/-/releases/download/model/wanxiang-lts-zh-hans.gram',
    //// 万象方案(同步模型参数用)
    'downloads/wanxiang/wanxiang.schema.yaml': 'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/wanxiang.schema.yaml',
    // rime-lua类型声明
    'lua/librime.lua': 'https://cdn.jsdelivr.net/gh/hchunhui/librime-lua@master/contrib/librime.lua',
};

/** @type {Record<string, string>} 本地路径 → 远程下载地址 */
const keytaoFiles = {
    'dicts/keytao/keytao.single.dict.yaml': 'https://cdn.jsdelivr.net/gh/xkinput/KeyTao@master/rime/keytao.single.dict.yaml',
    'dicts/keytao/keytao.phrase.dict.yaml': 'https://cdn.jsdelivr.net/gh/xkinput/KeyTao@master/rime/keytao.phrase.dict.yaml',
    'dicts/keytao/keytao.supplement.dict.yaml': 'https://cdn.jsdelivr.net/gh/xkinput/KeyTao@master/rime/keytao.supplement.dict.yaml',
    'dicts/keytao/keytao.css.dict.yaml': 'https://cdn.jsdelivr.net/gh/xkinput/KeyTao@master/rime/keytao.css.dict.yaml',
};

const allFiles = { ...pinyinFiles, ...keytaoFiles };

/**
 * 解析命令行参数 --mode
 * @returns {'all' | 'keytao' | 'pinyin'}
 */
function parseMode() {
    const idx = process.argv.indexOf('--mode');
    if (idx < 0) return 'all';
    const mode = process.argv[idx + 1];
    if (mode === 'keytao' || mode === 'pinyin') return mode;
    return 'all';
}

// 同步远程数据

/**
 * @type {(url: string, localPath: string) => Promise<{ok: boolean}>}
 */
const checkAndUpdateFile = require(path.join(PROJECT_ROOT, 'scripts', 'utils', 'fetch'));


/**
 * 主函数：批量同步远程文件。
 * @param {Record<string, string>} files
 * @returns {Promise<{totalCount: number, successCount: number, hasWarn: boolean}>}
 */
async function updateFiles(files) {
    const modeLabel = files === keytaoFiles ? '键道' : files === pinyinFiles ? '双拼' : '全部';
    const fileCount = Object.keys(files).length;
    console.log(`开始检查并同步文件... (模式: ${modeLabel})`);
    console.log(`共配置了 ${fileCount} 个文件\n`);

    let successCount = 0;
    let totalCount = 0;
    let hasWarn = false;

    // 遍历所有配置的文件
    for (const [filePath, remoteUrl] of Object.entries(files)) {
        totalCount++;
        try {
            const result = await checkAndUpdateFile(remoteUrl, filePath);
            if (!result.ok) hasWarn = true;
            successCount++;
        } catch (err) {
            console.error(`\n[严重错误] 文件 ${filePath} 下载失败，终止流程`);
            throw err;
        }
    }

    console.log(`\n====================`);
    console.log(`同步完成! 成功: ${successCount}/${totalCount} 个文件`);
    return { totalCount, successCount, hasWarn };
}

// 导出函数以便在其他脚本中使用
const downloadAll = () => updateFiles(allFiles);
downloadAll.pinyin = () => updateFiles(pinyinFiles);
downloadAll.keytao = () => updateFiles(keytaoFiles);
module.exports = downloadAll;

if (require.main === module) {
    const mode = parseMode();
    const files = mode === 'keytao' ? keytaoFiles
                : mode === 'pinyin' ? pinyinFiles
                : allFiles;
    updateFiles(files);
}
