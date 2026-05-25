import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "hamburger"]

  toggle() {
    this.menuTarget.classList.toggle("nav-open")
    this.hamburgerTarget.classList.toggle("nav-tab-open")
  }

  close() {
    this.menuTarget.classList.remove("nav-open")
    this.hamburgerTarget.classList.remove("nav-tab-open")
  }
}
