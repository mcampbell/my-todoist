# Recurrence ending - grill

Date: 2026-10-22. Design: `specs/recurrence-ending-design.md`.

Q: Does a skip use up one of the N times in "ending after N times"?
A: No. Only a completion lowers the count. (User call.)

Q: Can one task carry both "ending on" and "ending after"?
A: No. Both on one title is a 422. One limit per task. (User call.)

Q: How do you change or remove the limit after create?
A: Two edit-form fields: "Ends on" (date + optional time) and "Times left"
(number). Clear a field to remove the limit. (User call.)

Q: Which words follow the number?
A: `time(s)`, `occurrence(s)`, and the misspelling `occurrance(s)` (the
user's own spelling in the request). (Own decision.)

Q: Where does the limit live?
A: On the task: two nullable columns. Not in the `recurrence` string, so
`Recurrence` stays pure and its parser does not change. (Own decision.)

Q: Is an end date inclusive?
A: Yes. A date with no time ends at the end of that day (app zone). A time
makes it exact, for sub-day recurrences. (Own decision.)

Q: Does a skip past the end date end the task?
A: Yes. A skip whose next occurrence lands after `recurrence_ends_at`
destroys the task with no completion log. Only the count rule ignores
skips. (Own decision.)

Q: What happens when the recurrence is cleared on edit?
A: The limit clears too: a limit without a recurrence means nothing.
(Own decision.)
