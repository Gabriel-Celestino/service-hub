/**
 * Assigns new cases to a queue, using the rules in Routing_Rule__mdt and the
 * support tier of the case's account. Runs in before insert, so it only sets
 * OwnerId and performs no DML.
 */
public inherited sharing class CaseRoutingService {
  public static void assignQueues(List<Case> cases) {
    if (cases == null || cases.isEmpty()) {
      return;
    }

    Map<Id, Account> accountsById = new AccountSelector()
      .selectByIds(collectAccountIds(cases));
    CaseRouter router = new CaseRouter(
      new RoutingRuleSelector().selectAllOrdered()
    );

    List<String> queueNames = new List<String>();
    for (Case record : cases) {
      Account parentAccount = accountsById.get(record.AccountId);
      String supportTier = parentAccount == null
        ? null
        : parentAccount.Support_Tier__c;
      queueNames.add(router.resolveQueue(record.Category__c, supportTier));
    }

    Map<String, Id> queueIdsByName = new QueueSelector()
      .selectIdsByDeveloperName(new Set<String>(queueNames));
    for (Integer i = 0; i < cases.size(); i++) {
      Id queueId = queueIdsByName.get(queueNames[i]);
      if (queueId == null) {
        System.debug(
          LoggingLevel.WARN,
          'Routing: queue not found: ' + queueNames[i]
        );
        continue;
      }
      cases[i].OwnerId = queueId;
    }
  }

  private static Set<Id> collectAccountIds(List<Case> cases) {
    Set<Id> accountIds = new Set<Id>();
    for (Case record : cases) {
      if (record.AccountId != null) {
        accountIds.add(record.AccountId);
      }
    }
    return accountIds;
  }
}
