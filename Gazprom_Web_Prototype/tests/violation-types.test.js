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
      MAPPING_SEED_TYPES: ['Новый вид Smart Forms', 'Ещё один новый вид'],
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
    expect(catalog.violationTypes.length).toBe(5);
    expect(VT.getActiveTypes(catalog).length).toBe(3);
    expect(VT.getPendingTypes(catalog).length).toBe(2);
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

  it('pending-вид активируется при setMapping', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Старый', status: 'archived' },
        { id: 'p1', title: 'Новый', status: 'pending' },
      ],
      typeMappings: {},
    };
    VT.setMapping(catalog, 'a1', 'p1');
    expect(VT.findById(catalog, 'p1').status).toBe('active');
    expect(VT.getActiveTypes(catalog).some((t) => t.title === 'Новый')).toBe(true);
  });

  it('deleteType удаляет неиспользуемый вид', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Лишний уникальный вид', status: 'pending' },
      ],
      typeMappings: {},
    };
    VT.ensureCatalog(catalog);
    const before = catalog.violationTypes.length;
    const r = VT.deleteType(catalog, 'a1');
    expect(r.ok).toBe(true);
    expect(catalog.violationTypes).toHaveLength(before - 1);
  });

  it('deleteType не восстанавливает удалённый seed-вид', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'seed1', title: 'Новый вид Smart Forms', status: 'pending' },
      ],
      typeMappings: {},
      dismissedMappingSeeds: [],
    };
    VT.ensureCatalog(catalog);
    const r = VT.deleteType(catalog, 'seed1');
    expect(r.ok).toBe(true);
    VT.ensureCatalog(catalog);
    expect(VT.getPendingTypes(catalog).some((t) => t.title === 'Новый вид Smart Forms')).toBe(false);
    expect(catalog.dismissedMappingSeeds).toContain('Новый вид Smart Forms');
  });

  it('restoreType возвращает вид из архива в активные', () => {
    const catalog = {
      akts: [],
      violationTypes: [
        { id: 'a1', title: 'Старый', status: 'archived', replacedBy: 'a2' },
        { id: 'a2', title: 'Новый', status: 'active' },
      ],
      typeMappings: { a1: 'a2' },
    };
    const r = VT.restoreType(catalog, 'a1');
    expect(r.ok).toBe(true);
    expect(VT.findById(catalog, 'a1').status).toBe('active');
    expect(VT.getMappings(catalog).a1).toBeUndefined();
  });
});
