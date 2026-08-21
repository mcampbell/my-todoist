// Client-side due-toast poller (slice 6). Polls GET /tasks/due_since.json and
// toasts timed tasks that crossed their due_at since the last poll. No job
// stack: the server only answers a query; dedup is this per-session anchor.

let anchor = Date.now(); // page-load time; tasks already overdue never toast
const INTERVAL = 30_000;
let started = false; // Turbo cache restores must not double-start the interval
let inFlight = false; // serializes polls: no overlapping requests
let container = null;
let wasHidden = document.hidden; // visibility edge latch (hidden -> visible)

function ensureContainer() {
  container = document.getElementById("toast-container");
  if (!container) {
    container = document.createElement("div");
    container.id = "toast-container";
    document.body.appendChild(container);
  }
  return container;
}

// Advance the anchor to server time on every successful poll, so client/server
// clock skew cannot miss or duplicate a task. No monotonic guard: inFlight
// already serializes polls in this tab, and a one-way guard would pin the
// anchor above the server clock whenever the client runs ahead, silently
// disabling every toast.
async function poll({ silent = false } = {}) {
  if (inFlight) return; // a resume silent poll never overlaps a live poll
  inFlight = true;
  ensureContainer();
  try {
    const url = "/tasks/due_since.json?since=" +
      encodeURIComponent(new Date(anchor).toISOString());
    const response = await fetch(url);
    if (!response.ok) return; // leave the anchor: never widen the gap on error
    const payload = await response.json();
    if (!silent) {
      for (const task of payload.tasks) {
        try {
          toast(task);
        } catch (error) {
          console.error("toast render failed:", error);
        }
      }
    }
    anchor = Date.parse(payload.now);
  } catch (error) {
    console.error("due-since poll failed:", error);
  } finally {
    inFlight = false;
  }
}

// Short beep via Web Audio API — no asset file needed. Browsers may block
// AudioContext before any user gesture on the page; that's fine, the toast
// still renders silently rather than erroring.
function beep() {
  try {
    const ctx = new AudioContext();
    const oscillator = ctx.createOscillator();
    const gain = ctx.createGain();
    oscillator.frequency.value = 880;
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2);
    oscillator.connect(gain);
    gain.connect(ctx.destination);
    oscillator.start();
    oscillator.stop(ctx.currentTime + 0.2);
    oscillator.onended = () => ctx.close();
  } catch (error) {
    console.error("beep failed:", error);
  }
}

// Fire-and-forget: an OS-level toast is a nice-to-have on top of the
// in-page one, never worth failing or retrying over.
function notifyOs(task) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
  fetch("/os_notification", {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
    body: JSON.stringify({ title: "Task due", message: task.title }),
  }).catch((error) => console.error("os notification failed:", error));
}

function toast(task) {
  ensureContainer();
  beep();
  notifyOs(task);
  const notification = document.createElement("div");
  notification.className = "notification is-info";
  notification.appendChild(document.createTextNode(task.title));

  const close = document.createElement("button");
  close.className = "delete";
  close.setAttribute("aria-label", "Dismiss");
  close.addEventListener("click", (event) => {
    event.stopPropagation(); // do not bubble into the navigation listener
    notification.remove();
  });
  notification.appendChild(close);

  // Navigate on the wrapper click: an <a> body would navigate even when the
  // close button is clicked (stopPropagation cannot cancel its default).
  notification.addEventListener("click", () => {
    Turbo.visit("/tasks/" + task.id + "/edit");
  });

  container.appendChild(notification);
  setTimeout(() => notification.remove(), 8000);
}

function onVisibilityChange() {
  // Resume from a hidden period: one silent poll advances the anchor to
  // resume-time so the hidden gap never dumps a toast burst.
  if (wasHidden && !document.hidden) poll({ silent: true });
  wasHidden = document.hidden;
}

function start() {
  if (started) return;
  started = true;
  document.addEventListener("visibilitychange", onVisibilityChange);
  setInterval(() => poll(), INTERVAL);
  poll(); // first check shortly after load, then every INTERVAL
}

document.addEventListener("DOMContentLoaded", start);
document.addEventListener("turbo:load", start);