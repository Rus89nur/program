import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import vm from 'node:vm';
import { describe, it, expect, beforeAll } from 'vitest';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function loadMlService() {
  const ctx = { console, Math, JSON, Float32Array, Array, String, Number };
  vm.createContext(ctx);
  const expose = '\nif (typeof MlImageService !== "undefined") this.MlImageService = MlImageService;\n';
  vm.runInContext(readFileSync(join(root, 'js/ml-image-service.js'), 'utf8') + expose, ctx);
  return ctx.MlImageService;
}

describe('MlImageService', () => {
  let MlImageService;

  beforeAll(() => {
    MlImageService = loadMlService();
  });

  it('distanceBetween is zero for identical vectors', () => {
    const v = new Float32Array([0.1, 0.5, 0.9]);
    expect(MlImageService.distanceBetween(v, v)).toBe(0);
  });

  it('distanceToConfidence decreases with distance', () => {
    const c1 = MlImageService.distanceToConfidence(0);
    const c2 = MlImageService.distanceToConfidence(10);
    expect(c1).toBeGreaterThan(c2);
  });

  it('averageFeatureVectors computes mean', () => {
    const a = new Float32Array([0, 1]);
    const b = new Float32Array([2, 3]);
    const avg = MlImageService.averageFeatureVectors([a, b]);
    expect(avg[0]).toBeCloseTo(1);
    expect(avg[1]).toBeCloseTo(2);
  });

  it('findMatchingViolationTitle matches exact and partial', () => {
    const registry = [
      { title: 'Необеспечение СИЗ', number: 12 },
      { title: 'Обучение по ПБ', number: 8 },
    ];
    expect(MlImageService.findMatchingViolationTitle('Необеспечение СИЗ', registry)).toBe(
      'Необеспечение СИЗ'
    );
    expect(
      MlImageService.findMatchingViolationTitle('Нарушение: необеспечение сиз', registry)
    ).toBe('Необеспечение СИЗ');
  });

  it('predictFromFeature returns equal split for same photo in base', async () => {
    const feature = new Float32Array(32 * 32).fill(0.5);
    const entries = [
      { id: '1', violationTitle: 'A', feature },
      { id: '2', violationTitle: 'B', feature },
    ];
    const registry = [
      { title: 'A', number: 1 },
      { title: 'B', number: 2 },
    ];
    const preds = await MlImageService.predictFromFeature(feature, entries, registry);
    expect(preds.length).toBe(2);
    expect(preds[0].confidence).toBeCloseTo(0.5, 1);
    expect(preds[1].confidence).toBeCloseTo(0.5, 1);
  });
});
