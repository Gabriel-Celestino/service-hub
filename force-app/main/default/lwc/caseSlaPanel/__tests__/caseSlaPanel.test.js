import { createElement } from "lwc";
import CaseSlaPanel from "c/caseSlaPanel";
import getCaseSla from "@salesforce/apex/CaseSlaController.getCaseSla";
import { getRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";

const mockSla = require("./data/getCaseSla.json");

jest.mock(
  "@salesforce/apex/CaseSlaController.getCaseSla",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

const CASE_ID = "500000000000001AAA";

function render() {
  const element = createElement("c-case-sla-panel", { is: CaseSlaPanel });
  element.recordId = CASE_ID;
  document.body.appendChild(element);
  return element;
}

const flush = () => Promise.resolve();
const all = (element, id) =>
  element.shadowRoot.querySelectorAll(`[data-id="${id}"]`);
const one = (element, id) =>
  element.shadowRoot.querySelector(`[data-id="${id}"]`);

describe("c-case-sla-panel", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows a spinner until the SLA arrives", () => {
    const element = render();

    expect(
      element.shadowRoot.querySelector("lightning-spinner")
    ).not.toBeNull();
  });

  it("shows each milestone with a countdown and the case status", async () => {
    const element = render();
    getCaseSla.emit(mockSla);
    await flush();

    expect(all(element, "milestone")).toHaveLength(2);
    expect(element.shadowRoot.querySelectorAll("c-sla-countdown")).toHaveLength(
      2
    );
    const status = one(element, "status");
    expect(status.textContent).toBe("At Risk");
    expect(status.className).toContain("sla-status_at-risk");
  });

  it("shows the escalation trail", async () => {
    const element = render();
    getCaseSla.emit(mockSla);
    await flush();

    const escalations = all(element, "escalation");
    expect(escalations).toHaveLength(1);
    expect(escalations[0].textContent).toContain("Level 1 · SLA At Risk");
    expect(escalations[0].textContent).toContain("Owner unchanged");
  });

  it("shows empty states when there is nothing to show", async () => {
    const element = render();
    getCaseSla.emit({
      slaStatus: null,
      escalationLevel: 0,
      milestones: [],
      escalations: []
    });
    await flush();

    expect(one(element, "no-milestones")).not.toBeNull();
    expect(one(element, "no-escalations")).not.toBeNull();
    expect(one(element, "status").textContent).toBe("No SLA");
  });

  it("shows the server error message", async () => {
    const element = render();
    getCaseSla.error({ message: "Case not found or not accessible." });
    await flush();

    expect(one(element, "error").textContent).toBe(
      "Case not found or not accessible."
    );
  });

  it("refreshes the SLA when the case is saved", async () => {
    render();
    getCaseSla.emit(mockSla);
    getRecord.emit({
      fields: { LastModifiedDate: { value: "2026-01-05T12:00:00.000Z" } }
    });
    await flush();
    expect(refreshApex).not.toHaveBeenCalled();

    getRecord.emit({
      fields: { LastModifiedDate: { value: "2026-01-05T12:05:00.000Z" } }
    });
    await flush();

    expect(refreshApex).toHaveBeenCalledTimes(1);
  });
});
