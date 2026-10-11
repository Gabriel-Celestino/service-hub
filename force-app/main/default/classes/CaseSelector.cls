/**
 * Queries on Case.
 */
public inherited sharing class CaseSelector {
  public Map<Id, Case> selectByIds(Set<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return new Map<Id, Case>();
    }
    return new Map<Id, Case>(
      [
        SELECT Id, OwnerId, Status, Escalation_Level__c, SLA_Status__c
        FROM Case
        WHERE Id IN :caseIds
      ]
    );
  }
}
