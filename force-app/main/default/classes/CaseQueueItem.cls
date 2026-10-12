/**
 * One row of the SLA queue console, ranked by urgency.
 *
 * Urgency is computed from the running milestones at a given moment, not from
 * Case.SLA_Status__c, so the console is exact even between two runs of the
 * escalation job. Pure logic: no SOQL or DML.
 */
public inherited sharing class CaseQueueItem implements Comparable {
  public static final Integer RANK_BREACHED = 0;
  public static final Integer RANK_AT_RISK = 1;
  public static final Integer RANK_ON_TRACK = 2;
  public static final Integer RANK_PAUSED = 3;
  public static final Integer RANK_NO_SLA = 4;

  private static final List<String> URGENCY_LABELS = new List<String>{
    'Breached',
    'At Risk',
    'On Track',
    'Paused',
    'No SLA'
  };

  @AuraEnabled
  public Id caseId;
  @AuraEnabled
  public String caseNumber;
  @AuraEnabled
  public String subject;
  @AuraEnabled
  public String accountName;
  @AuraEnabled
  public String priority;
  @AuraEnabled
  public String status;
  @AuraEnabled
  public String ownerName;
  @AuraEnabled
  public Integer escalationLevel;
  @AuraEnabled
  public Integer urgencyRank;
  @AuraEnabled
  public String urgency;
  @AuraEnabled
  public SlaMilestoneView nextMilestone;

  /**
   * @param ownerName display name of the case owner (a user or a queue),
   *        resolved by the caller
   */
  public CaseQueueItem(
    Case record,
    List<SLA_Milestone__c> openMilestones,
    String ownerName,
    Datetime now
  ) {
    List<SLA_Milestone__c> milestones = openMilestones == null
      ? new List<SLA_Milestone__c>()
      : openMilestones;
    this.caseId = record.Id;
    this.caseNumber = record.CaseNumber;
    this.subject = record.Subject;
    this.accountName = record.Account?.Name;
    this.priority = record.Priority;
    this.status = record.Status;
    this.ownerName = ownerName;
    this.escalationLevel = record.Escalation_Level__c == null
      ? 0
      : record.Escalation_Level__c.intValue();
    this.urgencyRank = rankOf(milestones, now);
    this.urgency = URGENCY_LABELS[this.urgencyRank];
    SLA_Milestone__c next = pickNext(milestones);
    this.nextMilestone = next == null ? null : new SlaMilestoneView(next);
  }

  /** Most urgent first; then the nearest deadline; then the case number. */
  public Integer compareTo(Object other) {
    CaseQueueItem that = (CaseQueueItem) other;
    if (urgencyRank != that.urgencyRank) {
      return urgencyRank < that.urgencyRank ? -1 : 1;
    }
    Datetime mine = nextMilestone?.targetAt;
    Datetime theirs = that.nextMilestone?.targetAt;
    if (mine != theirs) {
      if (mine == null) {
        return 1;
      }
      if (theirs == null) {
        return -1;
      }
      return mine < theirs ? -1 : 1;
    }
    String myNumber = caseNumber == null ? '' : caseNumber;
    String theirNumber = that.caseNumber == null ? '' : that.caseNumber;
    return myNumber.compareTo(theirNumber);
  }

  private static Integer rankOf(
    List<SLA_Milestone__c> milestones,
    Datetime now
  ) {
    Boolean anyRunning = false;
    Boolean anyPaused = false;
    Boolean anyAtRisk = false;

    for (SLA_Milestone__c milestone : milestones) {
      if (SlaMilestoneCalculator.isCompleted(milestone)) {
        continue;
      }
      if (milestone.Status__c == SlaConstants.MILESTONE_PAUSED) {
        anyPaused = true;
        continue;
      }
      anyRunning = true;
      Boolean pastTarget =
        milestone.Target_At__c != null &&
        now > milestone.Target_At__c;
      if (
        milestone.Status__c == SlaConstants.MILESTONE_BREACHED || pastTarget
      ) {
        return RANK_BREACHED;
      }
      Boolean pastAtRisk =
        milestone.At_Risk_At__c != null &&
        now >= milestone.At_Risk_At__c;
      if (milestone.Status__c == SlaConstants.MILESTONE_AT_RISK || pastAtRisk) {
        anyAtRisk = true;
      }
    }

    if (anyAtRisk) {
      return RANK_AT_RISK;
    }
    if (anyRunning) {
      return RANK_ON_TRACK;
    }
    if (anyPaused) {
      return RANK_PAUSED;
    }
    return RANK_NO_SLA;
  }

  /** The running milestone with the nearest deadline; a paused one only when none is running. */
  private static SLA_Milestone__c pickNext(List<SLA_Milestone__c> milestones) {
    SLA_Milestone__c nextRunning;
    SLA_Milestone__c nextPaused;
    for (SLA_Milestone__c milestone : milestones) {
      if (SlaMilestoneCalculator.isCompleted(milestone)) {
        continue;
      }
      if (milestone.Status__c == SlaConstants.MILESTONE_PAUSED) {
        nextPaused = earlier(nextPaused, milestone);
      } else {
        nextRunning = earlier(nextRunning, milestone);
      }
    }
    return nextRunning != null ? nextRunning : nextPaused;
  }

  private static SLA_Milestone__c earlier(
    SLA_Milestone__c current,
    SLA_Milestone__c candidate
  ) {
    if (current == null) {
      return candidate;
    }
    if (
      candidate.Target_At__c != null &&
      (current.Target_At__c == null ||
      candidate.Target_At__c < current.Target_At__c)
    ) {
      return candidate;
    }
    return current;
  }
}
