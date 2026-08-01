import { Controller } from "@hotwired/stimulus"

const DAY_START_MINUTES = 6 * 60
const DAY_SPAN_MINUTES = 18 * 60
const SNAP_MINUTES = 15

export default class extends Controller {
  static targets = [
    "dialog", "eventPanel", "notePanel", "eventTab", "noteTab",
    "title", "date", "time", "start", "end", "endLabel", "duration",
    "allDay", "noteOccurred", "noteContent"
  ]

  connect() {
    this.durationMinutes = 60
    this.opener = null
    this.updateSchedule()
  }

  open(event) {
    event?.preventDefault()
    this.opener = event?.currentTarget || document.activeElement
    this.prefill(event?.currentTarget?.dataset || {})
    this.showType(event?.currentTarget?.dataset.quickCreateType || "event")
    this.dialogTarget.showModal()
    requestAnimationFrame(() => {
      const target = this.eventPanelTarget.hidden ? this.noteContentTarget : this.titleTarget
      target.focus()
    })
  }

  openMonth(event) {
    if (event.target.closest("a, button, input, textarea, select, [draggable='true']")) return
    event.preventDefault()
    this.opener = event.currentTarget
    this.prefill({ quickCreateDate: event.currentTarget.dataset.calendarDate, quickCreateTime: "09:00" })
    this.showType("event")
    this.dialogTarget.showModal()
    requestAnimationFrame(() => this.titleTarget.focus())
  }

  openWeek(event) {
    if (event.target.closest("a, button, input, textarea, select, [draggable='true']")) return
    event.preventDefault()
    const rect = event.currentTarget.getBoundingClientRect()
    const relative = Math.max(0, Math.min(rect.height, event.clientY - rect.top))
    const rawMinutes = DAY_START_MINUTES + (relative / rect.height) * DAY_SPAN_MINUTES
    const snapped = Math.max(DAY_START_MINUTES, Math.min(DAY_START_MINUTES + DAY_SPAN_MINUTES - SNAP_MINUTES, Math.round(rawMinutes / SNAP_MINUTES) * SNAP_MINUTES))
    const time = `${String(Math.floor(snapped / 60)).padStart(2, "0")}:${String(snapped % 60).padStart(2, "0")}`
    this.opener = event.currentTarget
    this.prefill({ quickCreateDate: event.currentTarget.dataset.calendarDay, quickCreateTime: time })
    this.showType("event")
    this.dialogTarget.showModal()
    requestAnimationFrame(() => this.titleTarget.focus())
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close(event)
  }

  restoreFocus() {
    this.opener?.focus?.({ preventScroll: true })
  }

  selectEvent(event) {
    event.preventDefault()
    this.showType("event")
    this.titleTarget.focus()
  }

  selectNote(event) {
    event.preventDefault()
    this.showType("note")
    this.noteContentTarget.focus()
  }

  chooseDuration(event) {
    event.preventDefault()
    this.durationMinutes = Number(event.currentTarget.dataset.durationMinutes) || 60
    this.durationTargets.forEach((button) => button.setAttribute("aria-pressed", String(button === event.currentTarget)))
    this.updateSchedule()
  }

  updateSchedule() {
    if (!this.hasDateTarget || !this.hasTimeTarget) return
    const date = this.dateTarget.value
    const time = this.timeTarget.value || "09:00"
    if (!date) return

    const start = new Date(`${date}T${time}:00`)
    const end = new Date(start.getTime() + this.durationMinutes * 60_000)
    const local = (value) => `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, "0")}-${String(value.getDate()).padStart(2, "0")}T${String(value.getHours()).padStart(2, "0")}:${String(value.getMinutes()).padStart(2, "0")}`

    if (this.allDayTarget.checked) {
      this.startTarget.value = `${date}T00:00`
      this.endTarget.value = `${date}T23:59`
      this.endLabelTarget.textContent = "весь день"
    } else {
      this.startTarget.value = local(start)
      this.endTarget.value = local(end)
      this.endLabelTarget.textContent = `${time} → ${String(end.getHours()).padStart(2, "0")}:${String(end.getMinutes()).padStart(2, "0")}`
    }
    this.noteOccurredTarget.value = `${date}T${time}`
  }

  prefill(data) {
    const date = data.quickCreateDate || this.dateTarget.value
    const time = data.quickCreateTime || this.timeTarget.value || "09:00"
    this.dateTarget.value = date
    this.timeTarget.value = time
    this.allDayTarget.checked = data.quickCreateAllDay === "true"
    this.updateSchedule()
  }

  showType(type) {
    const note = type === "note"
    this.eventPanelTarget.hidden = note
    this.notePanelTarget.hidden = !note
    this.eventTabTarget.setAttribute("aria-selected", String(!note))
    this.noteTabTarget.setAttribute("aria-selected", String(note))
  }
}
