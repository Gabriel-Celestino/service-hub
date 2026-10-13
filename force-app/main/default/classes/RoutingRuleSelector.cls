/**
 * Reads Routing_Rule__mdt from the metadata cache (getAll does not consume
 * SOQL queries) and returns the rules in evaluation order.
 */
public inherited sharing class RoutingRuleSelector {
  public List<Routing_Rule__mdt> selectAllOrdered() {
    List<Routing_Rule__mdt> rules = Routing_Rule__mdt.getAll().values();
    rules.sort(new BySortOrder());
    return rules;
  }

  /** Sort_Order__c ascending (empty last), then DeveloperName, so the order is stable. */
  private class BySortOrder implements Comparator<Routing_Rule__mdt> {
    public Integer compare(Routing_Rule__mdt left, Routing_Rule__mdt right) {
      Decimal leftOrder = left.Sort_Order__c;
      Decimal rightOrder = right.Sort_Order__c;
      if (leftOrder != rightOrder) {
        if (leftOrder == null) {
          return 1;
        }
        if (rightOrder == null) {
          return -1;
        }
        return leftOrder < rightOrder ? -1 : 1;
      }
      return left.DeveloperName.compareTo(right.DeveloperName);
    }
  }
}
