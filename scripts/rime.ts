import fs from 'fs';
import yaml from './utils/js-yaml.js';

const LABELS = ['text', 'code', 'weight', 'stem'];
const DEFAULT_COLUMNS = ['text', 'code', 'weight'];

type DictColumn = 'text' | 'code' | 'weight' | 'stem';
type Entry<C extends DictColumn[]> = { [K in C[number]]: K extends 'weight' ? number : string } & { _line: number };
type Dict<C extends DictColumn[] = ['text', 'code', 'weight']> = {
    name: string;
    columns: C;
    header: string;
    data: Entry<C>[];
};

function parseDict<C extends DictColumn[] = ['text', 'code', 'weight']>(content: string): Dict<C> {
    content = content.replace(/^\uFEFF/, '');
    const lines: string[] = content.split('\n');
    const end: number = lines.findIndex(l => l.trim() === '...') + 1 || lines.length;
    const head_lines: string[] = lines.slice(0, end);
    const data_lines: string[] = lines.slice(end);

    const head = yaml.load(head_lines.join('\n')) || {};
    const columns: DictColumn[] = Array.isArray(head.columns) && head.columns.length
        ? head.columns.filter((c: DictColumn) => LABELS.includes(c))
        : DEFAULT_COLUMNS;
    const data: Entry<C>[] = data_lines.map((line, index) => [index, line.trim()] as const)
        .filter(([, line]) => !line.startsWith('#'))
        .map(([index, line]) => [index, line.split('\t')] as const)
        .filter(([, array]) => array.length === columns.length)
        .map(([index, array]) => {
            const entry: Record<string, string | number> = { _line: end + index + 1 };
            columns.forEach((label, i) => {
                entry[label] = label === 'weight' ? +array[i] || 0 : (array[i] || '').trim();
            });
            return entry as Entry<C>;
        });
    return { name: head.name, columns, header: head_lines.join('\n'), data } as Dict<C>;
}

function loadDictFile<C extends DictColumn[] = ['text', 'code', 'weight']>(filePath: string): Dict<C> {
    return parseDict<C>(fs.readFileSync(filePath, 'utf-8'));
}

export { parseDict, loadDictFile, type Dict };
