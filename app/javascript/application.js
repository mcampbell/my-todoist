// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "notifications"

// Reload the page at the server's next midnight so date-based views (Today,
// Overdue, Upcoming) roll over without a manual refresh. The layout renders
// the delay server-side (app zone), so this reader stays logic-free. Runs once
// per full load; the reload re-arms it, and Turbo navigations keep the timer.
// ponytail: sleeping past midnight just fires late on wake, which still lands
// on the correct day after the reload — fine for a local single-user app.
const secondsUntilMidnight = document.querySelector('meta[name="seconds-until-midnight"]')
if (secondsUntilMidnight) {
  setTimeout(() => location.reload(), Number(secondsUntilMidnight.content) * 1000)
}

document.addEventListener("keydown", (event) => {
  if (event.key !== "q") return
  if (event.ctrlKey || event.metaKey || event.altKey) return

  const tag = event.target.tagName
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return
  if (event.target.isContentEditable) return

  event.preventDefault()
  Turbo.visit("/tasks/new")
})

document.addEventListener("keydown", (event) => {
  if (event.key !== "/") return
  if (event.ctrlKey || event.metaKey || event.altKey) return

  const tag = event.target.tagName
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return
  if (event.target.isContentEditable) return

  event.preventDefault()
  Turbo.visit("/tasks/search")
})

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return
  if (![ "/tasks/new", "/tasks/search" ].includes(window.location.pathname)) return

  const cancelLink = document.getElementById("cancel-link")
  if (!cancelLink) return

  event.preventDefault()
  Turbo.visit(cancelLink.href)
})
