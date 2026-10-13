/**
 * Queries on SLA_Milestone__c.
 */
public inherited sharing class SlaMilestoneSelector {
  /** All milestones of the given cases, grouped by case id. */
  public Map<Id, List<SLA_Milestone__c>> selectByCaseIds(Set<Id> caseIds) {
    Map<Id, List<SLA_Milestone__c>> milestonesByCaseId = new Map<Id, List<SLA_Milestone__c>>();
    if (caseIds == null || caseIds.isEmpty()) {
      return milestonesByCaseId;
    }
    for (SLA_Milestone__c milestone : [
      SELECT
        Id,
        Case__c,
        Type__c,
        Status__c,
        Target_At__c,
        At_Risk_At__c,
        Completed_At__c,
        Paused_Since__c,
        Paused_Minutes__c
      FROM SLA_Milestone__c
      WHERE Case__c IN :caseIds
      WITH SYSTEM_MODE
      ORDER BY Case__c, Type__c
    ]) {
      if (!milestonesByCaseId.containsKey(milestone.Case__c)) {
        milestonesByCaseId.put(milestone.Case__c, new List<SLA_Milestone__c>());
      }
      milestonesByCaseId.get(milestone.Case__c).add(milestone);
    }
    return milestonesByCaseId;
  }

  /**
   * Running milestones the escalation job must look at: Open ones past their
   * at-risk point, and At Risk ones past their target. Paused and completed
   * milestones are never due.
   */
  public Database.QueryLocator queryLocatorDueForEscalation(Datetime asOf) {
    String openStatus = SlaConstants.MILESTONE_OPEN;
    String atRiskStatus = SlaConstants.MILESTONE_AT_RISK;
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Case__c,
          Type__c,
          Status__c,
          Target_At__c,
          At_Risk_At__c,
          Completed_At__c,
          Paused_Since__c,
          Paused_Minutes__c
        FROM SLA_Milestone__c
        WHERE
          Completed_At__c = NULL
          AND ((Status__c = :openStatus
          AND At_Risk_At__c <= :asOf)
          OR (Status__c = :atRiskStatus
          AND Target_At__c < :asOf))
        WITH SYSTEM_MODE
      ]
    );
  }

  /** Milestones of one case as the current user sees them (user mode). */
  public List<SLA_Milestone__c> selectVisibleByCaseId(Id caseId) {
    return [
      SELECT
        Id,
        Type__c,
        Status__c,
        Target_At__c,
        At_Risk_At__c,
        Completed_At__c,
        Paused_Since__c,
        Paused_Minutes__c
      FROM SLA_Milestone__c
      WHERE Case__c = :caseId
      WITH USER_MODE
      ORDER BY Type__c
    ];
  }
}
