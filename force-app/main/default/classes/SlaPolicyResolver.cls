/**
 * Finds the SLA policy for a support tier and case priority. Cases without an
 * account use the Standard tier; cases without a priority use Medium.
 */
public inherited sharing class SlaPolicyResolver {
  public static final String DEFAULT_TIER = 'Standard';
  public static final String DEFAULT_PRIORITY = 'Medium';

  private final Map<String, SLA_Policy__mdt> policiesByKey = new Map<String, SLA_Policy__mdt>();

  public SlaPolicyResolver(List<SLA_Policy__mdt> policies) {
    if (policies == null) {
      return;
    }
    for (SLA_Policy__mdt policy : policies) {
      policiesByKey.put(
        key(policy.Support_Tier__c, policy.Priority__c),
        policy
      );
    }
  }

  /** Returns the matching policy, or null when none is configured. */
  public SLA_Policy__mdt resolve(String supportTier, String priority) {
    String tier = String.isBlank(supportTier) ? DEFAULT_TIER : supportTier;
    String effectivePriority = String.isBlank(priority)
      ? DEFAULT_PRIORITY
      : priority;
    return policiesByKey.get(key(tier, effectivePriority));
  }

  private static String key(String supportTier, String priority) {
    return (supportTier + '|' + priority).toLowerCase();
  }
}
