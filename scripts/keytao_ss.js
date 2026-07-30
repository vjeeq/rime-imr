const fs = require('fs');
const path = require('path');

const DEFAULT_FILE = path.join(__dirname, '..', 'dicts', 'keytao', 'keytao.supplement.dict.yaml');
const CONS = 'bcdefghjklmnpqrstwxyz';

function main() {
  const FILE = process.argv[2] || DEFAULT_FILE;
  const content = fs.readFileSync(FILE, 'utf-8');
  const lines = content.split('\n');

  let inBody = false;
  let changed = 0;

  const out = lines.map(line => {
    if (!inBody) {
      if (line.trim() === '...') inBody = true;
      return line;
    }
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return line;
    const parts = line.split('\t');
    if (parts.length < 3) return line;
    const text = parts[0].trim();
    const code = parts[1].trim();
    const weight = parseInt(parts[2].trim(), 10);
    if (
      code.length === 2 &&
      CONS.indexOf(code[0]) !== -1 &&
      CONS.indexOf(code[1]) !== -1 &&
      [...text].length == 2 &&
      weight < 1000
    ) {
      const indent = line.match(/^(\s*)/)[1];
      changed++;
      return indent + text + '\t' + code + '\t' + (weight * 10);
    }
    return line;
  });

  fs.writeFileSync(FILE, out.join('\n'), 'utf-8');
  console.log(`Changed ${changed} entries in ${FILE}`);
}

module.exports = main;

if (require.main === module) {
  main();
}
