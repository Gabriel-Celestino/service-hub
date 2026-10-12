import {
  computeSlaState,
  formatDuration,
  statusModifier,
  SLA_STATES
} from "c/slaUtils";

const NOW = Date.parse("2026-01-05T12:00:00.000Z");
const minutesFromNow = (minutes) =>
  new Date(NOW + minutes * 60 * 1000).toISOString();

describe("formatDuration", () => {
  it("shows minutes and seconds under an hour", () => {
    expect(formatDuration(4 * 60 * 1000 + 7 * 1000)).toBe("4m 07s");
  });

  it("shows hours, minutes and seconds under a day", () => {
    expect(formatDuration(65 * 60 * 1000 + 9 * 1000)).toBe("1h 05m 09s");
  });

  it("shows days, hours and minutes from one day", () => {
    expect(formatDuration((2 * 24 * 60 + 3 * 60 + 15) * 60 * 1000)).toBe(
      "2d 03h 15m"
    );
  });

  it("ignores the sign", () => {
    expect(formatDuration(-90 * 1000)).toBe("1m 30s");
  });
});

describe("computeSlaState", () => {
  const running = {
    status: "Open",
    targetAt: minutesFromNow(30),
    atRiskAt: minutesFromNow(22)
  };

  it("is on track before the at-risk point", () => {
    const result = computeSlaState(running, NOW);
    expect(result.state).toBe(SLA_STATES.ON_TRACK);
    expect(result.label).toBe("30m 00s left");
  });

  it("is at risk after the at-risk point", () => {
    const result = computeSlaState(running, NOW + 25 * 60 * 1000);
    expect(result.state).toBe(SLA_STATES.AT_RISK);
    expect(result.label).toBe("5m 00s left");
  });

  it("trusts an At Risk status from the server", () => {
    expect(computeSlaState({ ...running, status: "At Risk" }, NOW).state).toBe(
      SLA_STATES.AT_RISK
    );
  });

  it("is breached and shows the overdue time after the target", () => {
    const result = computeSlaState(running, NOW + 31 * 60 * 1000);
    expect(result.state).toBe(SLA_STATES.BREACHED);
    expect(result.label).toBe("Overdue by 1m 00s");
  });

  it("freezes the remaining time while paused", () => {
    const paused = {
      ...running,
      status: "Paused",
      pausedSince: minutesFromNow(10)
    };
    const result = computeSlaState(paused, NOW + 500 * 60 * 1000);
    expect(result.state).toBe(SLA_STATES.PAUSED);
    expect(result.label).toBe("Paused · 20m 00s left");
  });

  it("shows Met or Breached once completed", () => {
    const done = { ...running, completedAt: minutesFromNow(5) };
    expect(computeSlaState({ ...done, status: "Met" }, NOW).label).toBe("Met");
    expect(computeSlaState({ ...done, status: "Breached" }, NOW).state).toBe(
      SLA_STATES.BREACHED
    );
  });

  it("handles a milestone without a deadline", () => {
    expect(computeSlaState({ status: "Open" }, NOW).label).toBe("No deadline");
    expect(computeSlaState(undefined, NOW).state).toBe(SLA_STATES.ON_TRACK);
  });
});

describe("statusModifier", () => {
  it("turns an SLA status into a CSS modifier", () => {
    expect(statusModifier("At Risk")).toBe("at-risk");
    expect(statusModifier("Breached")).toBe("breached");
    expect(statusModifier(undefined)).toBe("none");
  });
});
