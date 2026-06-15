// [1]万象 [2]墨奇 [3]小鹤 [4]自然码 [5]虎码 [6]五笔 [7]汉心 [8]首右 [9]首右+
const AUX_INDEX = 2;
const AUX_CF_URLs = [
    ,
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/wx_chaifen.txt',
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/moqi_chaifen.txt',
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/flypy_chaifen.txt',
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/zrm_chaifen.txt',
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/tiger_chaifen.txt',
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/wubi_chaifen.txt',
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/shouyou_chaifen.txt',
    'https://cnb.cool/amzxyz/rime-wanxiang/-/git/raw/wanxiang/custom/shyplus_chaifen.txt',
]
 
module.exports = {
    AUX_INDEX,
    AUX_CF_URL: AUX_CF_URLs[AUX_INDEX],
}