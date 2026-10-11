@IsTest
private class CaseRouterTest {
  private static Routing_Rule__mdt rule(
    String category,
    String supportTier,
    String targetQueue
  ) {
    return new Routing_Rule__mdt(
      Category__c = category,
      Support_Tier__c = supportTier,
      Target_Queue__c = targetQueue
    );
  }

  @IsTest
  static void returnsQueueOfMatchingRule() {
    CaseRouter router = new CaseRouter(
      new List<Routing_Rule__mdt>{
        rule('Billing', null, 'Billing_Support'),
        rule('Technical', null, 'Technical_Support')
      }
    );

    Assert.areEqual(
      'Technical_Support',
      router.resolveQueue('Technical', 'Standard'),
      'Should match by category'
    );
  }

  @IsTest
  static void firstMatchingRuleWins() {
    CaseRouter router = new CaseRouter(
      new List<Routing_Rule__mdt>{
        rule('Technical', 'Enterprise', 'Tier2_Escalations'),
        rule('Technical', null, 'Technical_Support')
      }
    );

    Assert.areEqual(
      'Tier2_Escalations',
      router.resolveQueue('Technical', 'Enterprise'),
      'The tier-specific rule comes first and should win'
    );
    Assert.areEqual(
      'Technical_Support',
      router.resolveQueue('Technical', 'Standard'),
      'Other tiers should fall through to the generic rule'
    );
  }

  @IsTest
  static void blankTierRuleMatchesCaseWithoutAccount() {
    CaseRouter router = new CaseRouter(
      new List<Routing_Rule__mdt>{ rule('Access', null, 'Access_Support') }
    );

    Assert.areEqual(
      'Access_Support',
      router.resolveQueue('Access', null),
      'Empty rule tier matches any tier'
    );
  }

  @IsTest
  static void tierSpecificRuleDoesNotMatchOtherTiers() {
    CaseRouter router = new CaseRouter(
      new List<Routing_Rule__mdt>{
        rule('Billing', 'Enterprise', 'Billing_Support')
      }
    );

    Assert.areEqual(
      CaseRouter.FALLBACK_QUEUE,
      router.resolveQueue('Billing', 'Premium'),
      'A rule for another tier must not match'
    );
  }

  @IsTest
  static void unmatchedCategoryFallsBackToGeneralQueue() {
    CaseRouter router = new CaseRouter(
      new List<Routing_Rule__mdt>{ rule('Billing', null, 'Billing_Support') }
    );

    Assert.areEqual(
      CaseRouter.FALLBACK_QUEUE,
      router.resolveQueue('Other', 'Standard'),
      'No rule should mean fallback'
    );
  }

  @IsTest
  static void blankCategoryFallsBackToGeneralQueue() {
    CaseRouter router = new CaseRouter(
      new List<Routing_Rule__mdt>{ rule('Billing', null, 'Billing_Support') }
    );

    Assert.areEqual(
      CaseRouter.FALLBACK_QUEUE,
      router.resolveQueue(null, 'Standard'),
      'No category should mean fallback'
    );
  }

  @IsTest
  static void worksWithNoRules() {
    CaseRouter router = new CaseRouter(null);

    Assert.areEqual(
      CaseRouter.FALLBACK_QUEUE,
      router.resolveQueue('Billing', 'Standard'),
      'No rules should mean fallback'
    );
  }
}
