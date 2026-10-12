@IsTest
private class CaseSlaControllerTest {
  private static Case insertEnterpriseCriticalCase() {
    Account customer = TestDataFactory.createAccount('Enterprise');
    Case record = TestDataFactory.buildCase(
      customer.Id,
      'Technical',
      'Critical'
    );
    insert record;
    return [SELECT Id, CreatedDate FROM Case WHERE Id = :record.Id];
  }

  @IsTest
  static void returnsMilestonesForANewCase() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      Case record = insertEnterpriseCriticalCase();

      Test.startTest();
      CaseSlaController.CaseSlaView view = CaseSlaController.getCaseSla(
        record.Id
      );
      Test.stopTest();

      Assert.areEqual(
        SlaConstants.SLA_ON_TRACK,
        view.slaStatus,
        'A new case is on track'
      );
      Assert.areEqual(0, view.escalationLevel, 'Not escalated');
      Assert.areEqual(
        2,
        view.milestones.size(),
        'First response and resolution'
      );
      Assert.areEqual(
        SlaConstants.TYPE_FIRST_RESPONSE,
        view.milestones[0].type,
        'Sorted by type'
      );
      Assert.areEqual(
        record.CreatedDate.addMinutes(30),
        view.milestones[0].targetAt,
        'Target exposed to the UI'
      );
      Assert.areEqual(0, view.milestones[0].pausedMinutes, 'No pause yet');
      Assert.isTrue(view.escalations.isEmpty(), 'No escalation trail yet');
    }
  }

  @IsTest
  static void returnsTheEscalationTrailNewestFirst() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      Case record = insertEnterpriseCriticalCase();
      List<SLA_Milestone__c> running = [
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
        WHERE Case__c = :record.Id
      ];
      SlaEscalationService.escalate(running, record.CreatedDate.addMinutes(25));
      SlaEscalationService.escalate(running, record.CreatedDate.addMinutes(31));

      Test.startTest();
      CaseSlaController.CaseSlaView view = CaseSlaController.getCaseSla(
        record.Id
      );
      Test.stopTest();

      Assert.areEqual(2, view.escalationLevel, 'Escalated to level 2');
      Assert.areEqual(2, view.escalations.size(), 'One entry per level');
      Assert.areEqual(
        2,
        view.escalations[0].level,
        'Newest (highest level) first'
      );
      Assert.areEqual(
        EscalationPolicy.REASON_BREACHED,
        view.escalations[0].reason,
        'Reason exposed'
      );
      Assert.areEqual(
        EscalationPolicy.TIER2_QUEUE,
        view.escalations[0].targetQueue,
        'Queue exposed'
      );
      Assert.isNotNull(view.escalations[0].name, 'Auto-number exposed');
    }
  }

  @IsTest
  static void failsCleanlyForAnUnknownCase() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      Account notACase = TestDataFactory.createAccount('Standard');
      try {
        CaseSlaController.getCaseSla(notACase.Id);
        Assert.fail('Expected an AuraHandledException');
      } catch (AuraHandledException error) {
        Assert.isNotNull(error.getMessage(), 'The UI gets a handled error');
      }
    }
  }
}
