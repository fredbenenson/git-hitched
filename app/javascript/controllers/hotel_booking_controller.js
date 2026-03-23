import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkIn", "checkOut", "rooms", "summary", "nights", "roomCount", "total"]

  connect() {
    this.calculate()
  }

  calculate() {
    const checkIn = this.checkInTarget.value
    const checkOut = this.checkOutTarget.value
    const rooms = parseInt(this.roomsTarget.value) || 1

    if (!checkIn || !checkOut) {
      this.summaryTarget.style.display = "none"
      return
    }

    const nights = Math.ceil((new Date(checkOut) - new Date(checkIn)) / (1000 * 60 * 60 * 24))

    if (nights <= 0) {
      this.summaryTarget.style.display = "none"
      return
    }

    const total = nights * rooms * 220

    this.nightsTarget.textContent = nights
    this.roomCountTarget.textContent = rooms
    this.totalTarget.textContent = total.toLocaleString()
    this.summaryTarget.style.display = "block"
  }
}
