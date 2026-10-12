import { createElement } from "lwc";
import SlaCountdown from "c/slaCountdown";

const NOW = Date.parse("2026-01-05T12:00:00.000Z");
const minutesFromNow = (minutes) =>
  new Date(NOW + minutes * 60 * 1000).toISOString();

function render(milestone) {
  const element = createElement("c-sla-countdown", { is: SlaCountdown });
  element.milestone = milestone;
  document.body.appendChild(element);
  return element;
}

const badgeOf = (element) =>
  element.shadowRoot.querySelector('[data-id="badge"]');

describe("c-sla-countdown", () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(NOW);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.useRealTimers();
  });

  it("shows the time left and the on-track style", () => {
    const element = render({
      type: "First Response",
      status: "Open",
      targetAt: minutesFromNow(30),
      atRiskAt: minutesFromNow(22)
    });

    const badge = badgeOf(element);
    expect(badge.textContent).toBe("30m 00s left");
    expect(badge.className).toContain("sla-badge_on-track");
    expect(badge.title).toBe("First Response: 30m 00s left");
  });

  it("counts down every second and turns at risk", async () => {
    const element = render({
      status: "Open",
      targetAt: minutesFromNow(30),
      atRiskAt: minutesFromNow(22)
    });

    jest.advanceTimersByTime(23 * 60 * 1000);
    await Promise.resolve();

    const badge = badgeOf(element);
    expect(badge.textContent).toBe("7m 00s left");
    expect(badge.className).toContain("sla-badge_at-risk");
  });

  it("shows a completed milestone as met", () => {
    const element = render({
      status: "Met",
      targetAt: minutesFromNow(30),
      completedAt: minutesFromNow(-5)
    });

    expect(badgeOf(element).textContent).toBe("Met");
    expect(badgeOf(element).className).toContain("sla-badge_met");
  });

  it("stops ticking when removed from the page", () => {
    const clearSpy = jest.spyOn(global, "clearInterval");
    const element = render({ status: "Open", targetAt: minutesFromNow(30) });

    document.body.removeChild(element);

    expect(clearSpy).toHaveBeenCalled();
    clearSpy.mockRestore();
  });
});
