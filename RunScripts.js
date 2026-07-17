const path = require('path')
/** @type {string} */
const PROJECT_ROOT = __dirname;
/**
 * @type {(type?: string) => Promise<{totalCount: number, successCount: number, skipCount: number, hasWarn: boolean}>}
 */
const updateFiles = require(path.join(PROJECT_ROOT, 'scripts', 'download'));
/** @type {() => void} */
const transform = require(path.join(PROJECT_ROOT, 'scripts', 'transform'));

const args = process.argv.slice(2);
(async () => {
    let dlResult = null;
    try {
        if (args.length > 0) {
            switch (args[0]) {
                case 'wanxiang':
                    dlResult = await updateFiles('wanxiang');
                    break;
                case 'All':
                    dlResult = await updateFiles('All');
                    break;
                default:
                    process.exit(1);
            }
        } else {
            dlResult = await updateFiles();
        }
        await transform();

        if (dlResult && dlResult.hasWarn) {
            console.log(`
░▒▓████████▓▒░▒▓███████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░  
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓██████▓▒░ ░▒▓███████▓▒░░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░  
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
`);
            process.exit(1);
        }
        console.log('\n✓ All done');
    } catch (error) {
        console.error('执行过程中出现错误:', error);
        process.exit(1);
    }
})();
