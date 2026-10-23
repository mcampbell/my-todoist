---
type: Feature
title: Clickable URLs
description: Task rows turn http(s) URLs in the title and the notes preview into links that open in a new tab.
tags: [ui, tasks, links]
generated:
  by: agent:claude-code
  at: 2026-10-23T00:00:00Z
sources:
  - resource: "../../app/helpers/tasks_helper.rb"
    title: "app/helpers/tasks_helper.rb"
  - resource: "../../app/views/tasks/_task.html.erb"
    title: "app/views/tasks/_task.html.erb"
---

# Overview

`TasksHelper#linkify` splits text on `URL_SPLIT` and renders each URL as a
link with `target="_blank"` and `rel="noopener noreferrer"`. A block renders
the text between URLs.

# Where it applies

| Surface | Behaviour |
|---|---|
| Task row title (`_task.html.erb`) | URL parts open the URL. The text parts stay links to Edit (`a.task-title`), so no link nests in another. A title that is only a URL has no Edit link in the title; use the Edit button. |
| Task row notes preview | URLs in the first line of the notes become links. |

The completed list, the completed-task details page, and the
complete-with-notes heading do not link URLs. The user chose task rows only.

# Rules

* Only `http://` and `https://`, in any case. Other schemes (`javascript:`,
  `ftp:`) stay plain text.
* The URL must start at a word boundary: `xhttps://...` does not link.
* The last character excludes sentence punctuation (`. , ; : ! ? ) ] '`), so
  "see <https://x.example>." links `https://x.example`. A URL that really ends
  in `)` loses that character.
* `link_to` escapes the link text and the href. `<`, `>`, and `"` end a URL.
