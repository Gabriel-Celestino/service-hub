import { LightningElement, api } from "lwc";
import { computeSlaState } from "c/slaUtils";

const TICK_MS = 1000;

/**
 * Live countdown badge for one SLA milestone. Ticks every second while the
 * clock is running; stops when the milestone is paused or completed.
 */
export default class SlaCountdown extends LightningElement {
  @api milestone;

  now = Date.now();
  timerId;

  connectedCallback() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.timerId = setInterval(() => {
      this.now = Date.now();
    }, TICK_MS);
  }

  disconnectedCallback() {
    clearInterval(this.timerId);
  }

  get sla() {
    return computeSlaState(this.milestone, this.now);
  }

  get label() {
    return this.sla.label;
  }

  get badgeClass() {
    return `sla-badge sla-badge_${this.sla.state}`;
  }

  get assistiveText() {
    const type = this.milestone?.type ?? "SLA";
    return `${type}: ${this.sla.label}`;
  }
}
