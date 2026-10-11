/**
 * Domain logic for case routing: decides which queue a case belongs to.
 *
 * Pure logic with no SOQL or DML. Rules must be given in evaluation order
 * (Sort_Order__c ascending); the first matching rule wins. A rule with an
 * empty support tier matches any tier.
 */
public inherited sharing class CaseRouter {
  public static final String FALLBACK_QUEUE = 'General_Support';

  private final List<Routing_Rule__mdt> rules;

  public CaseRouter(List<Routing_Rule__mdt> rules) {
    this.rules = rules == null ? new List<Routing_Rule__mdt>() : rules;
  }

  /**
   * Returns the DeveloperName of the queue for a case with the given
   * category and account support tier.
   */
  public String resolveQueue(String category, String supportTier) {
    if (String.isBlank(category)) {
      return FALLBACK_QUEUE;
    }
    for (Routing_Rule__mdt rule : rules) {
      if (matches(rule, category, supportTier)) {
        return rule.Target_Queue__c;
      }
    }
    return FALLBACK_QUEUE;
  }

  private static Boolean matches(
    Routing_Rule__mdt rule,
    String category,
    String supportTier
  ) {
    Boolean categoryMatches = rule.Category__c == category;
    Boolean tierMatches =
      String.isBlank(rule.Support_Tier__c) ||
      rule.Support_Tier__c == supportTier;
    return categoryMatches && tierMatches;
  }
}
