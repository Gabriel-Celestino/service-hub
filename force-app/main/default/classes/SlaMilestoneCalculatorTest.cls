/**
 * Domain tests with a wall clock (every minute is a business minute), so
 * expected deadlines are plain arithmetic.
 */
@IsTest
private class SlaMilestoneCalculatorTest {
  private static final Datetime START = Datetime.newInstanceGmt(
    2026,
    1,
    5,
    12,
    0,
    0
  );

  private class WallClock implements BusinessClock {
    public Datetime addMinutes(
      Id businessHoursId,
      Datetime startTime,
      Integer minutes
    ) {
      return startTime.addMinutes(minutes);
    }
    public Integer minutesBetween(
      Id businessHoursId,
      Datetime startTime,
      Datetime endTime
    ) {
      return ((endTime.getTime() - startTime.getTime()) / 60000L).intValue();
    }
  }

  private static SlaMilestoneCalculator calculator() {
    return new SlaMilestoneCalculator(new WallClock());
  }

  private static SLA_Policy__mdt policy() {
    return new SLA_Policy__mdt(
      First_Response_Minutes__c = 30,
      Resolution_Minutes__c = 240,
      At_Risk_Percent__c = 75
    );
  }

  private static SLA_Milestone__c milestone(String milestoneType) {
    SLA_Milestone__c record = new SLA_Milestone__c(
      Type__c = milestoneType,
      Status__c = SlaConstants.MILESTONE_OPEN,
      Paused_Minutes__c = 0
    );
    calculator().applyTargets(record, START, policy(), null);
    return record;
  }

  @IsTest
  static void appliesTargetsFromPolicy() {
    SLA_Milestone__c firstResponse = milestone(
      SlaConstants.TYPE_FIRST_RESPONSE
    );
    SLA_Milestone__c resolution = milestone(SlaConstants.TYPE_RESOLUTION);

    Assert.areEqual(
      START.addMinutes(30),
      firstResponse.Target_At__c,
      'First response target'
    );
    Assert.areEqual(
      START.addMinutes(22),
      firstResponse.At_Risk_At__c,
      '75% of 30 minutes, rounded down'
    );
    Assert.areEqual(
      START.addMinutes(240),
      resolution.Target_At__c,
      'Resolution target'
    );
    Assert.areEqual(
      START.addMinutes(180),
      resolution.At_Risk_At__c,
      '75% of 240 minutes'
    );
  }

  @IsTest
  static void missingAtRiskPercentMeansAtRiskAtTarget() {
    SLA_Policy__mdt noPercent = policy();
    noPercent.At_Risk_Percent__c = null;
    SLA_Milestone__c record = new SLA_Milestone__c(
      Type__c = SlaConstants.TYPE_FIRST_RESPONSE
    );

    calculator().applyTargets(record, START, noPercent, null);

    Assert.areEqual(
      record.Target_At__c,
      record.At_Risk_At__c,
      'Without a percent, at risk equals the target'
    );
  }

  @IsTest
  static void pauseAndResumeMovesDeadlinesByPausedTime() {
    SlaMilestoneCalculator calculator = calculator();
    SLA_Milestone__c resolution = milestone(SlaConstants.TYPE_RESOLUTION);

    calculator.pause(resolution, START.addMinutes(10));
    Assert.areEqual(
      SlaConstants.MILESTONE_PAUSED,
      resolution.Status__c,
      'Should be paused'
    );
    Assert.areEqual(
      START.addMinutes(10),
      resolution.Paused_Since__c,
      'Should record when the pause started'
    );

    calculator.resume(resolution, START.addMinutes(70), null);
    calculator.applyTargets(resolution, START, policy(), null);

    Assert.areEqual(
      SlaConstants.MILESTONE_OPEN,
      resolution.Status__c,
      'Should run again'
    );
    Assert.areEqual(
      60,
      resolution.Paused_Minutes__c.intValue(),
      'Should add the 60 paused minutes'
    );
    Assert.isNull(resolution.Paused_Since__c, 'Pause start should be cleared');
    Assert.areEqual(
      START.addMinutes(300),
      resolution.Target_At__c,
      '240 minutes plus 60 paused'
    );
    Assert.areEqual(
      START.addMinutes(240),
      resolution.At_Risk_At__c,
      '180 minutes plus 60 paused'
    );
  }

