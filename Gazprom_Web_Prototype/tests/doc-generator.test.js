import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadDocGenerator() {
  const ctx = { console, Date, Math, JSON, parseInt, String, Number, isNaN: Number.isNaN };
  vm.createContext(ctx);
  const expose = '\nif (typeof AktUtils !== "undefined") this.AktUtils = AktUtils;\n';
  vm.runInContext(readFileSync(join(root, 'js/akt-utils.js'), 'utf8') + expose, ctx);
  vm.runInContext(
    readFileSync(join(root, 'js/doc-generator.js'), 'utf8') +
      '\nif (typeof DocGenerator !== "undefined") this.DocGenerator = DocGenerator;\n',
    ctx
  );
  return ctx.DocGenerator;
}

describe('DocGenerator.buildTemplateData', () => {
  let DocGenerator;

  beforeAll(() => {
    DocGenerator = loadDocGenerator();
  });

  it('strips quotes from object name and formats signatures and attendees', () => {
    const data = DocGenerator.buildTemplateData({
      number: '1',
      date: '2026-06-01T12:00:00.000Z',
      objectsCheck: [{ title: '«Котельная №2»' }],
      organization: { title: 'ООО Тест' },
      comission: [{ fio: 'Иванов Иван Иванович', jobTitle: 'Председатель' }],
      predstavitelyComission: [
        { fio: 'Петров Пётр Петрович', jobTitle: 'Директор' },
        { fio: 'Сидоров Сидор Сидорович', jobTitle: 'Инженер' },
      ],
      violations: [],
    });

    expect(data.NameObject).toBe('Котельная №2');
    expect(data.Pedstav).toBe('директор - Петров Пётр Петрович, инженер - Сидоров Сидор Сидорович');
    expect(data.predVoiceLines).toEqual(['Председатель И.И. Иванов']);
    expect(data.pedstavVoiceLines).toEqual(['Директор П.П. Петров', 'Инженер С.С. Сидоров']);
  });

  it('preserves violation text with line breaks and spaces in template data', () => {
    const data = DocGenerator.buildTemplateData({
      number: '2',
      date: '2026-06-01T12:00:00.000Z',
      violations: [
        {
          title: '  Первая строка\nВторая строка  ',
          mesto: 'Лестница\n2 этаж',
          urlToPravilo: 'п. 1\nп. 2',
          formulaFromRules: 'Формула\nс переносом',
        },
      ],
    });

    expect(data.violations[0].ddescrVi).toBe('  Первая строка\nВторая строка  ');
    expect(data.violations[0].TitleViolatation).toBe('Лестница\n2 этаж');
    expect(data.violations[0].urlDoc).toBe('п. 1\nп. 2');
    expect(data.violations[0].formula).toBe('Формула\nс переносом');
  });

  it('converts line breaks to Word XML breaks for table cells', () => {
    expect(DocGenerator.toWordMultilineTextXml('строка 1\nстрока 2')).toBe(
      'строка 1</w:t><w:br/><w:t>строка 2'
    );
    expect(DocGenerator.toWordMultilineTextXml('одна строка')).toBe('одна строка');
    expect(DocGenerator.toWordMultilineTextXml('a<b\n&c')).toBe(
      'a&lt;b</w:t><w:br/><w:t>&amp;c'
    );
  });

  it('blank template includes marker guide groups', () => {
    const guide = DocGenerator.getMarkerGuide();
    expect(guide.length).toBeGreaterThan(3);
    expect(guide.some((g) => g.items.some((i) => i.key === 'Number'))).toBe(true);
    expect(guide.some((g) => g.items.some((i) => i.key === 'PoradNum'))).toBe(true);
    expect(guide[0].items[0]).toMatchObject({ key: expect.any(String), label: expect.any(String) });
  });
});
