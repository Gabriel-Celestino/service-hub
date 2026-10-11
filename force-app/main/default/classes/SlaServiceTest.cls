/**
 * End-to-end SLA tests through CaseTrigger, using the deployed SLA policies
 * and Business Hours. Enterprise accounts use the 24x7 calendar, so their
 * deadlines are exact minute offsets from the case creation time.
 */
@IsTest
private class SlaServiceTest {
  private static Case insertCase(String supportTier, String priority) {
    Id accountId = supportTier == null
      ? null
      : TestDataFactory.createAccount(supportTier).Id;
    Case record = TestDataFactory.buildCase(accountId, 'Technical', priority);
    insert record;
    return reloadCase(record.Id);
  }

  private static Case reloadCase(Id caseId) {
    return [
      SELECT Id, CreatedDate, Status, SLA_Status__c, First_Response_At__c
      FROM Case
      WHERE Id = :caseId
    ];
  }

  private static SLA_Milestone__c milestoneOf(Id caseId, String milestoneType) {
    return [
      SELECT
        Status__c,
        Target_At__c,
        At_Risk_At__c,
        Completed_At__c,
        Paused_Since__c,
        Paused_Minutes__c
      FROM SLA_Milestone__c
      WHERE Case__c = :caseId AND Type__c = :milestoneType
    ];
  }

  private static void updateCase(
    Id caseId,
    String status,
    String priority,
    Datetime atTime
  ) {
    SlaService.nowOverride = atTime;
    Case changes = new Case(Id = caseId);
    if (status != null) {
      changes.Status = status;
    }
    if (priority != null) {
      changes.Priority = priority;
    }
    update changes;
  }

  @IsTest
  static void createsBothMilestonesFromThePolicy() {
    Test.startTest();
    Case record = insertCase('Enterprise', 'Critical');
    Test.stopTest();

    SLA_Milestone__c firstResponse = milestoneOf(
      record.Id,
      SlaConstants.TYPE_FIRST_RESPONSE
    );
    SLA_Milestone__c resolution = milestoneOf(
      record.Id,
      SlaConstants.TYPE_RESOLUTION
    );

    Assert.areEqual(
      SlaConstants.SLA_ON_TRACK,
      record.SLA_Status__c,
      'A new case starts on track'
    );
    Assert.areEqual(
      record.CreatedDate.addMinutes(30),
      firstResponse.Target_At__c,
      'Enterprise Critical: 30 minutes'
    );
    Assert.areEqual(
      record.CreatedDate.addMinutes(22),
      firstResponse.At_Risk_At__c,
      '75% of 30, rounded down'
    );
    Assert.areEqual(
      record.CreatedDate.addMinutes(240),
      resolution.Target_At__c,
      'Enterprise Critical: 240 minutes'
    );
    Assert.areEqual(
      SlaConstants.MILESTONE_OPEN,
      resolution.Status__c,
      'Milestones start open'
    );
  }

  @IsTest
  static void caseWithoutAccountUsesStandardPolicyAndDefaultHours() {
    Test.startTest();
    Case record = insertCase(null, 'Low');
    Test.stopTest();

    Id defaultHoursId = [
      SELECT Id
      FROM BusinessHours
      WHERE Name = 'Default' AND IsActive = TRUE
      LIMIT 1
    ]
    .Id;
    Datetime expected = BusinessHours.add(
      defaultHoursId,
      record.CreatedDate,
      480 * 60000L
    );
    Assert.areEqual(
      expected,
      milestoneOf(record.Id, SlaConstants.TYPE_FIRST_RESPONSE).Target_At__c,
      'Standard Low: 480 business minutes on the Default calendar'
    );
  }

  @IsTest
  static void firstResponseIsMetWhenTheCaseLeavesNewInTime() {
    Case record = insertCase('Enterprise', 'Critical');
    Datetime respondedAt = record.CreatedDate.addMinutes(10);

    Test.startTest();
    updateCase(record.Id, 'In Progress', null, respondedAt);
    Test.stopTest();

    SLA_Milestone__c firstResponse = milestoneOf(
      record.Id,
      SlaConstants.TYPE_FIRST_RESPONSE
    );
    Case saved = reloadCase(record.Id);
    Assert.areEqual(
      SlaConstants.MILESTONE_MET,
      firstResponse.Status__c,
      'Responded within 30 minutes'
    );
    Assert.areEqual(
      respondedAt,
      firstResponse.Completed_At__c,
      'Completion time recorded'
    );
    Assert.areEqual(
      respondedAt,
      saved.First_Response_At__c,
      'Case stamped with the first response time'
    );
    Assert.areEqual(
      SlaConstants.MILESTONE_OPEN,
      milestoneOf(record.Id, SlaConstants.TYPE_RESOLUTION).Status__c,
      'Resolution keeps running'
    );
    Assert.areEqual(
      SlaConstants.SLA_ON_TRACK,
      saved.SLA_Status__c,
      'Case still on track'
    );
  }

  @IsTest
  static void lateFirstResponseIsBreached() {
    Case record = insertCase('Enterprise', 'Critical');

    Test.startTest();
    updateCase(record.Id, 'In Progress', null, record.CreatedDate.addHours(24));
    Test.stopTest();

    Assert.areEqual(
      SlaConstants.MILESTONE_BREACHED,
      milestoneOf(record.Id, SlaConstants.TYPE_FIRST_RESPONSE).Status__c,
      'Responded after 30 minutes'
    );
    Assert.areEqual(
      SlaConstants.SLA_BREACHED,
      reloadCase(record.Id).SLA_Status__c,
      'Case shows the breach'
    );
  }

