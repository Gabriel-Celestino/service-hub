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
      ORDER BY Case__c, Type__c
    ]) {
      if (!milestonesByCaseId.containsKey(milestone.Case__c)) {
        milestonesByCaseId.put(milestone.Case__c, new List<SLA_Milestone__c>());
      }
      milestonesByCaseId.get(milestone.Case__c).add(milestone);
    }
    return milestonesByCaseId;
  }
}
