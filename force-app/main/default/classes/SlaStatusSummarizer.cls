/**
 * Summarizes a case's milestones into Case.SLA_Status__c, worst first:
 * Breached, At Risk, On Track (a clock is running), Paused, Met.
 */
public inherited sharing class SlaStatusSummarizer {
  /** Returns null when there are no milestones, so the case is left unchanged. */
  public static String summarize(List<SLA_Milestone__c> milestones) {
    if (milestones == null || milestones.isEmpty()) {
      return null;
    }
    Boolean anyAtRisk = false;
    Boolean anyRunning = false;
    Boolean anyPaused = false;

    for (SLA_Milestone__c milestone : milestones) {
      if (milestone.Status__c == SlaConstants.MILESTONE_BREACHED) {
        return SlaConstants.SLA_BREACHED;
      }
      if (SlaMilestoneCalculator.isCompleted(milestone)) {
        continue;
      }
      if (milestone.Status__c == SlaConstants.MILESTONE_AT_RISK) {
        anyAtRisk = true;
      } else if (milestone.Status__c == SlaConstants.MILESTONE_PAUSED) {
        anyPaused = true;
      } else {
        anyRunning = true;
      }
    }

    if (anyAtRisk) {
      return SlaConstants.SLA_AT_RISK;
    }
    if (anyRunning) {
      return SlaConstants.SLA_ON_TRACK;
    }
    if (anyPaused) {
      return SlaConstants.SLA_PAUSED;
    }
    return SlaConstants.SLA_MET;
  }
}
