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

  /** Accounts of the given cases. Cases without an account are skipped. */
  public Map<Id, Account> selectByCases(List<Case> cases) {
    Set<Id> accountIds = new Set<Id>();
    for (Case record : cases) {
      if (record.AccountId != null) {
        accountIds.add(record.AccountId);
      }
    }
    return selectByIds(accountIds);
  }
}
