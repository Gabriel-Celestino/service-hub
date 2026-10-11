@IsTest
private class EscalationPolicyTest {
  private static SLA_Milestone__c running(String status) {
    return new SLA_Milestone__c(Status__c = status);
  }

  private static SLA_Milestone__c completedMilestone(String status) {
    return new SLA_Milestone__c(
      Status__c = status,
      Completed_At__c = System.now()
    );
  }

  @IsTest
  static void runningBreachIsLevelTwo() {
    Integer level = EscalationPolicy.levelFor(
      new List<SLA_Milestone__c>{
        running(SlaConstants.MILESTONE_AT_RISK),
        running(SlaConstants.MILESTONE_BREACHED)
      }
    );

    Assert.areEqual(
      EscalationPolicy.LEVEL_BREACHED,
      level,
      'A running breach wins'
    );
  }

  @IsTest
  static void runningAtRiskIsLevelOne() {
    Integer level = EscalationPolicy.levelFor(
      new List<SLA_Milestone__c>{
        running(SlaConstants.MILESTONE_OPEN),
        running(SlaConstants.MILESTONE_AT_RISK)
      }
    );

    Assert.areEqual(
      EscalationPolicy.LEVEL_AT_RISK,
      level,
      'At risk escalates to level 1'
    );
  }

  @IsTest
  static void completedBreachDoesNotEscalate() {
    Integer level = EscalationPolicy.levelFor(
      new List<SLA_Milestone__c>{
        completedMilestone(SlaConstants.MILESTONE_BREACHED),
        running(SlaConstants.MILESTONE_OPEN)
      }
    );

    Assert.areEqual(
      EscalationPolicy.LEVEL_NONE,
      level,
      'A past breach is history, not a reason to escalate'
    );
  }

  @IsTest
  static void noMilestonesIsLevelZero() {
    Assert.areEqual(
      EscalationPolicy.LEVEL_NONE,
      EscalationPolicy.levelFor(null),
      'Null list'
    );
    Assert.areEqual(
      EscalationPolicy.LEVEL_NONE,
      EscalationPolicy.levelFor(new List<SLA_Milestone__c>()),
      'Empty list'
    );
  }

  @IsTest
  static void reasonAndQueueFollowTheLevel() {
    Assert.areEqual(
      EscalationPolicy.REASON_AT_RISK,
      EscalationPolicy.reasonFor(1),
      'Level 1 reason'
    );
    Assert.areEqual(
      EscalationPolicy.REASON_BREACHED,
      EscalationPolicy.reasonFor(2),
      'Level 2 reason'
    );
    Assert.isNull(
      EscalationPolicy.targetQueueFor(1),
      'Level 1 keeps the owner'
    );
    Assert.areEqual(
      EscalationPolicy.TIER2_QUEUE,
      EscalationPolicy.targetQueueFor(2),
      'Level 2 goes to Tier 2'
    );
  }
}
