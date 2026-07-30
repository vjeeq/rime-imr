const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const DICT = path.join(ROOT, 'dicts', 'keytao', 'keytao.supplement.dict.yaml');

const cons = 'bcdefghjklmnpqrstwxyz';
const forms = 'avuio';

const content = fs.readFileSync(DICT, 'utf-8');
const lines = content.split('\n');

let headerEnd = 0;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].trim() === '...') { headerEnd = i + 1; break; }
}

const header = lines.slice(0, headerEnd).join('\n');
const body = lines.slice(headerEnd);

const seen1char = new Set();
let kept = 0;
let dropped = 0;

const outLines = [];

for (let i = 0; i < body.length; i++) {
  let line = body[i];
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) { outLines.push(line); continue; }
  const parts = line.split('\t');
  if (parts.length < 3) { outLines.push(line); continue; }
  const text = parts[0].trim();
  const code = parts[1].trim();
  const wordLen = [...text].length;

  let keep = false;

  if (code.length > 0 && forms.indexOf(code[0]) !== -1) {
    keep = true;
  }

  if (!keep && code.length === 1 && cons.indexOf(code) !== -1 && wordLen === 1) {
    if (!seen1char.has(code)) {
      seen1char.add(code);
      keep = true;
    }
  }

  if (!keep && code.length === 2 && cons.indexOf(code[0]) !== -1 && cons.indexOf(code[1]) !== -1 && wordLen >= 2) {
    keep = true;
    const weight = parseInt(parts[2].trim(), 10);
    if (weight < 1000) {
      const indent = line.match(/^(\s*)/)[1];
      line = indent + text + '\t' + code + '\t' + (weight * 10);
    }
  }

  if (keep) {
    outLines.push(line);
    kept++;
  } else {
    dropped++;
  }
}

fs.mkdirSync(path.dirname(DICT), { recursive: true });
fs.writeFileSync(DICT, header + '\n' + outLines.join('\n') + '\n', 'utf-8');

console.log(`Kept: ${kept}, Dropped: ${dropped}`);
console.log(`Written: ${DICT}`);
