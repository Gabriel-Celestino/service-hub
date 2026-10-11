/**
 * Domain logic for a single SLA milestone: deadlines, pauses and completion.
 *
 * Deadlines are always derived from the same formula, so a recalculation after
 * a pause or a priority change gives the same result as a fresh calculation:
 *
 *   target  = start + policy minutes                 + paused minutes
 *   at risk = start + policy minutes x at-risk share + paused minutes
 *
 * All minutes are business minutes, through the injected BusinessClock.
 * No SOQL or DML.
 */
public inherited sharing class SlaMilestoneCalculator {
  private final BusinessClock clock;

  public SlaMilestoneCalculator(BusinessClock clock) {
    this.clock = clock;
  }

  public void applyTargets(
    SLA_Milestone__c milestone,
    Datetime startTime,
    SLA_Policy__mdt policy,
    Id businessHoursId
  ) {
    Integer targetMinutes = targetMinutes(milestone.Type__c, policy);
    Integer atRiskMinutes = atRiskMinutes(
      targetMinutes,
      policy.At_Risk_Percent__c
    );
    Integer pausedMinutes = pausedMinutes(milestone);
    milestone.Target_At__c = clock.addMinutes(
      businessHoursId,
      startTime,
      targetMinutes + pausedMinutes
    );
    milestone.At_Risk_At__c = clock.addMinutes(
      businessHoursId,
      startTime,
      atRiskMinutes + pausedMinutes
    );
  }

  /** Stops the clock. Completed or already paused milestones are left as they are. */
  public void pause(SLA_Milestone__c milestone, Datetime now) {
    if (
      isCompleted(milestone) ||
      milestone.Status__c == SlaConstants.MILESTONE_PAUSED
    ) {
      return;
    }
    milestone.Status__c = SlaConstants.MILESTONE_PAUSED;
    milestone.Paused_Since__c = now;
  }

  /**
   * Restarts the clock and adds the paused business minutes. Call
   * applyTargets afterwards to move the deadlines.
   */
  public void resume(
    SLA_Milestone__c milestone,
    Datetime now,
    Id businessHoursId
  ) {
    if (
      milestone.Status__c != SlaConstants.MILESTONE_PAUSED ||
      milestone.Paused_Since__c == null
    ) {
      return;
    }
    Integer pausedNow = clock.minutesBetween(
      businessHoursId,
      milestone.Paused_Since__c,
      now
    );
    milestone.Paused_Minutes__c = pausedMinutes(milestone) + pausedNow;
    milestone.Paused_Since__c = null;
    milestone.Status__c = SlaConstants.MILESTONE_OPEN;
  }

  /** Sets Open, At Risk or Breached from the current time. Ignores paused and completed milestones. */
  public void refreshStatus(SLA_Milestone__c milestone, Datetime now) {
    if (
      isCompleted(milestone) ||
      milestone.Status__c == SlaConstants.MILESTONE_PAUSED
    ) {
      return;
    }
    if (now > milestone.Target_At__c) {
      milestone.Status__c = SlaConstants.MILESTONE_BREACHED;
    } else if (now >= milestone.At_Risk_At__c) {
      milestone.Status__c = SlaConstants.MILESTONE_AT_RISK;
    } else {
      milestone.Status__c = SlaConstants.MILESTONE_OPEN;
    }
  }

  /**
   * Closes the milestone as Met or Breached. A paused milestone is judged at
   * the moment it was paused, since its clock was stopped. A milestone already
   * flagged as Breached stays Breached.
   */
  public void complete(SLA_Milestone__c milestone, Datetime now) {
    if (isCompleted(milestone)) {
      return;
    }
    Boolean paused =
      milestone.Status__c == SlaConstants.MILESTONE_PAUSED &&
      milestone.Paused_Since__c != null;
    Datetime effectiveTime = paused ? milestone.Paused_Since__c : now;
    Boolean late =
      milestone.Status__c == SlaConstants.MILESTONE_BREACHED ||
      effectiveTime > milestone.Target_At__c;

    milestone.Status__c = late
      ? SlaConstants.MILESTONE_BREACHED
      : SlaConstants.MILESTONE_MET;
    milestone.Completed_At__c = now;
    milestone.Paused_Since__c = null;
  }

  public static Boolean isCompleted(SLA_Milestone__c milestone) {
    return milestone.Completed_At__c != null;
  }

  private static Integer targetMinutes(
    String milestoneType,
    SLA_Policy__mdt policy
  ) {
    Decimal minutes = milestoneType == SlaConstants.TYPE_FIRST_RESPONSE
      ? policy.First_Response_Minutes__c
      : policy.Resolution_Minutes__c;
    return minutes.intValue();
  }

  private static Integer atRiskMinutes(
    Integer targetMinutes,
    Decimal atRiskPercent
  ) {
    Decimal percent = atRiskPercent == null ? 100 : atRiskPercent;
    return (targetMinutes *
      percent /
      100)
      .setScale(0, System.RoundingMode.DOWN)
      .intValue();
  }

  private static Integer pausedMinutes(SLA_Milestone__c milestone) {
    return milestone.Paused_Minutes__c == null
      ? 0
      : milestone.Paused_Minutes__c.intValue();
  }
}
