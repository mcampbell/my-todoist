// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "notifications"

document.addEventListener("keydown", (event) => {
  if (event.key !== "q") return
  if (event.ctrlKey || event.metaKey || event.altKey) return

  const tag = event.target.tagName
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return
  if (event.target.isContentEditable) return

  event.preventDefault()
  Turbo.visit("/tasks/new")
})
