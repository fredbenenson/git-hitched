import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "counter"]

  connect() {
    this.index = 0
    this.total = this.slideTargets.length
    this.showSlide()
  }

  next() {
    this.index = (this.index + 1) % this.total
    this.showSlide()
  }

  prev() {
    this.index = (this.index - 1 + this.total) % this.total
    this.showSlide()
  }

  showSlide() {
    this.slideTargets.forEach((el, i) => {
      el.style.display = i === this.index ? "block" : "none"
    })
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.index + 1} / ${this.total}`
    }
  }
}
