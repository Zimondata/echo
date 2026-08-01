// Import and register controllers from the importmap.
import { application } from "controllers/application"
import { Controller } from "@hotwired/stimulus"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

const DAY_START_MINUTES = 6 * 60
const DAY_SPAN_MINUTES = 18 * 60
const SNAP_MINUTES = 15

class PlannerDragController extends Controller {
  static targets = ["day", "status"]
  static values = { timezone: String, view: String }

  connect() {
    this.dragged = null
    this.dragEndedAt = 0
  }

  start(event) {
    if (!this.desktopEnabled()) {
      event.preventDefault()
      return
    }

    const source = event.currentTarget
    if (source.dataset.plannerDragKind === "time-block" && source.dataset.plannerDragLocked === "true") {
      event.preventDefault()
      return
    }

    this.dragged = this.payloadFrom(source)
    if (!this.dragged) {
      event.preventDefault()
      return
    }

    source.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", source.textContent.trim())
    this.announce(this.dragged.kind === "task" ? "Выбери время в календаре" : "Выбери новое время")
  }

  finish(event) {
    event.currentTarget.classList.remove("is-dragging")
    this.clearDropState()
    this.dragEndedAt = Date.now()
    this.dragged = null
  }

  guardClick(event) {
    if (Date.now() - this.dragEndedAt < 300) event.preventDefault()
  }

  over(event) {
    const payload = this.currentPayload(event)
    if (!payload || !this.desktopEnabled()) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    const slot = this.slotFor(event.currentTarget, event.clientY)
    this.clearDropState(event.currentTarget)
    event.currentTarget.classList.add("is-planner-drop-target")
    event.currentTarget.style.setProperty("--planner-drop-y", `${slot.offsetPercent}%`)
    event.currentTarget.dataset.plannerDropTime = slot.time
  }

  leave(event) {
    if (event.currentTarget.contains(event.relatedTarget)) return
    this.resetDay(event.currentTarget)
  }

  drop(event) {
    const payload = this.currentPayload(event)
    if (!payload || !this.desktopEnabled()) return

    event.preventDefault()
    const day = event.currentTarget
    const slot = this.slotFor(day, event.clientY)
    this.resetDay(day)
    this.submit(payload, day.dataset.calendarDay, slot.time)
  }

  monthOver(event) {
    const payload = this.currentPayload(event)
    if (!payload || !this.desktopEnabled()) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.clearDropState(event.currentTarget)
    event.currentTarget.classList.add("is-month-drop-target")
  }

  monthDrop(event) {
    const payload = this.currentPayload(event)
    if (!payload || !this.desktopEnabled()) return

    event.preventDefault()
    const day = event.currentTarget
    this.resetDay(day)
    this.submit(payload, day.dataset.calendarDate, payload.localTime || "09:00")
  }

  payloadFrom(source) {
    const kind = source.dataset.plannerDragKind
    const common = {
      kind,
      taskId: source.dataset.plannerDragTaskId,
      taskLockVersion: source.dataset.plannerDragTaskLockVersion,
      duration: source.dataset.plannerDragDuration,
      localTime: source.dataset.plannerDragLocalTime
    }

    if (kind === "task") {
      return { ...common, url: source.dataset.plannerDragCreateUrl, method: "post", locked: "0" }
    }

    if (kind === "time-block") {
      return {
        ...common,
        url: source.dataset.plannerDragUpdateUrl,
        method: "patch",
        timeBlockId: source.dataset.plannerDragTimeBlockId,
        blockLockVersion: source.dataset.plannerDragBlockLockVersion,
        locked: source.dataset.plannerDragLocked === "true" ? "1" : "0"
      }
    }

    if (kind === "calendar-event") {
      return {
        ...common,
        url: source.dataset.plannerDragUpdateUrl,
        method: "patch",
        eventId: source.dataset.plannerDragEventId,
        eventLockVersion: source.dataset.plannerDragEventLockVersion
      }
    }

    return null
  }

  currentPayload(_event) {
    return this.dragged
  }

  slotFor(day, clientY) {
    const rect = day.getBoundingClientRect()
    const relative = Math.max(0, Math.min(rect.height, clientY - rect.top))
    const rawMinutes = DAY_START_MINUTES + (relative / rect.height) * DAY_SPAN_MINUTES
    const snapped = Math.max(DAY_START_MINUTES, Math.min(DAY_START_MINUTES + DAY_SPAN_MINUTES - SNAP_MINUTES, Math.round(rawMinutes / SNAP_MINUTES) * SNAP_MINUTES))
    const hour = Math.floor(snapped / 60)
    const minute = snapped % 60

    return {
      time: `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`,
      offsetPercent: ((snapped - DAY_START_MINUTES) / DAY_SPAN_MINUTES) * 100
    }
  }

  submit(payload, date, time) {
    if (!date || !time || !payload.url) {
      this.announce("Не удалось определить время. Открой форму планирования.")
      return
    }

    const form = document.createElement("form")
    form.method = "post"
    form.action = payload.url
    form.hidden = true

    this.addField(form, "authenticity_token", document.querySelector("meta[name='csrf-token']")?.content || "")
    if (payload.method === "patch") this.addField(form, "_method", "patch")
    if (payload.kind === "calendar-event") {
      this.addField(form, "calendar_event[local_date]", date)
      this.addField(form, "calendar_event[local_time]", time)
      this.addField(form, "calendar_event[duration_minutes]", payload.duration)
      this.addField(form, "calendar_event[timezone]", this.timezoneValue)
      this.addField(form, "calendar_event[lock_version]", payload.eventLockVersion)
    } else {
      this.addField(form, "task[lock_version]", payload.taskLockVersion)
      this.addField(form, "time_block[local_date]", date)
      this.addField(form, "time_block[local_time]", time)
      this.addField(form, "time_block[duration_minutes]", payload.duration)
      this.addField(form, "time_block[locked]", payload.locked)
      this.addField(form, "time_block[timezone]", this.timezoneValue)
      if (payload.blockLockVersion) this.addField(form, "time_block[lock_version]", payload.blockLockVersion)
    }
    this.addField(form, "view", this.viewValue || "week")
    this.addField(form, "date", date)

    this.element.classList.add("is-planner-submitting")
    this.announce(payload.kind === "task" ? `Ставлю задачу на ${time}` : `Переношу на ${time}`)
    document.body.appendChild(form)
    form.requestSubmit()
  }

  addField(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value ?? ""
    form.appendChild(input)
  }

  clearDropState(except = null) {
    this.dayTargets.forEach((day) => {
      if (day !== except) this.resetDay(day)
    })
  }

  resetDay(day) {
    day.classList.remove("is-planner-drop-target")
    day.classList.remove("is-month-drop-target")
    day.style.removeProperty("--planner-drop-y")
    delete day.dataset.plannerDropTime
  }

  announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  desktopEnabled() {
    return window.matchMedia("(min-width: 721px)").matches
  }
}

application.register("planner-drag", PlannerDragController)
eagerLoadControllersFrom("controllers", application)