  @IsTest
  static void waitingOnCustomerPausesAndResumesTheClock() {
    Case record = insertCase('Enterprise', 'Critical');

    Test.startTest();
    updateCase(
      record.Id,
      SlaConstants.CASE_STATUS_WAITING,
      null,
      record.CreatedDate.addMinutes(10)
    );
    SLA_Milestone__c paused = milestoneOf(
      record.Id,
      SlaConstants.TYPE_RESOLUTION
    );
    String statusWhilePaused = reloadCase(record.Id).SLA_Status__c;

    updateCase(
      record.Id,
      'In Progress',
      null,
      record.CreatedDate.addMinutes(70)
    );
    Test.stopTest();

    Assert.areEqual(
      SlaConstants.MILESTONE_PAUSED,
      paused.Status__c,
      'Resolution paused while waiting'
    );
    Assert.areEqual(
      SlaConstants.SLA_PAUSED,
      statusWhilePaused,
      'Case shows the pause'
    );

    SLA_Milestone__c resumed = milestoneOf(
      record.Id,
      SlaConstants.TYPE_RESOLUTION
    );
    Assert.areEqual(
      SlaConstants.MILESTONE_OPEN,
      resumed.Status__c,
      'Clock running again'
    );
    Assert.areEqual(
      60,
      resumed.Paused_Minutes__c.intValue(),
      'Waited 60 minutes on a 24x7 calendar'
    );
    Assert.areEqual(
      record.CreatedDate.addMinutes(300),
      resumed.Target_At__c,
      '240 minutes plus 60 paused'
    );
    Assert.areEqual(
      SlaConstants.SLA_ON_TRACK,
      reloadCase(record.Id).SLA_Status__c,
      'Case back on track'
    );
  }

  @IsTest
  static void closingTheCaseCompletesEveryMilestone() {
    Case record = insertCase('Enterprise', 'Critical');

    Test.startTest();
    updateCase(record.Id, 'Closed', null, record.CreatedDate.addMinutes(5));
    Test.stopTest();

    Assert.areEqual(
      SlaConstants.MILESTONE_MET,
      milestoneOf(record.Id, SlaConstants.TYPE_FIRST_RESPONSE).Status__c,
      'First response met'
    );
    Assert.areEqual(
      SlaConstants.MILESTONE_MET,
      milestoneOf(record.Id, SlaConstants.TYPE_RESOLUTION).Status__c,
      'Resolution met'
    );
    Assert.areEqual(
      SlaConstants.SLA_MET,
      reloadCase(record.Id).SLA_Status__c,
      'Case SLA met'
    );
  }

  @IsTest
  static void priorityChangeRecalculatesOpenMilestones() {
    Case record = insertCase('Enterprise', 'Medium');

    Test.startTest();
    updateCase(record.Id, null, 'Critical', record.CreatedDate.addMinutes(1));
    Test.stopTest();

    Assert.areEqual(
      record.CreatedDate.addMinutes(30),
      milestoneOf(record.Id, SlaConstants.TYPE_FIRST_RESPONSE).Target_At__c,
      'Critical first response is 30 minutes instead of 120'
    );
    Assert.areEqual(
      record.CreatedDate.addMinutes(240),
      milestoneOf(record.Id, SlaConstants.TYPE_RESOLUTION).Target_At__c,
      'Critical resolution is 240 minutes instead of 960'
    );
  }

  @IsTest
  static void handlesBulkInsertAndUpdateOf200Cases() {
    Account customer = TestDataFactory.createAccount('Premium');
    List<Case> cases = TestDataFactory.buildCases(customer.Id, 'Billing', 200);

    Test.startTest();
    insert cases;
    for (Case record : cases) {
      record.Status = 'In Progress';
    }
    update cases;
    Test.stopTest();

    Assert.areEqual(
      400,
      [SELECT COUNT() FROM SLA_Milestone__c],
      'Two milestones per case'
    );
    Assert.areEqual(
      200,
      [
        SELECT COUNT()
        FROM SLA_Milestone__c
        WHERE
          Completed_At__c != NULL
          AND Type__c = :SlaConstants.TYPE_FIRST_RESPONSE
      ],
      'Every first response completed'
    );
  }

  @IsTest
  static void unrelatedChangesLeaveMilestonesAlone() {
    Case record = insertCase('Standard', 'High');
    SLA_Milestone__c original = milestoneOf(
      record.Id,
      SlaConstants.TYPE_RESOLUTION
    );

    Test.startTest();
    update new Case(Id = record.Id, Subject = 'New subject');
    Test.stopTest();

    SLA_Milestone__c afterUpdate = milestoneOf(
      record.Id,
      SlaConstants.TYPE_RESOLUTION
    );
    Assert.areEqual(
      original.Target_At__c,
      afterUpdate.Target_At__c,
      'Target unchanged'
    );
    Assert.areEqual(
      original.Status__c,
      afterUpdate.Status__c,
      'Status unchanged'
    );
  }

  @IsTest
  static void selectorsReturnEmptyResultsForEmptyInput() {
    Assert.isTrue(
      new BusinessHoursSelector()
        .selectActiveIdsByName(new Set<String>())
        .isEmpty(),
      'No names should return no Business Hours'
    );
    Assert.isTrue(
      new SlaMilestoneSelector().selectByCaseIds(new Set<Id>()).isEmpty(),
      'No case ids should return no milestones'
    );
  }
}
