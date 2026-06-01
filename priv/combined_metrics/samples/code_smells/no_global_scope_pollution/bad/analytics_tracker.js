window.ANALYTICS_ENDPOINT = "/api/analytics";
window.ANALYTICS_API_KEY = process.env.ANALYTICS_API_KEY;
window.analyticsQueue = [];
window.analyticsSessionId = null;
window.analyticsFlushTimer = null;
const MAX_QUEUE_SIZE = 100;

function initAnalytics() {
  const stored = sessionStorage.getItem("session");
  window.analyticsSessionId = stored ?? crypto.randomUUID();
  sessionStorage.setItem("session", window.analyticsSessionId);
}

function trackEvent(eventName, properties = {}) {
  if (window.analyticsQueue.length >= MAX_QUEUE_SIZE) {
    flushAnalytics();
  }

  window.analyticsQueue.push({
    event: eventName,
    properties,
    sessionId: window.analyticsSessionId,
    timestamp: Date.now(),
  });

  scheduleAnalyticsFlush();
}

function identifyUser(userId, traits = {}) {
  trackEvent("$identify", { userId, ...traits });
}

function scheduleAnalyticsFlush() {
  if (window.analyticsFlushTimer) return;
  window.analyticsFlushTimer = setTimeout(() => {
    window.analyticsFlushTimer = null;
    flushAnalytics();
  }, 2000);
}

async function flushAnalytics() {
  if (window.analyticsQueue.length === 0) return;
  const events = window.analyticsQueue.splice(0, window.analyticsQueue.length);
  await fetch(window.ANALYTICS_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Api-Key": window.ANALYTICS_API_KEY,
    },
    body: JSON.stringify({ events }),
  });
}

window.trackEvent = trackEvent;
window.identifyUser = identifyUser;
window.flushAnalytics = flushAnalytics;
window.initAnalytics = initAnalytics;

initAnalytics();
