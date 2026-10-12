import { createElement } from "lwc";
import CaseQueue from "c/caseQueue";
import getQueue from "@salesforce/apex/SlaConsoleController.getQueue";

const mockQueue = require("./data/getQueue.json");

jest.mock(
  "@salesforce/apex/SlaConsoleController.getQueue",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

// Records every navigation request made through NavigationMixin.
const mockNavigate = jest.fn();
jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  const GenerateUrl = Symbol("GenerateUrl");
  const NavigationMixin = (Base) =>
    class extends Base {
      [Navigate](pageReference, replace) {
        mockNavigate(pageReference, replace);
      }
      [GenerateUrl]() {
        return Promise.resolve("https://example.com");
      }
    };
  NavigationMixin.Navigate = Navigate;
  NavigationMixin.GenerateUrl = GenerateUrl;
  return { NavigationMixin };
});

function render() {
  const element = createElement("c-case-queue", { is: CaseQueue });
  document.body.appendChild(element);
  return element;
}

// Lets the Apex promise resolve and the component re-render.
// eslint-disable-next-line @lwc/lwc/no-async-operation
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const all = (element, id) =>
  element.shadowRoot.querySelectorAll(`[data-id="${id}"]`);
const one = (element, id) =>
  element.shadowRoot.querySelector(`[data-id="${id}"]`);
const tileCount = (element, key) =>
  element.shadowRoot.querySelector(
    `[data-id="tile"][data-key="${key}"] .tile__count`
  ).textContent;

describe("c-case-queue", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("lists cases in the order the server ranked them", async () => {
    getQueue.mockResolvedValue(mockQueue);
    const element = render();
    await flush();

    const rows = all(element, "row");
    expect(rows).toHaveLength(3);
    expect(rows[0].textContent).toContain("00001001");
    expect(rows[0].textContent).toContain("Breached");
    expect(rows[0].textContent).toContain("L2");
    expect(rows[2].textContent).toContain("—");
    expect(element.shadowRoot.querySelectorAll("c-sla-countdown")).toHaveLength(
      3
    );
    expect(getQueue).toHaveBeenCalledWith({ scope: "ALL" });
  });

  it("counts cases per urgency in the tiles", async () => {
    getQueue.mockResolvedValue(mockQueue);
    const element = render();
    await flush();

    expect(tileCount(element, "Breached")).toBe("1");
    expect(tileCount(element, "At Risk")).toBe("1");
    expect(tileCount(element, "On Track")).toBe("1");
    expect(tileCount(element, "Paused")).toBe("0");
  });

  it("reloads with the selected scope", async () => {
    getQueue.mockResolvedValue(mockQueue);
    const element = render();
    await flush();

    getQueue.mockResolvedValue([mockQueue[0]]);
    one(element, "scope").dispatchEvent(
      new CustomEvent("change", { detail: { value: "AT_RISK" } })
    );
    await flush();

    expect(getQueue).toHaveBeenLastCalledWith({ scope: "AT_RISK" });
    expect(all(element, "row")).toHaveLength(1);
  });

  it("opens the case record when its number is clicked", async () => {
    getQueue.mockResolvedValue(mockQueue);
    const element = render();
    await flush();

    all(element, "case-link")[1].click();

    expect(mockNavigate).toHaveBeenCalledTimes(1);
    const [pageReference] = mockNavigate.mock.calls[0];
    expect(pageReference.type).toBe("standard__recordPage");
    expect(pageReference.attributes.recordId).toBe("500000000000002AAA");
    expect(pageReference.attributes.actionName).toBe("view");
  });

  it("shows an empty state when there is nothing to work on", async () => {
    getQueue.mockResolvedValue([]);
    const element = render();
    await flush();

    expect(one(element, "empty")).not.toBeNull();
    expect(all(element, "row")).toHaveLength(0);
  });

  it("shows the server error message", async () => {
    getQueue.mockRejectedValue({ body: { message: "Unknown queue scope: X" } });
    const element = render();
    await flush();

    expect(one(element, "error").textContent).toBe("Unknown queue scope: X");
  });

  it("refreshes on demand and every minute", async () => {
    jest.useFakeTimers();
    getQueue.mockResolvedValue(mockQueue);
    const element = render();
    expect(getQueue).toHaveBeenCalledTimes(1);

    one(element, "refresh").click();
    expect(getQueue).toHaveBeenCalledTimes(2);

    jest.advanceTimersByTime(60 * 1000);
    expect(getQueue).toHaveBeenCalledTimes(3);
  });

  it("stops refreshing when removed from the page", () => {
    const clearSpy = jest.spyOn(global, "clearInterval");
    getQueue.mockResolvedValue(mockQueue);
    const element = render();

    document.body.removeChild(element);

    expect(clearSpy).toHaveBeenCalled();
    clearSpy.mockRestore();
  });
});
