/**
 * Pure helpers for showing SLA milestones. No DOM, no Apex: easy to test.
 */

export const SLA_STATES = Object.freeze({
  ON_TRACK: "on-track",
  AT_RISK: "at-risk",
  BREACHED: "breached",
  PAUSED: "paused",
  MET: "met"
});

const SECOND = 1000;
const MINUTE = 60 * SECOND;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const pad = (value) => String(value).padStart(2, "0");

/**
 * Formats a duration as "2d 03h 15m", "1h 05m 09s" or "4m 07s".
 * The sign is ignored: callers say whether time is left or overdue.
 */
export function formatDuration(milliseconds) {
  const total = Math.floor(Math.abs(milliseconds) / SECOND) * SECOND;
  const days = Math.floor(total / DAY);
  const hours = Math.floor((total % DAY) / HOUR);
  const minutes = Math.floor((total % HOUR) / MINUTE);
  const seconds = Math.floor((total % MINUTE) / SECOND);

  if (days > 0) {
    return `${days}d ${pad(hours)}h ${pad(minutes)}m`;
  }
  if (hours > 0) {
    return `${hours}h ${pad(minutes)}m ${pad(seconds)}s`;
  }
  return `${minutes}m ${pad(seconds)}s`;
}

const toTime = (value) => (value ? new Date(value).getTime() : null);

/**
 * Works out how a milestone should look at a given moment.
 *
 * @param {object} milestone fields from CaseSlaController.MilestoneView
 * @param {number} now epoch milliseconds
 * @returns {{state: string, label: string, remainingMs: number|null}}
 */
export function computeSlaState(milestone, now = Date.now()) {
  const { status, targetAt, atRiskAt, completedAt, pausedSince } =
    milestone || {};
  const target = toTime(targetAt);

  if (completedAt) {
    const breached = status === "Breached";
    return {
      state: breached ? SLA_STATES.BREACHED : SLA_STATES.MET,
      label: breached ? "Breached" : "Met",
      remainingMs: null
    };
  }

  if (target === null) {
    return {
      state: SLA_STATES.ON_TRACK,
      label: "No deadline",
      remainingMs: null
    };
  }

  if (status === "Paused") {
    const frozenAt = toTime(pausedSince) ?? now;
    const remainingMs = target - frozenAt;
    return {
      state: SLA_STATES.PAUSED,
      label: `Paused · ${formatDuration(remainingMs)} left`,
      remainingMs
    };
  }

  const remainingMs = target - now;
  if (remainingMs < 0 || status === "Breached") {
    return {
      state: SLA_STATES.BREACHED,
      label: `Overdue by ${formatDuration(remainingMs)}`,
      remainingMs
    };
  }

  const atRisk = toTime(atRiskAt);
  const isAtRisk = status === "At Risk" || (atRisk !== null && now >= atRisk);
  return {
    state: isAtRisk ? SLA_STATES.AT_RISK : SLA_STATES.ON_TRACK,
    label: `${formatDuration(remainingMs)} left`,
    remainingMs
  };
}

/** CSS modifier for a Case.SLA_Status__c value, e.g. "At Risk" -> "at-risk". */
export function statusModifier(slaStatus) {
  return (slaStatus || "none").toLowerCase().replace(/\s+/g, "-");
}
