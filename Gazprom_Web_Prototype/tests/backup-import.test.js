import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadBackup() {
  const ctx = {
    console,
    Date,
    Math,
    JSON,
    parseInt,
    String,
    Array,
    Error,
    Promise,
    AktUtils: null,
    GazpromStore: {
      get: async () => null,
      set: async () => {},
      hasData: () => false,
    },
  };
  vm.createContext(ctx);
  const expose = '\nif (typeof AktUtils !== "undefined") this.AktUtils = AktUtils;\nif (typeof GazpromBackup !== "undefined") this.GazpromBackup = GazpromBackup;\n';
  vm.runInContext(readFileSync(join(root, 'js/akt-utils.js'), 'utf8') + expose, ctx);
  vm.runInContext(readFileSync(join(root, 'js/backup-import.js'), 'utf8') + expose, ctx);
  return ctx;
}

describe('GazpromBackup', () => {
  let GazpromBackup;
  beforeAll(() => {
    GazpromBackup = loadBackup().GazpromBackup;
  });

  it('normalizeBackup requires akts array', () => {
    expect(() => GazpromBackup.normalizeBackup({})).toThrow(/актов/);
  });

  it('normalizeBackup preserves structure', () => {
    const raw = {
      version: '1.2',
      akts: [{ id: '1', number: '1', violations: [{ photo: ['abc123'] }] }],
      organizations: [],
      trash: [],
    };
    const out = GazpromBackup.normalizeBackup(raw);
    expect(out.akts).toHaveLength(1);
    expect(out.akts[0].violations[0].photo[0]).toBe('abc123');
    expect(out.version).toBe('1.2');
  });

  it('normalizeBackup v1.3 web-only fields with defaults', () => {
    const raw = {
      version: '1.3',
      akts: [{ id: '1', number: '1', violations: [] }],
    };
    const out = GazpromBackup.normalizeBackup(raw);
    expect(out.violationRegistry).toEqual([]);
    expect(out.descriptionTemplates).toEqual(['', '', '']);
    expect(out.wordTemplate).toBeNull();
    expect(out.wordTemplateName).toBeNull();
  });

  it('normalizeBackup v1.3 preserves registry templates and word template', () => {
    const raw = {
      version: '1.3',
      akts: [],
      violationRegistry: [{ id: 'v1', number: 1, title: 'Test' }],
      descriptionTemplates: ['A', 'B', 'C'],
      wordTemplate: 'dGVzdA==',
      wordTemplateName: 'akt.docx',
    };
    const out = GazpromBackup.normalizeBackup(raw);
    expect(out.violationRegistry).toHaveLength(1);
    expect(out.descriptionTemplates).toEqual(['A', 'B', 'C']);
    expect(out.wordTemplate).toBe('dGVzdA==');
    expect(out.wordTemplateName).toBe('akt.docx');
  });

  it('mergeBackups merges registry and description templates', () => {
    const current = {
      akts: [{ id: 'a1', number: '1' }],
      comissionPeople: [],
      organizations: [],
      objects: [],
      predstavitely: [],
      scheduleItems: [],
      violationEliminations: [],
      violationRegistry: [{ id: 'r1', title: 'Old' }],
      descriptionTemplates: ['keep', '', ''],
      wordTemplate: 'old==',
      wordTemplateName: 'old.docx',
    };
    const incoming = {
      akts: [{ id: 'a2', number: '2' }],
      comissionPeople: [],
      organizations: [],
      objects: [],
      predstavitely: [],
      trash: [],
      scheduleItems: [],
      violationEliminations: [],
      violationRegistry: [{ id: 'r2', title: 'New' }],
      descriptionTemplates: ['', 'incoming', ''],
      wordTemplate: 'new==',
      wordTemplateName: 'new.docx',
    };
    const merged = GazpromBackup.mergeBackups(current, incoming);
    expect(merged.akts).toHaveLength(2);
    expect(merged.violationRegistry).toHaveLength(2);
    expect(merged.descriptionTemplates[0]).toBe('keep');
    expect(merged.descriptionTemplates[1]).toBe('incoming');
    expect(merged.wordTemplate).toBe('new==');
    expect(merged.wordTemplateName).toBe('new.docx');
  });

  it('round-trip v1.3 export shape normalizes without loss', () => {
    const exportPayload = {
      version: '1.3',
      timestamp: new Date().toISOString(),
      akts: [{ id: '1', number: '10', violations: [] }],
      comissionPeople: [],
      organizations: [{ id: 'o1', title: 'Org' }],
      objects: [],
      predstavitely: [],
      trash: [],
      scheduleItems: [{ id: 's1', year: 2026 }],
      violationEliminations: [{ id: 'e1', aktNumber: '10' }],
      violationRegistry: [{ id: 'vr1', number: 1, title: 'Нарушение' }],
      descriptionTemplates: ['шаблон1', '', ''],
      wordTemplate: 'YmFzZTY0',
      wordTemplateName: 'template.docx',
    };
    const normalized = GazpromBackup.normalizeBackup(exportPayload);
    expect(normalized.organizations).toHaveLength(1);
    expect(normalized.scheduleItems).toHaveLength(1);
    expect(normalized.violationEliminations).toHaveLength(1);
    expect(normalized.violationRegistry[0].title).toBe('Нарушение');
    expect(normalized.wordTemplate).toBe('YmFzZTY0');
    expect(GazpromBackup.getStats(normalized).registry).toBe(1);
  });

  it('getStats counts photos', () => {
    const backup = {
      version: '1.0',
      timestamp: new Date().toISOString(),
      akts: [{ violations: [{ photo: ['a', 'b'] }] }],
      trash: [],
      comissionPeople: [],
      organizations: [],
      objects: [],
      predstavitely: [],
      scheduleItems: [],
      violationEliminations: [],
      violationRegistry: [],
    };
    expect(GazpromBackup.getStats(backup).photos).toBe(2);
  });

  it('parseJsonText strips UTF-8 BOM', () => {
    const raw = {
      version: '1.0',
      akts: [{ id: '1', number: '1', violations: [] }],
    };
    const out = GazpromBackup.parseJsonText('\uFEFF' + JSON.stringify(raw), 'test.json');
    expect(out.akts).toHaveLength(1);
    expect(out.sourceFileName).toBe('test.json');
  });

  it('ACCEPT_MOBILE includes .gazprombackup for iOS file picker', () => {
    expect(GazpromBackup.ACCEPT_MOBILE).toContain('.gazprombackup');
  });

  it('round-trip demo file parses', () => {
    const demo = JSON.parse(
      readFileSync(join(root, 'assets/sample-demo.gazprombackup'), 'utf8')
    );
    const normalized = GazpromBackup.normalizeBackup(demo);
    expect(normalized.akts.length).toBeGreaterThan(0);
    const stats = GazpromBackup.getStats(normalized);
    expect(stats.organizations).toBeGreaterThan(0);
  });
});
