/**
 * End-to-end escalation tests. Enterprise Critical cases use the 24x7
 * calendar: first response is at risk at minute 22 and breached after
 * minute 30.
 */
@IsTest
private class SlaEscalationBatchTest {
  private static Case insertEnterpriseCriticalCase() {
    Account customer = TestDataFactory.createAccount('Enterprise');
    Case record = TestDataFactory.buildCase(
      customer.Id,
      'Technical',
      'Critical'
    );
    insert record;
    return reloadCase(record.Id);
  }

  private static Case reloadCase(Id caseId) {
    return [
      SELECT Id, CreatedDate, OwnerId, Escalation_Level__c, SLA_Status__c
      FROM Case
      WHERE Id = :caseId
    ];
  }

  private static List<SLA_Milestone__c> runningMilestones(Id caseId) {
    return [
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
      WHERE Case__c = :caseId AND Completed_At__c = NULL
    ];
  }

  private static String firstResponseStatus(Id caseId) {
    return [
      SELECT Status__c
      FROM SLA_Milestone__c
      WHERE Case__c = :caseId AND Type__c = :SlaConstants.TYPE_FIRST_RESPONSE
    ]
    .Status__c;
  }

  private static void runBatch(Datetime asOf) {
    Test.startTest();
    Database.executeBatch(new SlaEscalationBatch(asOf));
    Test.stopTest();
  }

  @IsTest
  static void atRiskCaseEscalatesToLevelOne() {
    Case record = insertEnterpriseCriticalCase();

    runBatch(record.CreatedDate.addMinutes(25));

    Case saved = reloadCase(record.Id);
    Escalation__c escalation = [
      SELECT Level__c, Reason__c, Target_Queue__c
      FROM Escalation__c
      WHERE Case__c = :record.Id
    ];
    Assert.areEqual(
      SlaConstants.MILESTONE_AT_RISK,
      firstResponseStatus(record.Id),
      'Past 75% of 30 minutes'
    );
    Assert.areEqual(1, saved.Escalation_Level__c.intValue(), 'Case at level 1');
    Assert.areEqual(
      SlaConstants.SLA_AT_RISK,
      saved.SLA_Status__c,
      'Case shows the risk'
    );
    Assert.areEqual(
      EscalationPolicy.REASON_AT_RISK,
      escalation.Reason__c,
      'Audit record explains why'
    );
    Assert.isNull(escalation.Target_Queue__c, 'Level 1 does not move the case');
    Assert.areEqual(
      record.OwnerId,
      saved.OwnerId,
      'Owner unchanged at level 1'
    );
  }

  @IsTest
  static void breachedCaseMovesToTierTwo() {
    Case record = insertEnterpriseCriticalCase();

    runBatch(record.CreatedDate.addMinutes(31));

    Case saved = reloadCase(record.Id);
    Escalation__c escalation = [
      SELECT Level__c, Reason__c, Target_Queue__c
      FROM Escalation__c
      WHERE Case__c = :record.Id
    ];
    Assert.areEqual(
      SlaConstants.MILESTONE_BREACHED,
      firstResponseStatus(record.Id),
      'Past the 30-minute target'
    );
    Assert.areEqual(2, saved.Escalation_Level__c.intValue(), 'Case at level 2');
    Assert.areEqual(
      SlaConstants.SLA_BREACHED,
      saved.SLA_Status__c,
      'Case shows the breach'
    );
    Assert.areEqual(
      EscalationPolicy.REASON_BREACHED,
      escalation.Reason__c,
      'Audit record explains why'
    );
    Assert.areEqual(
      EscalationPolicy.TIER2_QUEUE,
      escalation.Target_Queue__c,
      'Audit record names the queue'
    );
    Assert.areEqual(
      TestDataFactory.queueId(EscalationPolicy.TIER2_QUEUE),
      saved.OwnerId,
      'Case moved to Tier 2'
    );
  }

  @IsTest
  static void escalatesStepByStepAndKeepsTheTrail() {
    Case record = insertEnterpriseCriticalCase();
    SlaEscalationService.escalate(
      runningMilestones(record.Id),
      record.CreatedDate.addMinutes(25)
    );

    runBatch(record.CreatedDate.addMinutes(31));

    List<Escalation__c> trail = [
      SELECT Level__c
      FROM Escalation__c
      WHERE Case__c = :record.Id
      ORDER BY Level__c
    ];
    Assert.areEqual(2, trail.size(), 'One audit record per level');
    Assert.areEqual(1, trail[0].Level__c.intValue(), 'First level 1');
    Assert.areEqual(2, trail[1].Level__c.intValue(), 'Then level 2');
  }

  @IsTest
  static void sameLevelIsNeverEscalatedTwice() {
    Case record = insertEnterpriseCriticalCase();
    SlaEscalationService.escalate(
      runningMilestones(record.Id),
      record.CreatedDate.addMinutes(23)
    );

    Test.startTest();
    SlaEscalationService.escalate(
      runningMilestones(record.Id),
      record.CreatedDate.addMinutes(26)
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Escalation__c WHERE Case__c = :record.Id],
      'Still at level 1, no new record'
    );
  }

  @IsTest
  static void pausedClocksAreNeverEscalated() {
    Case record = insertEnterpriseCriticalCase();
    SlaService.nowOverride = record.CreatedDate.addMinutes(5);
    update new Case(Id = record.Id, Status = SlaConstants.CASE_STATUS_WAITING);

    runBatch(record.CreatedDate.addMinutes(600));

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Escalation__c WHERE Case__c = :record.Id],
      'Waiting on customer: no escalation'
    );
    Assert.areEqual(
      0,
      reloadCase(record.Id).Escalation_Level__c.intValue(),
      'Level unchanged'
    );
  }

  @IsTest
  static void escalatesBulkOf200Cases() {
    Account customer = TestDataFactory.createAccount('Enterprise');
    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < 200; i++) {
      cases.add(TestDataFactory.buildCase(customer.Id, 'Billing', 'Critical'));
    }
    insert cases;

    runBatch(System.now().addMinutes(25));

    Assert.areEqual(
      200,
      [SELECT COUNT() FROM Escalation__c],
      'One escalation per case'
    );
    Assert.areEqual(
      200,
      [SELECT COUNT() FROM Case WHERE Escalation_Level__c = 1],
      'Every case at level 1'
    );
  }

  @IsTest
  static void ignoresEmptyInput() {
    SlaEscalationService.escalate(new List<SLA_Milestone__c>(), System.now());
    SlaEscalationService.escalate(null, System.now());

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Escalation__c],
      'Nothing to escalate'
    );
    Assert.isTrue(
      new CaseSelector().selectByIds(new Set<Id>()).isEmpty(),
      'No ids, no cases'
    );
  }

  @IsTest
  static void schedulesFourJobsPerHour() {
    List<Id> jobIds = SlaEscalationBatch.scheduleEvery15Minutes();

    Assert.areEqual(
      4,
      [SELECT COUNT() FROM CronTrigger WHERE Id IN :jobIds],
      'Jobs at minutes 0, 15, 30 and 45'
    );
  }

  @IsTest
  static void scheduledRunStartsTheBatch() {
    Test.startTest();
    new SlaEscalationBatch().execute((SchedulableContext) null);
    Test.stopTest();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM AsyncApexJob
        WHERE JobType = 'BatchApex' AND ApexClass.Name = 'SlaEscalationBatch'
      ],
      'The schedule enqueues one batch'
    );
  }
}
