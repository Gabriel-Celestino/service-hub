/**
 * Queries on Escalation__c.
 */
public inherited sharing class EscalationSelector {
  /** Escalation trail of one case, newest first, as the current user sees it (user mode). */
  public List<Escalation__c> selectVisibleByCaseId(Id caseId) {
    return [
      SELECT Id, Name, Level__c, Reason__c, Target_Queue__c, CreatedDate
      FROM Escalation__c
      WHERE Case__c = :caseId
      WITH USER_MODE
      ORDER BY Level__c DESC
    ];
  }
}
