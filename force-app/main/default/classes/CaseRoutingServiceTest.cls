/**
 * End-to-end routing tests through CaseTrigger, using the Routing_Rule__mdt
 * records and queues deployed with the project.
 */
@IsTest
private class CaseRoutingServiceTest {
  @IsTest
  static void routesNewCaseByCategory() {
    Account customer = TestDataFactory.createAccount('Premium');
    Case newCase = TestDataFactory.buildCase(customer.Id, 'Billing');

    Test.startTest();
    insert newCase;
    Test.stopTest();

    Case saved = [SELECT OwnerId FROM Case WHERE Id = :newCase.Id];
    Assert.areEqual(
      TestDataFactory.queueId('Billing_Support'),
      saved.OwnerId,
      'Billing case should go to Billing Support'
    );
  }

  @IsTest
  static void routesCaseWithoutAccount() {
    Case newCase = TestDataFactory.buildCase(null, 'Technical');

    Test.startTest();
    insert newCase;
    Test.stopTest();

    Case saved = [SELECT OwnerId FROM Case WHERE Id = :newCase.Id];
    Assert.areEqual(
      TestDataFactory.queueId('Technical_Support'),
      saved.OwnerId,
      'Rules without a tier should route cases without an account'
    );
  }

  @IsTest
  static void sendsUnmatchedCaseToFallbackQueue() {
    Account customer = TestDataFactory.createAccount('Standard');
    Case newCase = TestDataFactory.buildCase(customer.Id, 'Other');

    Test.startTest();
    insert newCase;
    Test.stopTest();

    Case saved = [SELECT OwnerId FROM Case WHERE Id = :newCase.Id];
    Assert.areEqual(
      TestDataFactory.queueId(CaseRouter.FALLBACK_QUEUE),
      saved.OwnerId,
      'A case no rule matches should go to the fallback queue'
    );
  }

  @IsTest
  static void routesBulkInsertOf200Cases() {
    Account customer = TestDataFactory.createAccount('Enterprise');
    List<Case> cases = new List<Case>();
    cases.addAll(TestDataFactory.buildCases(customer.Id, 'Billing', 50));
    cases.addAll(TestDataFactory.buildCases(customer.Id, 'Technical', 50));
    cases.addAll(TestDataFactory.buildCases(customer.Id, 'Access', 50));
    cases.addAll(TestDataFactory.buildCases(customer.Id, 'Other', 50));

    Test.startTest();
    insert cases;
    Test.stopTest();

    Map<Id, Integer> casesByOwner = new Map<Id, Integer>();
    for (AggregateResult row : [
      SELECT OwnerId, COUNT(Id) caseCount
      FROM Case
      GROUP BY OwnerId
    ]) {
      casesByOwner.put((Id) row.get('OwnerId'), (Integer) row.get('caseCount'));
    }
    for (
      String queueName : new List<String>{
        'Billing_Support',
        'Technical_Support',
        'Access_Support',
        'General_Support'
      }
    ) {
      Assert.areEqual(
        50,
        casesByOwner.get(TestDataFactory.queueId(queueName)),
        queueName + ' should own 50 cases'
      );
    }
  }

  @IsTest
  static void skipsRoutingWhenHandlerIsBypassed() {
    Case newCase = TestDataFactory.buildCase(null, 'Billing');
    TriggerHandler.bypass(CaseTriggerHandler.class);

    Test.startTest();
    insert newCase;
    Test.stopTest();

    TriggerHandler.clearBypass(CaseTriggerHandler.class);
    Case saved = [SELECT OwnerId FROM Case WHERE Id = :newCase.Id];
    Assert.areEqual(
      UserInfo.getUserId(),
      saved.OwnerId,
      'A bypassed handler must not change the owner'
    );
  }
}
