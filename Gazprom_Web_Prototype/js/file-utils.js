/**
 * Кроссбраузерные утилиты для файлов (Chrome, Firefox, Edge, Safari, Яндекс Браузер).
 */
const GazpromFileUtils = (() => {
  const IMAGE_EXT = new Set(['heic', 'heif', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tif', 'tiff']);

  function isCoarsePointer() {
    try {
      return window.matchMedia('(pointer: coarse)').matches;
    } catch {
      return false;
    }
  }

  function isImageFile(file) {
    if (!file) return false;
    const type = String(file.type || '').toLowerCase();
    if (type.startsWith('image/')) return true;
    const ext = String(file.name || '').split('.').pop()?.toLowerCase();
    return IMAGE_EXT.has(ext);
  }

  /** Надёжное скачивание Blob во всех браузерах (в т.ч. Firefox, Яндекс). */
  function downloadBlob(blob, fileName) {
    const blobUrl = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = blobUrl;
    a.download = fileName;
    a.rel = 'noopener';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(blobUrl), 10000);
  }

  function triggerFilePicker(input) {
    if (!input) return false;
    try {
      input.click();
      return true;
    } catch {
      return false;
    }
  }

  return {
    downloadBlob,
    isCoarsePointer,
    isImageFile,
    triggerFilePicker,
  };
})();
