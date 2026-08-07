import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (this.element.querySelector("[data-task-errors]")) this.element.open = true
  }
}
