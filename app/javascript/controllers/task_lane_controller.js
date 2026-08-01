import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!window.matchMedia("(max-width: 980px)").matches) return
    if (this.element.querySelector("[data-task-errors]")) return

    this.element.open = false
  }
}
