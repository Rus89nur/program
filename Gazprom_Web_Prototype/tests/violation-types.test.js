import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadModules() {
  const ctx = {
    console,
    AktUtils: {
      uuid: (() => {
        let n = 0;
        return () => `id-${++n}`;
      })(),
    },
    ViolationTemplates: {
      VIOLATION_TYPES: ['Пожарная безопасность', 'Пожароопасные работы', 'Электробезопасность'],
    },
  };
  vm.createContext(ctx);
  const expose = '\nthis.ViolationTypes = ViolationTypes;\n';
  vm.runInContext(readFileSync(join(root, 'js/violation-types.js'), 'utf8') + expose, ctx);
  return ctx.ViolationTypes;
}

describe('ViolationTypes', () => {
  let VT;

  beforeAll(() => {
    VT = loadModules();
  });

  it('ensureCatalog создаёт типы из шаблона', () => {
    const catalog = { akts: [] };
    VT.ensureCatalog(catalog);
    expect(catalog.violationTypes.length).toBe(3);
    expect(catalog.violationTypes.every((t) => t.status === 'active')).toBe(true);
  });

  it('resolveVid следует цепочке replacedBy', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Пожароопасные работы', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Пожарная безопасность', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    expect(VT.resolveVid(catalog, 'Пожароопасные работы')).toBe('Пожарная безопасность');
  });

  it('syncOrphanVids добавляет неизвестные виды из актов в архив', () => {
    const catalog = {
      akts: [{ violations: [{ vid: 'Старый вид из акта' }] }],
      violationTypes: [{ id: 'x', title: 'Пожарная безопасность', status: 'active' }],
      typeMappings: {},
    };
    VT.ensureCatalog(catalog);
    const archived = VT.getArchivedTypes(catalog);
    expect(archived.some((t) => t.title === 'Старый вид из акта')).toBe(true);
  });

  it('migrateStoredVids переписывает vid в актах', () => {
    const catalog = {
      akts: [{ violations: [{ vid: 'Пожароопасные работы' }] }],
      violationRegistry: [{ vid: 'Пожароопасные работы' }],
      violationTypes: [
        { id: 'a1', title: 'Пожароопасные работы', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Пожарная безопасность', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    const n = VT.migrateStoredVids(catalog);
    expect(n).toBe(2);
    expect(catalog.akts[0].violations[0].vid).toBe('Пожарная безопасность');
  });

  it('buildKindStats группирует по resolved vid', () => {
    const catalog = {
      akts: [
        { violations: [{ vid: 'Пожароопасные работы' }, { vid: 'Пожарная безопасность' }] },
      ],
      violationTypes: [
        { id: 'a1', title: 'Пожароопасные работы', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Пожарная безопасность', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    const stats = VT.buildKindStats(catalog, { resolve: true });
    expect(stats.get('Пожарная безопасность')).toBe(2);
  });
});
