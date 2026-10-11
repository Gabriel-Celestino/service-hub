/**
 * Decides a case's escalation level from its running milestones:
 * 2 when a running clock is past its target, 1 when one is at risk, else 0.
 *
 * Completed milestones are history, not a reason to escalate now: a late
 * first response shows in Case.SLA_Status__c, but it does not move the case
 * to Tier 2 while its resolution clock is still on track.
 */
public inherited sharing class EscalationPolicy {
  public static final Integer LEVEL_NONE = 0;
  public static final Integer LEVEL_AT_RISK = 1;
  public static final Integer LEVEL_BREACHED = 2;

  public static final String REASON_AT_RISK = 'SLA At Risk';
  public static final String REASON_BREACHED = 'SLA Breached';

  public static final String TIER2_QUEUE = 'Tier2_Escalations';

  public static Integer levelFor(List<SLA_Milestone__c> milestones) {
    Integer level = LEVEL_NONE;
    if (milestones == null) {
      return level;
    }
    for (SLA_Milestone__c milestone : milestones) {
      if (SlaMilestoneCalculator.isCompleted(milestone)) {
        continue;
      }
      if (milestone.Status__c == SlaConstants.MILESTONE_BREACHED) {
        return LEVEL_BREACHED;
      }
      if (milestone.Status__c == SlaConstants.MILESTONE_AT_RISK) {
        level = LEVEL_AT_RISK;
      }
    }
    return level;
  }

  public static String reasonFor(Integer level) {
    return level == LEVEL_BREACHED ? REASON_BREACHED : REASON_AT_RISK;
  }

  /** DeveloperName of the queue a case moves to at this level, or null to keep its owner. */
  public static String targetQueueFor(Integer level) {
    return level == LEVEL_BREACHED ? TIER2_QUEUE : null;
  }
}
