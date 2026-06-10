import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadViolationSearch() {
  const ctx = { console };
  vm.createContext(ctx);
  const expose = '\nif (typeof ViolationSearch !== "undefined") this.ViolationSearch = ViolationSearch;\n';
  vm.runInContext(readFileSync(join(root, 'js/violation-search.js'), 'utf8') + expose, ctx);
  return ctx.ViolationSearch;
}

const sampleRegistry = [
  {
    id: '1',
    number: 42,
    title: 'Не проведён инструктаж по охране труда',
    subTitle: 'п. 4.1 СП 12-135-2003',
    description: 'Повторное нарушение на объекте',
    vid: 'Пожарная безопасность',
    formulaFromRules: 'Согласно п. 4.1',
  },
  {
    id: '2',
    number: 7,
    title: 'Отсутствуют средства пожаротушения',
    subTitle: 'ФЗ-123',
    description: '',
    vid: 'Пожароопасные работы',
    formulaFromRules: '',
  },
];

describe('ViolationSearch', () => {
  let VS;
  beforeAll(() => {
    VS = loadViolationSearch();
  });

  it('normalize: ё, пунктуация, лишние пробелы', () => {
    expect(VS.normalize('  Ёлка,  «тест»  ')).toBe('елка тест');
  });

  it('ищет по примечанию (description)', () => {
    const r = VS.filterRegistry(sampleRegistry, 'повторное');
    expect(r).toHaveLength(1);
    expect(r[0].id).toBe('1');
  });

  it('несколько слов — логика И', () => {
    const r = VS.filterRegistry(sampleRegistry, 'инструктаж охране');
    expect(r).toHaveLength(1);
    expect(r[0].id).toBe('1');

    expect(VS.filterRegistry(sampleRegistry, 'инструктаж пожаротушения')).toHaveLength(0);
  });

  it('ищет по номеру записи', () => {
    const r = VS.filterRegistry(sampleRegistry, '42');
    expect(r).toHaveLength(1);
    expect(r[0].id).toBe('1');
  });

  it('ищет по виду нарушения', () => {
    const r = VS.filterRegistry(sampleRegistry, 'пожароопасные');
    expect(r).toHaveLength(1);
    expect(r[0].id).toBe('2');
  });

  it('кавычки — точная фраза', () => {
    const r = VS.filterRegistry(sampleRegistry, '"средства пожаротушения"');
    expect(r).toHaveLength(1);
    expect(r[0].id).toBe('2');
  });

  it('vidFilter совместим с поиском', () => {
    const r = VS.filterRegistry(sampleRegistry, 'пожар', { vidFilter: 'Пожарная безопасность' });
    expect(r).toHaveLength(1);
    expect(r[0].id).toBe('1');
  });

  it('filterActViolations: место и ссылка на правило', () => {
    const violations = [
      {
        id: 'a',
        title: 'Нарушение А',
        mesto: 'Котельная №3',
        urlToPravilo: 'п. 2.3 ППБ',
        description: 'замечание инспектора',
      },
    ];
    expect(VS.filterActViolations(violations, 'котельная').map((v) => v.id)).toEqual(['a']);
    expect(VS.filterActViolations(violations, 'инспектора').map((v) => v.id)).toEqual(['a']);
    expect(VS.filterActViolations(violations, 'ппб').map((v) => v.id)).toEqual(['a']);
  });

  it('пустой запрос — все записи', () => {
    expect(VS.filterRegistry(sampleRegistry, '')).toHaveLength(2);
    expect(VS.filterRegistry(sampleRegistry, '   ')).toHaveLength(2);
  });
});