  @IsTest
  static void pauseIgnoresCompletedAndAlreadyPausedMilestones() {
    SlaMilestoneCalculator calculator = calculator();
    SLA_Milestone__c completed = milestone(SlaConstants.TYPE_FIRST_RESPONSE);
    calculator.complete(completed, START.addMinutes(5));
    SLA_Milestone__c paused = milestone(SlaConstants.TYPE_RESOLUTION);
    calculator.pause(paused, START.addMinutes(10));

    calculator.pause(completed, START.addMinutes(20));
    calculator.pause(paused, START.addMinutes(20));

    Assert.areEqual(
      SlaConstants.MILESTONE_MET,
      completed.Status__c,
      'Completed milestone keeps its status'
    );
    Assert.areEqual(
      START.addMinutes(10),
      paused.Paused_Since__c,
      'Second pause keeps the first start'
    );
  }

  @IsTest
  static void resumeIgnoresMilestonesThatAreNotPaused() {
    SLA_Milestone__c running = milestone(SlaConstants.TYPE_RESOLUTION);

    calculator().resume(running, START.addMinutes(30), null);

    Assert.areEqual(
      0,
      running.Paused_Minutes__c.intValue(),
      'Nothing to add when the clock was running'
    );
  }

  @IsTest
  static void completingBeforeTargetIsMet() {
    SLA_Milestone__c firstResponse = milestone(
      SlaConstants.TYPE_FIRST_RESPONSE
    );

    calculator().complete(firstResponse, START.addMinutes(29));

    Assert.areEqual(
      SlaConstants.MILESTONE_MET,
      firstResponse.Status__c,
      'Done within target'
    );
    Assert.areEqual(
      START.addMinutes(29),
      firstResponse.Completed_At__c,
      'Completion time recorded'
    );
  }

  @IsTest
  static void completingAfterTargetIsBreached() {
    SLA_Milestone__c firstResponse = milestone(
      SlaConstants.TYPE_FIRST_RESPONSE
    );

    calculator().complete(firstResponse, START.addMinutes(31));

    Assert.areEqual(
      SlaConstants.MILESTONE_BREACHED,
      firstResponse.Status__c,
      'Done after target'
    );
  }

  @IsTest
  static void breachedMilestoneStaysBreachedWhenCompleted() {
    SLA_Milestone__c firstResponse = milestone(
      SlaConstants.TYPE_FIRST_RESPONSE
    );
    firstResponse.Status__c = SlaConstants.MILESTONE_BREACHED;

    calculator().complete(firstResponse, START.addMinutes(1));

    Assert.areEqual(
      SlaConstants.MILESTONE_BREACHED,
      firstResponse.Status__c,
      'A breach is never undone'
    );
  }

  @IsTest
  static void pausedMilestoneIsJudgedWhenItWasPaused() {
    SlaMilestoneCalculator calculator = calculator();
    SLA_Milestone__c firstResponse = milestone(
      SlaConstants.TYPE_FIRST_RESPONSE
    );
    calculator.pause(firstResponse, START.addMinutes(10));

    calculator.complete(firstResponse, START.addMinutes(500));

    Assert.areEqual(
      SlaConstants.MILESTONE_MET,
      firstResponse.Status__c,
      'The clock stopped at minute 10'
    );
    Assert.isNull(
      firstResponse.Paused_Since__c,
      'Pause start should be cleared'
    );
  }

  @IsTest
  static void refreshStatusFollowsTheClock() {
    SlaMilestoneCalculator calculator = calculator();
    SLA_Milestone__c firstResponse = milestone(
      SlaConstants.TYPE_FIRST_RESPONSE
    );

    calculator.refreshStatus(firstResponse, START.addMinutes(5));
    Assert.areEqual(
      SlaConstants.MILESTONE_OPEN,
      firstResponse.Status__c,
      'Before the at-risk point'
    );

    calculator.refreshStatus(firstResponse, START.addMinutes(25));
    Assert.areEqual(
      SlaConstants.MILESTONE_AT_RISK,
      firstResponse.Status__c,
      'Past 75% of the target'
    );

    calculator.refreshStatus(firstResponse, START.addMinutes(31));
    Assert.areEqual(
      SlaConstants.MILESTONE_BREACHED,
      firstResponse.Status__c,
      'Past the target'
    );
  }

  @IsTest
  static void refreshStatusIgnoresPausedMilestones() {
    SlaMilestoneCalculator calculator = calculator();
    SLA_Milestone__c firstResponse = milestone(
      SlaConstants.TYPE_FIRST_RESPONSE
    );
    calculator.pause(firstResponse, START.addMinutes(5));

    calculator.refreshStatus(firstResponse, START.addMinutes(60));

    Assert.areEqual(
      SlaConstants.MILESTONE_PAUSED,
      firstResponse.Status__c,
      'A paused clock cannot breach'
    );
  }
}
