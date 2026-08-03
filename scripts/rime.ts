import fs from 'fs';
import yaml from './utils/js-yaml.js';

const LABELS = ['text', 'code', 'weight', 'stem'];
const DEFAULT_COLUMNS = ['text', 'code', 'weight'];

type DictColumn = 'text' | 'code' | 'weight' | 'stem';
type Entry<C extends DictColumn[]> = { [K in C[number]]: K extends 'weight' ? number : string };
type Dict<C extends DictColumn[] = ['text', 'code', 'weight']> = {
    name: string;
    columns: C;
    data: Entry<C>[];
};

function parseDict<C extends DictColumn[] = ['text', 'code', 'weight']>(content: string): Dict<C> {
    const lines = content.split('\n');
    const end = lines.findIndex(l => l.trim() === '...') + 1 || lines.length;
    const head_lines = lines.slice(0, end);
    const data_lines = lines.slice(end);

    const head = yaml.load(head_lines.join('\n')) || {};
    const columns: DictColumn[] = Array.isArray(head.columns) && head.columns.length
        ? head.columns.filter((c: DictColumn) => LABELS.includes(c))
        : DEFAULT_COLUMNS;
    const data = data_lines.map(line => line.trim())
        .filter(line =>!line.startsWith('#'))
        .map(line => line.split('\t'))
        .filter(array => array.length === columns.length)
        .map(array => {
            const entry: Record<string, string | number> = {};
            columns.forEach((label, i) => {
                entry[label] = label === 'weight' ? +array[i] || 0 : (array[i] || '').trim();
            });
            return entry;
        });
    return { name: head.name, columns, data } as Dict<C>;
}

function loadDictFile<C extends DictColumn[] = ['text', 'code', 'weight']>(filePath: string): Dict<C> {
    return parseDict<C>(fs.readFileSync(filePath, 'utf-8'));
}

export { parseDict, loadDictFile };
