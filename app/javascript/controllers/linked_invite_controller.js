import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = {
    inviteId: Number,
    searchUrl: String,
    linkUrlTemplate: String
  }

  connect() {
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    this.boundReposition = this.positionResults.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
    window.addEventListener("scroll", this.boundReposition, true)
    window.addEventListener("resize", this.boundReposition)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    window.removeEventListener("scroll", this.boundReposition, true)
    window.removeEventListener("resize", this.boundReposition)
    if (this.searchTimer) clearTimeout(this.searchTimer)
  }

  positionResults() {
    if (!this.hasResultsTarget || !this.hasInputTarget) return
    if (this.resultsTarget.style.display === "none") return
    const rect = this.inputTarget.getBoundingClientRect()
    this.resultsTarget.style.top = `${rect.bottom + 2}px`
    this.resultsTarget.style.left = `${rect.left}px`
    this.resultsTarget.style.width = `${rect.width}px`
  }

  search() {
    if (this.searchTimer) clearTimeout(this.searchTimer)
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.hideResults()
      return
    }
    this.searchTimer = setTimeout(() => this.runSearch(query), 200)
  }

  async runSearch(query) {
    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    url.searchParams.set("exclude_id", this.inviteIdValue)

    const response = await fetch(url, { headers: { "Accept": "application/json" } })
    if (!response.ok) return

    const matches = await response.json()
    this.renderResults(matches)
  }

  renderResults(matches) {
    if (matches.length === 0) {
      this.resultsTarget.innerHTML = `<div class="linked-invite-empty">No matches</div>`
    } else {
      this.resultsTarget.innerHTML = matches.map(m => `
        <button type="button" class="linked-invite-result" data-action="click->linked-invite#select" data-id="${m.id}">
          <div class="linked-invite-result-name">${this.escape(m.name)}</div>
          <div class="linked-invite-result-email">${this.escape(m.email || "")}</div>
        </button>
      `).join("")
    }
    this.resultsTarget.style.display = "block"
    this.positionResults()
  }

  hideResults() {
    if (!this.hasResultsTarget) return
    this.resultsTarget.style.display = "none"
    this.resultsTarget.innerHTML = ""
  }

  select(event) {
    const id = event.currentTarget.dataset.id
    this.submitLink(id)
  }

  unlink(event) {
    event.preventDefault()
    this.submitLink("")
  }

  async submitLink(linkedInviteId) {
    const url = this.linkUrlTemplateValue.replace(":id", this.inviteIdValue)
    const body = new FormData()
    body.append("linked_invite_id", linkedInviteId)

    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this.csrfToken()
      },
      body: body
    })

    if (response.ok) {
      const text = await response.text()
      window.Turbo.renderStreamMessage(text)
    }
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.hideResults()
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }

  escape(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
