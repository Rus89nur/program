/**
 * Отладка импорта бэкапа (сессия 2c2db0). Логи: ingest + localStorage.
 */
const DebugAgent = (() => {
  const INGEST = 'http://127.0.0.1:7931/ingest/e73f326d-990a-4349-ab2b-115a1dec68c8';
  const SESSION = '2c2db0';
  const LS_KEY = 'agentDebugLog_2c2db0';
  let runId = 'pre-fix';

  function log(location, message, data, hypothesisId) {
    const entry = {
      sessionId: SESSION,
      runId,
      hypothesisId: hypothesisId || '',
      location,
      message,
      data: data || {},
      timestamp: Date.now(),
    };
    // #region agent log
    fetch(INGEST, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': SESSION },
      body: JSON.stringify(entry),
    }).catch(() => {});
    // #endregion
    try {
      const arr = JSON.parse(localStorage.getItem(LS_KEY) || '[]');
      arr.push(entry);
      while (arr.length > 50) arr.shift();
      localStorage.setItem(LS_KEY, JSON.stringify(arr));
    } catch {
      /* ignore */
    }
  }

  function getLogs() {
    try {
      return JSON.parse(localStorage.getItem(LS_KEY) || '[]');
    } catch {
      return [];
    }
  }

  async function copyLogsToClipboard() {
    const text = JSON.stringify(getLogs(), null, 0);
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
    return false;
  }

  function setRunId(id) {
    runId = id || 'pre-fix';
  }

  return { log, getLogs, copyLogsToClipboard, setRunId };
})();
