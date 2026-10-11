/**
 * Reads SLA_Policy__mdt. getAll() is served from the metadata cache and does
 * not consume SOQL queries.
 */
public inherited sharing class SlaPolicySelector {
  public List<SLA_Policy__mdt> selectAll() {
    return SLA_Policy__mdt.getAll().values();
  }
}
