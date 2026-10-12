/**
 * Pure tests: cases and milestones are built in memory, at a fixed moment.
 */
@IsTest
private class CaseQueueItemTest {
  private static final Datetime NOW = Datetime.newInstanceGmt(
    2026,
    1,
    5,
    12,
    0,
    0
  );

  /** CaseNumber is read-only, so the case is built from JSON. */
  private static Case caseNumbered(String caseNumber) {
    return (Case) JSON.deserialize(
      '{"attributes":{"type":"Case"},"CaseNumber":"' +
        caseNumber +
        '","Subject":"Test","Priority":"High"}',
      Case.class
    );
  }

  private static SLA_Milestone__c milestone(
    String status,
    Integer atRiskInMinutes,
    Integer targetInMinutes
  ) {
    return new SLA_Milestone__c(
      Type__c = SlaConstants.TYPE_FIRST_RESPONSE,
      Status__c = status,
      At_Risk_At__c = NOW.addMinutes(atRiskInMinutes),
      Target_At__c = NOW.addMinutes(targetInMinutes)
    );
  }

  private static CaseQueueItem item(
    String caseNumber,
    List<SLA_Milestone__c> milestones
  ) {
    return new CaseQueueItem(
      caseNumbered(caseNumber),
      milestones,
      'Billing Support',
      NOW
    );
  }

  @IsTest
  static void runningClockPastTargetIsBreached() {
    CaseQueueItem result = item(
      '1',
      new List<SLA_Milestone__c>{ milestone('Open', -20, -5) }
    );

    Assert.areEqual(
      CaseQueueItem.RANK_BREACHED,
      result.urgencyRank,
      'Past the target'
    );
    Assert.areEqual('Breached', result.urgency, 'Label for the UI');
  }

  @IsTest
  static void runningClockPastAtRiskPointIsAtRisk() {
    CaseQueueItem result = item(
      '1',
      new List<SLA_Milestone__c>{ milestone('Open', -2, 10) }
    );

    Assert.areEqual(
      CaseQueueItem.RANK_AT_RISK,
      result.urgencyRank,
      'Between at risk and target'
    );
  }

  @IsTest
  static void runningClockBeforeAtRiskPointIsOnTrack() {
    CaseQueueItem result = item(
      '1',
      new List<SLA_Milestone__c>{ milestone('Open', 20, 30) }
    );

    Assert.areEqual(
      CaseQueueItem.RANK_ON_TRACK,
      result.urgencyRank,
      'Plenty of time'
    );
    Assert.areEqual(
      NOW.addMinutes(30),
      result.nextMilestone.targetAt,
      'Next deadline exposed'
    );
  }

  @IsTest
  static void onlyPausedClocksArePaused() {
    CaseQueueItem result = item(
      '1',
      new List<SLA_Milestone__c>{ milestone('Paused', -20, -5) }
    );

    Assert.areEqual(
      CaseQueueItem.RANK_PAUSED,
      result.urgencyRank,
      'A paused clock cannot breach'
    );
  }

  @IsTest
  static void caseWithoutMilestonesHasNoSla() {
    CaseQueueItem result = item('1', null);

    Assert.areEqual(
      CaseQueueItem.RANK_NO_SLA,
      result.urgencyRank,
      'No milestones'
    );
    Assert.isNull(result.nextMilestone, 'Nothing to count down');
  }

  @IsTest
  static void nextMilestoneIsTheNearestRunningOne() {
    SLA_Milestone__c paused = milestone('Paused', 1, 2);
    SLA_Milestone__c later = milestone('Open', 200, 240);
    SLA_Milestone__c sooner = milestone('Open', 20, 30);

    CaseQueueItem result = item(
      '1',
      new List<SLA_Milestone__c>{ paused, later, sooner }
    );

    Assert.areEqual(
      NOW.addMinutes(30),
      result.nextMilestone.targetAt,
      'Running clocks come before paused ones'
    );
  }

  @IsTest
  static void sortsByUrgencyThenDeadlineThenNumber() {
    List<CaseQueueItem> items = new List<CaseQueueItem>{
      item(
        '00001005',
        new List<SLA_Milestone__c>{ milestone('Paused', -20, -5) }
      ),
      item(
        '00001004',
        new List<SLA_Milestone__c>{ milestone('Open', 100, 120) }
      ),
      item('00001003', new List<SLA_Milestone__c>{ milestone('Open', 20, 30) }),
      item('00001002', new List<SLA_Milestone__c>{ milestone('Open', -2, 10) }),
      item(
        '00001001',
        new List<SLA_Milestone__c>{ milestone('Open', -20, -5) }
      ),
      item('00001000', new List<SLA_Milestone__c>{ milestone('Open', 20, 30) })
    };

    items.sort();

    List<String> order = new List<String>();
    for (CaseQueueItem row : items) {
      order.add(row.caseNumber);
    }
    Assert.areEqual(
      new List<String>{
        '00001001',
        '00001002',
        '00001000',
        '00001003',
        '00001004',
        '00001005'
      },
      order,
      'Breached, at risk, on track by deadline (ties by number), then paused'
    );
  }
}
