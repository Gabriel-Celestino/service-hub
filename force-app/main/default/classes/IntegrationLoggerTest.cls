@IsTest
private class IntegrationLoggerTest {
  @IsTest
  static void savesOutboundFailuresWithTruncatedErrors() {
    Integration_Log__c log = IntegrationLogger.outbound(
      'EventBus.publish Case_Escalated__e',
      'corr-1',
      null,
      'x'.repeat(40000)
    );

    Test.startTest();
    IntegrationLogger.save(log);
    IntegrationLogger.save(new List<Integration_Log__c>());
    Test.stopTest();

    Integration_Log__c saved = [
      SELECT Direction__c, Correlation_Id__c, Error_Message__c
      FROM Integration_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(IntegrationLogger.OUTBOUND, saved.Direction__c, 'Outbound');
    Assert.areEqual('corr-1', saved.Correlation_Id__c, 'Correlation id kept');
    Assert.areEqual(
      32768,
      saved.Error_Message__c.length(),
      'Error truncated to the field size'
    );
  }

  @IsTest
  static void logsEvenWhenTheCallerCannotSeeTheLogObject() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      Test.startTest();
      IntegrationLogger.save(
        IntegrationLogger.inbound('GET /x', 200, 'corr-2', null, null, null)
      );
      Test.stopTest();
    }

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Correlation_Id__c = 'corr-2'
        WITH SYSTEM_MODE
      ],
      'Logged in system mode'
    );
  }
}
