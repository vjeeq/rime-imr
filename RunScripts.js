const path = require('path')
/**
 * @type {() => Promise<{totalCount: number, successCount: number, skipCount: number, hasWarn: boolean}>}
 */
const updateFiles = require(path.join(__dirname, 'scripts', 'download'));
/** @type {() => void} */
const transform = require(path.join(__dirname, 'scripts', 'transform'));

(async () => {
    try {
        await updateFiles();
        await transform();
        console.log('\n✓ All done');
    } catch (error) {
        console.error('执行过程中出现错误:', error);
        process.exit(1);
    }
})();
