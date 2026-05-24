import { Controller } from "@hotwired/stimulus"

// Drag-and-drop wiring for the seating floorplan.
//
// Hosts state for an in-flight drag (which RSVP IDs are moving, which group)
// and orchestrates dragstart/dragover/drop on its child elements via
// delegated listeners. POSTs to the move endpoint and applies the returned
// turbo-stream response.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.draggedRsvpIds = []
    this.draggedGroupId = null
    this.sourceElement = null
    this.hoveredDropTarget = null
    this.selectedRsvpIds = new Set()
    this.groupMode = false

    this.onDragStart = this.onDragStart.bind(this)
    this.onDragEnd = this.onDragEnd.bind(this)
    this.onDragOver = this.onDragOver.bind(this)
    this.onDragLeave = this.onDragLeave.bind(this)
    this.onDrop = this.onDrop.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKeyDown = this.onKeyDown.bind(this)
    this.onBeforeUnload = this.onBeforeUnload.bind(this)

    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragend", this.onDragEnd)
    this.element.addEventListener("dragover", this.onDragOver)
    this.element.addEventListener("dragleave", this.onDragLeave)
    this.element.addEventListener("drop", this.onDrop)
    this.element.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKeyDown)
    window.addEventListener("beforeunload", this.onBeforeUnload)
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragend", this.onDragEnd)
    this.element.removeEventListener("dragover", this.onDragOver)
    this.element.removeEventListener("dragleave", this.onDragLeave)
    this.element.removeEventListener("drop", this.onDrop)
    this.element.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKeyDown)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
  }

  // Warn before reload / close / external navigation if any unlocked seat is
  // filled. The show action wipes unlocked assignments on every visit, so an
  // accidental refresh would silently destroy unsaved placements. Turbo
  // visits (our own form submits) don't fire beforeunload, so this only
  // catches genuine page unloads.
  onBeforeUnload(event) {
    const hasUnlockedPlacements = this.element.querySelector(
      "[data-drop-target='seat'][data-rsvp-id]:not([data-locked])"
    )
    if (!hasUnlockedPlacements) return
    event.preventDefault()
    event.returnValue = ""
  }

  onClick(event) {
    const target = event.target.closest("[draggable='true'][data-rsvp-id]")
    if (!target) return

    // Shift-click always toggles the single guest, regardless of mode.
    if (event.shiftKey) {
      event.preventDefault()
      event.stopPropagation()
      this.toggleSelection(target)
      return
    }

    // Group mode: plain click toggles the whole linked-invite group.
    if (this.groupMode) {
      event.preventDefault()
      event.stopPropagation()
      this.toggleGroupSelection(target)
      return
    }

    // Default: plain clicks pass through (so embedded lock/shuffle buttons work).
  }

  toggleGroupMode(event) {
    this.groupMode = event.target.checked
    this.element.classList.toggle("is-group-mode", this.groupMode)
    if (!this.groupMode) this.clearSelection()
  }

  toggleGroupSelection(element) {
    const groupId = element.dataset.groupId
    if (!groupId) return

    const members = this.element.querySelectorAll(
      `[draggable='true'][data-group-id="${groupId}"][data-rsvp-id]`
    )
    if (members.length === 0) return

    // If every member is already selected, this click deselects them all;
    // otherwise add the whole group to the selection.
    const allSelected = Array.from(members).every(el =>
      this.selectedRsvpIds.has(parseInt(el.dataset.rsvpId, 10))
    )

    members.forEach(el => {
      const id = parseInt(el.dataset.rsvpId, 10)
      if (allSelected) {
        this.selectedRsvpIds.delete(id)
        el.classList.remove("is-selected")
      } else {
        this.selectedRsvpIds.add(id)
        el.classList.add("is-selected")
      }
    })
  }

  onKeyDown(event) {
    if (event.key === "Escape" && this.selectedRsvpIds.size > 0) {
      this.clearSelection()
    }
  }

  toggleSelection(element) {
    const rsvpId = parseInt(element.dataset.rsvpId, 10)
    if (this.selectedRsvpIds.has(rsvpId)) {
      this.selectedRsvpIds.delete(rsvpId)
      element.classList.remove("is-selected")
    } else {
      this.selectedRsvpIds.add(rsvpId)
      element.classList.add("is-selected")
    }
  }

  clearSelection() {
    this.selectedRsvpIds.clear()
    this.element.querySelectorAll(".is-selected").forEach(el => el.classList.remove("is-selected"))
  }

  selectedElements() {
    return Array.from(this.element.querySelectorAll(".is-selected"))
  }

  onDragStart(event) {
    const source = event.target.closest("[draggable='true'][data-rsvp-id]")
    if (!source) return
    if (source.dataset.locked) {
      event.preventDefault()
      return
    }

    const sourceRsvpId = parseInt(source.dataset.rsvpId, 10)
    // If the source is part of an active selection, drag the whole bundle.
    // Otherwise drag just this one (selection state untouched).
    if (this.selectedRsvpIds.has(sourceRsvpId) && this.selectedRsvpIds.size > 1) {
      this.draggedRsvpIds = Array.from(this.selectedRsvpIds)
    } else {
      this.draggedRsvpIds = [sourceRsvpId]
    }

    this.sourceElement = source
    this.draggedGroupId = source.dataset.groupId

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", source.dataset.rsvpId)

    // Replace the browser's default drag image — by default it would snapshot
    // the seat's bounding box, which includes absolutely-positioned name
    // labels that bleed into neighboring seats.
    const ghost = this.createDragGhost(source)
    document.body.appendChild(ghost)
    event.dataTransfer.setDragImage(ghost, 12, 10)
    setTimeout(() => ghost.remove(), 0)

    this.element.classList.add("is-dragging")
    if (this.draggedRsvpIds.length > 1) {
      this.element.classList.add("is-dragging-multi")
    }
    this.markGroupHints()
  }

  createDragGhost(source) {
    const ghost = document.createElement("div")
    ghost.className = "seating-drag-ghost"
    if (this.draggedRsvpIds.length > 1) {
      ghost.textContent = `${this.draggedRsvpIds.length} guests`
    } else {
      const nameEl = source.querySelector(".seat__name")
      ghost.textContent = nameEl ? nameEl.textContent.trim() : source.textContent.trim()
    }
    return ghost
  }

  markGroupHints() {
    if (!this.draggedGroupId) return
    const selector = `[data-group-id="${this.draggedGroupId}"][data-rsvp-id]`
    this.element.querySelectorAll(selector).forEach(el => {
      if (el === this.sourceElement) return
      el.classList.add("is-group-hint")
    })
  }

  clearGroupHints() {
    this.element.querySelectorAll(".is-group-hint").forEach(el => el.classList.remove("is-group-hint"))
  }

  onDragEnd() {
    this.clearHover()
    this.clearGroupHints()
    this.element.classList.remove("is-dragging", "is-dragging-multi")
    this.sourceElement = null
    this.draggedRsvpIds = []
    this.draggedGroupId = null
  }

  onDragOver(event) {
    if (this.draggedRsvpIds.length === 0) return

    const target = event.target.closest("[data-drop-target]")
    if (!target) {
      this.clearHover()
      return
    }

    if (!this.isValidDropTarget(target)) {
      event.dataTransfer.dropEffect = "none"
      this.setHover(target, "invalid")
      return
    }

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.setHover(target, "valid")
  }

  onDragLeave(event) {
    // Only clear when we've actually left the current hovered target (not just
    // moved to a child of it).
    if (!this.hoveredDropTarget) return
    if (!event.relatedTarget || !this.hoveredDropTarget.contains(event.relatedTarget)) {
      this.clearHover()
    }
  }

  async onDrop(event) {
    if (this.draggedRsvpIds.length === 0) return
    const target = event.target.closest("[data-drop-target]")
    if (!target || !this.isValidDropTarget(target)) return

    event.preventDefault()

    const destination = this.destinationFor(target)
    if (!destination) return

    await this.submitMove(destination)
  }

  isValidDropTarget(target) {
    const kind = target.dataset.dropTarget
    const isMulti = this.draggedRsvpIds.length > 1

    if (kind === "seat") {
      // Specific-seat drops only make sense for a single guest.
      if (isMulti) return false
      if (target.dataset.locked) return false
      if (this.sourceElement === target) return false
      return true
    }

    if (kind === "table") {
      // Refuse if the entire selection is already at this table — likely
      // accidental drop. (Server would no-op anyway, but skip the round trip.)
      const tableId = target.dataset.tableId
      const allHere = this.draggedRsvpIds.every(id => {
        const el = this.element.querySelector(`.seat[data-rsvp-id="${id}"]`)
        return el && el.dataset.tableId === tableId
      })
      if (allHere) return false
      return true
    }

    if (kind === "unseated") {
      const sourceInRail = this.sourceElement?.closest("[data-drop-target='unseated']")
      if (sourceInRail) return false
      return true
    }

    return false
  }

  destinationFor(target) {
    const kind = target.dataset.dropTarget
    if (kind === "seat") {
      return { type: "seat", table_id: target.dataset.tableId, position: target.dataset.position }
    }
    if (kind === "table") {
      return { type: "table", table_id: target.dataset.tableId }
    }
    if (kind === "unseated") {
      return { type: "unseated" }
    }
    return null
  }

  async submitMove(destination) {
    const body = new FormData()
    this.draggedRsvpIds.forEach(id => body.append("rsvp_ids[]", id))
    body.append("destination[type]", destination.type)
    if (destination.table_id) body.append("destination[table_id]", destination.table_id)
    if (destination.position) body.append("destination[position]", destination.position)

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this.csrfToken()
      },
      body: body
    })

    if (response.ok) {
      const text = await response.text()
      window.Turbo.renderStreamMessage(text)
      // Re-rendered nodes lost their .is-selected class; clear the set too.
      this.selectedRsvpIds.clear()
    }
  }

  setHover(target, kind) {
    if (this.hoveredDropTarget === target && this.hoverKind === kind) return
    this.clearHover()
    target.classList.add(`is-drop-target--${kind}`)
    this.hoveredDropTarget = target
    this.hoverKind = kind
  }

  clearHover() {
    if (this.hoveredDropTarget) {
      this.hoveredDropTarget.classList.remove("is-drop-target--valid", "is-drop-target--invalid")
      this.hoveredDropTarget = null
      this.hoverKind = null
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
