import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getQueue from "@salesforce/apex/SlaConsoleController.getQueue";
import { statusModifier } from "c/slaUtils";

const REFRESH_MS = 60 * 1000;

const SCOPE_OPTIONS = [
  { label: "All open", value: "ALL" },
  { label: "At risk & breached", value: "AT_RISK" },
  { label: "My queues", value: "MINE" }
];

const TILES = [
  { key: "Breached", label: "Breached" },
  { key: "At Risk", label: "At risk" },
  { key: "On Track", label: "On track" },
  { key: "Paused", label: "Paused" }
];

/**
 * SLA queue console: open cases ranked by urgency, with live countdowns.
 * Reloads every minute; countdowns tick every second on their own.
 */
export default class CaseQueue extends NavigationMixin(LightningElement) {
  scope = "ALL";
  rows = [];
  errorMessage;
  isLoading = true;
  lastRefreshed;
  timerId;

  scopeOptions = SCOPE_OPTIONS;

  connectedCallback() {
    this.load();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.timerId = setInterval(() => this.load(), REFRESH_MS);
  }

  disconnectedCallback() {
    clearInterval(this.timerId);
  }

  async load() {
    try {
      const items = await getQueue({ scope: this.scope });
      this.rows = items.map((item) => ({
        ...item,
        accountLabel: item.accountName ?? "—",
        urgencyClass: `urgency urgency_${statusModifier(item.urgency)}`,
        escalationLabel:
          item.escalationLevel > 0 ? `L${item.escalationLevel}` : ""
      }));
      this.errorMessage = undefined;
      this.lastRefreshed = new Date();
    } catch (error) {
      this.errorMessage = error?.body?.message ?? "Unable to load the queue.";
    } finally {
      this.isLoading = false;
    }
  }

  handleScopeChange(event) {
    this.scope = event.detail.value;
    this.isLoading = true;
    this.load();
  }

  handleRefresh() {
    this.load();
  }

  handleOpenCase(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: event.currentTarget.dataset.caseId,
        objectApiName: "Case",
        actionName: "view"
      }
    });
  }

  get tiles() {
    return TILES.map((tile) => ({
      ...tile,
      count: this.rows.filter((row) => row.urgency === tile.key).length,
      className: `tile tile_${statusModifier(tile.key)}`
    }));
  }

  get refreshedLabel() {
    if (!this.lastRefreshed) {
      return "";
    }

    const time = this.lastRefreshed.toLocaleTimeString([], {
      hour: "2-digit",

      minute: "2-digit",

      second: "2-digit"
    });

    return `Updated ${time}`;
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.errorMessage && !this.hasRows;
  }
}
