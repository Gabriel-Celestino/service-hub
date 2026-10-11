@IsTest
private class SlaPolicyResolverTest {
  private static SLA_Policy__mdt policy(
    String supportTier,
    String priority,
    Integer firstResponseMinutes
  ) {
    return new SLA_Policy__mdt(
      Support_Tier__c = supportTier,
      Priority__c = priority,
      First_Response_Minutes__c = firstResponseMinutes
    );
  }

  private static SlaPolicyResolver resolver() {
    return new SlaPolicyResolver(
      new List<SLA_Policy__mdt>{
        policy('Enterprise', 'Critical', 30),
        policy('Standard', 'Medium', 360),
        policy('Standard', 'Low', 480)
      }
    );
  }

  @IsTest
  static void resolvesByTierAndPriority() {
    Assert.areEqual(
      30,
      resolver()
        .resolve('Enterprise', 'Critical')
        .First_Response_Minutes__c.intValue(),
      'Exact match'
    );
  }

  @IsTest
  static void matchingIgnoresCase() {
    Assert.areEqual(
      30,
      resolver()
        .resolve('enterprise', 'CRITICAL')
        .First_Response_Minutes__c.intValue(),
      'Case-insensitive'
    );
  }

  @IsTest
  static void blankTierUsesStandard() {
    Assert.areEqual(
      480,
      resolver().resolve(null, 'Low').First_Response_Minutes__c.intValue(),
      'No account means Standard'
    );
  }

  @IsTest
  static void blankPriorityUsesMedium() {
    Assert.areEqual(
      360,
      resolver().resolve('Standard', '').First_Response_Minutes__c.intValue(),
      'No priority means Medium'
    );
  }

  @IsTest
  static void unknownCombinationReturnsNull() {
    Assert.isNull(
      resolver().resolve('Premium', 'High'),
      'No policy configured'
    );
    Assert.isNull(
      new SlaPolicyResolver(null).resolve('Standard', 'Low'),
      'No policies at all'
    );
  }
}
