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

  /** The case as the current user sees it: sharing, object and field access enforced. */
  public Case selectVisibleById(Id caseId) {
    List<Case> cases = [
      SELECT Id, SLA_Status__c, Escalation_Level__c
      FROM Case
      WHERE Id = :caseId
      WITH USER_MODE
    ];
    return cases.isEmpty() ? null : cases[0];
  }

  /**
   * Open cases for the queue console, with their running milestones, as the
   * current user sees them (user mode).
   *
   * @param ownerIds restrict to these owners; null means any owner
   */
  public List<Case> selectOpenForConsole(Set<Id> ownerIds, Integer maxRows) {
    String soql =
      'SELECT Id, CaseNumber, Subject, Priority, Status, SLA_Status__c, Escalation_Level__c, ' +
      'OwnerId, Account.Name, ' +
      '(SELECT Id, Type__c, Status__c, Target_At__c, At_Risk_At__c, Completed_At__c, Paused_Since__c, Paused_Minutes__c ' +
      'FROM SLA_Milestones__r WHERE Completed_At__c = NULL ORDER BY Target_At__c) ' +
      'FROM Case WHERE IsClosed = FALSE';
    Map<String, Object> binds = new Map<String, Object>();
    if (ownerIds != null) {
      soql += ' AND OwnerId IN :ownerIds';
      binds.put('ownerIds', ownerIds);
    }
    soql += ' ORDER BY CreatedDate DESC LIMIT ' + Integer.valueOf(maxRows);
    return (List<Case>) Database.queryWithBinds(
      soql,
      binds,
      AccessLevel.USER_MODE
    );
  }
}
