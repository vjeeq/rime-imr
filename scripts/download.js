const fs = require('fs');
const path = require('path');
/** @type {string} */
const PROJECT_ROOT = path.join(__dirname, '..');

/** @type {Record<string, string>} 本地路径 → 远程下载地址 */
const files = {
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

// 同步远程数据

/**
 * @type {(url: string, localPath: string) => Promise<boolean|{ok: boolean, warn: boolean}>}
 */
const checkAndUpdateFile = require(path.join(PROJECT_ROOT, 'scripts', 'utils', 'fetch'));


/**
 * 主函数：批量同步远程文件。
 * @returns {Promise<{totalCount: number, successCount: number, hasWarn: boolean}>}
 */
// 主函数
async function updateFiles() {
    console.log('开始检查并同步文件...');
    console.log(`共配置了 ${Object.keys(files).length} 个文件\n`);

    let successCount = 0;
    let totalCount = 0;
    let hasWarn = false;

    // 遍历所有配置的文件
    for (const [filePath, remoteUrl] of Object.entries(files)) {
        totalCount++;
        try {
            const result = await checkAndUpdateFile(remoteUrl, filePath);
            if (result?.warn) hasWarn = true;
            if (result) successCount++;
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
module.exports = updateFiles;
if (require.main === module) {
    updateFiles();
}
