/**
 * Queries on Account.
 */
public inherited sharing class AccountSelector {
  public Map<Id, Account> selectByIds(Set<Id> accountIds) {
    if (accountIds == null || accountIds.isEmpty()) {
      return new Map<Id, Account>();
    }
    return new Map<Id, Account>(
      [SELECT Id, Name, Support_Tier__c FROM Account WHERE Id IN :accountIds]
    );
  }
}
