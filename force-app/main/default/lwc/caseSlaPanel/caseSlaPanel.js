import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import getCaseSla from "@salesforce/apex/CaseSlaController.getCaseSla";
import CASE_LAST_MODIFIED from "@salesforce/schema/Case.LastModifiedDate";
import { statusModifier } from "c/slaUtils";

/** "Tier2_Escalations" -> "Tier 2 Escalations" */
const queueLabel = (developerName) =>
  developerName.replace(/_/g, " ").replace(/([a-z])(\d)/gi, "$1 $2");

/**
 * SLA panel for the Case record page: live countdown per milestone and the
 * escalation trail. Refreshes itself whenever the case is saved.
 */
export default class CaseSlaPanel extends LightningElement {
  @api recordId;

  slaResult;
  lastModified;

  @wire(getCaseSla, { caseId: "$recordId" })
  wiredSla(result) {
    this.slaResult = result;
  }

  @wire(getRecord, { recordId: "$recordId", fields: [CASE_LAST_MODIFIED] })
  wiredCase({ data }) {
    if (!data) {
      return;
    }
    const modified = data.fields.LastModifiedDate.value;
    if (this.lastModified && modified !== this.lastModified && this.slaResult) {
      refreshApex(this.slaResult);
    }
    this.lastModified = modified;
  }

  get sla() {
    return this.slaResult?.data;
  }

  get errorMessage() {
    const error = this.slaResult?.error;
    if (!error) {
      return undefined;
    }
    return error.body?.message ?? error.message ?? "Unable to load the SLA.";
  }

  get isLoading() {
    return !this.sla && !this.errorMessage;
  }

  get slaStatus() {
    return this.sla?.slaStatus ?? "No SLA";
  }

  get statusClass() {
    return `sla-status sla-status_${statusModifier(this.sla?.slaStatus)}`;
  }

  get milestones() {
    return this.sla?.milestones ?? [];
  }

  get hasMilestones() {
    return this.milestones.length > 0;
  }

  get escalations() {
    return (this.sla?.escalations ?? []).map((escalation) => ({
      ...escalation,
      title: `Level ${escalation.level} · ${escalation.reason}`,
      detail: escalation.targetQueue
        ? `· Moved to ${queueLabel(escalation.targetQueue)} ·`
        : "· Owner unchanged ·",
      createdAt: escalation.createdDate
        ? Date.parse(escalation.createdDate)
        : undefined
    }));
  }

  get hasEscalations() {
    return this.escalations.length > 0;
  }
}
