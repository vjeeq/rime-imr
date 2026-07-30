const path = require('path')
/**
 * @type {() => Promise<{totalCount: number, successCount: number, skipCount: number, hasWarn: boolean}>}
 */
const updateFiles = require(path.join(__dirname, 'scripts', 'download'));
const supplement = require(path.join(__dirname, 'scripts', 'keytao_supplement'));
const extend = require(path.join(__dirname, 'scripts', 'keytao_extend'));

(async () => {
    try {
        await updateFiles.keytao();
        supplement();
        extend();
        console.log('\n✓ All done');
    } catch (error) {
        console.error('执行过程中出现错误:', error);
        process.exit(1);
    }
})();
