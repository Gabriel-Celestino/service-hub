@IsTest
private class CaseEscalatedEventsTest {
  @IsTest
  static void copiesTheEscalationAndCaseIdentifiers() {
    Account customer = TestDataFactory.createAccount('Enterprise');
    Case record = TestDataFactory.buildCase(
      customer.Id,
      'Technical',
      'Critical'
    );
    record.External_Id__c = 'WEB-77';
    insert record;
    Case saved = [
      SELECT Id, CaseNumber, External_Id__c
      FROM Case
      WHERE Id = :record.Id
    ];
    Escalation__c escalation = new Escalation__c(
      Case__c = saved.Id,
      Level__c = 2,
      Reason__c = 'SLA Breached'
    );

    Test.startTest();
    Case_Escalated__e event = CaseEscalatedEvents.build(escalation, saved);
    Test.stopTest();

    Assert.areEqual(saved.Id, event.Case_Id__c, 'Case id');
    Assert.areEqual(
      saved.CaseNumber,
      event.Case_Number__c,
      'Case number for the customer'
    );
    Assert.areEqual('WEB-77', event.External_Id__c, 'Portal id');
    Assert.areEqual(2, event.Level__c.intValue(), 'Level');
    Assert.areEqual('SLA Breached', event.Reason__c, 'Reason');
    Assert.areEqual(
      36,
      event.Correlation_Id__c.length(),
      'Unique correlation id'
    );
  }
}
