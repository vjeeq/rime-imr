const path = require('path')
const PROJECT_ROOT = __dirname;
const updateFiles = require(path.join(PROJECT_ROOT, 'scripts', 'download'));
const transform = require(path.join(PROJECT_ROOT, 'scripts', 'transform'));

const args = process.argv.slice(2);
// 使用异步函数确保顺序执行
(async () => {
    try {
        if (args.length > 0) {
            switch (args[0]) {
                // node RunScripts.js wanxiang
                // 只更新万象文件(网络不好时，不走github)
                case 'wanxiang':
                    await updateFiles('wanxiang');
                    await transform();
                    break;
                case 'All':
                    await updateFiles('All');
                    await transform();
                    break;
            }
        } else {
            // 先执行update_files
            await updateFiles();
            // 再执行local_transform
            await transform();
        }
        console.log('所有任务执行完成!');
    } catch (error) {
        console.error('执行过程中出现错误:', error);
        process.exit(1);
    }
})();