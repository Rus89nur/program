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
  vm.runInContext(readFileSync(join(root, 'js/doc-generator.js'), 'utf8') + '\nthis.DocGenerator = DocGenerator;\n', ctx);
  return ctx.DocGenerator;
}

describe('TemplateBuilder / DocGenerator builder model', () => {
  let DocGenerator;

  beforeAll(() => {
    DocGenerator = loadDocGenerator();
  });

  it('exposes structure presets for akt and spravka', () => {
    const akt = DocGenerator.getBuilderStructurePresets('akt');
    const spravka = DocGenerator.getBuilderStructurePresets('spravka');
    expect(akt.length).toBe(4);
    expect(spravka.length).toBe(5);
    expect(akt[0].previewHtml).toContain('tb-preview-page');
    expect(spravka[4].id).toBe('spravka-full');
  });

  it('buildInitialBuilderModel includes expected markers for akt-violations', () => {
    const model = DocGenerator.buildInitialBuilderModel('akt', 'akt-violations');
    expect(model.templateType).toBe('akt');
    const xml = DocGenerator.buildDocumentXmlFromBuilderModel(model);
    expect(xml).toContain('PoradNum');
    expect(xml).toContain('DateReview');
    expect(xml).toContain('ddescrVi');
    expect(xml).not.toContain('&lt;w:document');
  });

  it('buildInitialBuilderModel spravka-full has all table markers', () => {
    const model = DocGenerator.buildInitialBuilderModel('spravka', 'spravka-full');
    const xml = DocGenerator.buildDocumentXmlFromBuilderModel(model);
    expect(xml).toContain('ObjTitle');
    expect(xml).toContain('OrgName');
    expect(xml).toContain('PoradNum');
    expect(DocGenerator.countMarkersInBuilderModel(model)).toBeGreaterThan(5);
  });

  it('markers are in single w:t runs without splitting', () => {
    const model = DocGenerator.buildInitialBuilderModel('akt', 'akt-text');
    const xml = DocGenerator.buildDocumentXmlFromBuilderModel(model);
    expect(xml).toMatch(/<w:t[^>]*>DateReview<\/w:t>/);
    expect(xml).toMatch(/<w:t[^>]*>Number<\/w:t>/);
  });

  it('applies paragraph alignment in XML', () => {
    const model = {
      templateType: 'akt',
      blocks: [
        DocGenerator.builderParagraph([DocGenerator.builderTextRun('Центр')], 'center'),
      ],
    };
    const xml = DocGenerator.buildDocumentXmlFromBuilderModel(model);
    expect(xml).toContain('<w:jc w:val="center"/>');
  });
});
