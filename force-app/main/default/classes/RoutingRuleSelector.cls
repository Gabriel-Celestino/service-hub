/**
 * Queries on Routing_Rule__mdt. Custom Metadata queries do not count toward
 * the SOQL query limit.
 */
public inherited sharing class RoutingRuleSelector {
  public List<Routing_Rule__mdt> selectAllOrdered() {
    return [
      SELECT
        DeveloperName,
        Category__c,
        Support_Tier__c,
        Target_Queue__c,
        Sort_Order__c
      FROM Routing_Rule__mdt
      ORDER BY Sort_Order__c ASC
    ];
  }
}
