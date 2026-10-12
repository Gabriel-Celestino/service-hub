/**
 * Builds the SLA queue for the console: open cases the user can see, ranked
 * by urgency.
 */
public inherited sharing class SlaConsoleService {
  public static final String SCOPE_ALL = 'ALL';
  public static final String SCOPE_AT_RISK = 'AT_RISK';
  public static final String SCOPE_MINE = 'MINE';
  public static final Set<String> SCOPES = new Set<String>{
    SCOPE_ALL,
    SCOPE_AT_RISK,
    SCOPE_MINE
  };

  /** Cases read from the database before ranking; the console shows the top MAX_ROWS. */
  public static final Integer QUERY_LIMIT = 1000;
  public static final Integer MAX_ROWS = 200;

  /**
   * @param scope ALL, AT_RISK (at risk or breached right now) or MINE (owned by
   *        the user or by one of the user's queues)
   */
  public static List<CaseQueueItem> getQueue(
    String scope,
    Id userId,
    Datetime now
  ) {
    if (!SCOPES.contains(scope)) {
      throw new IllegalArgumentException('Unknown queue scope: ' + scope);
    }

    Set<Id> ownerIds;
    if (scope == SCOPE_MINE) {
      ownerIds = new QueueSelector().selectQueueIdsForMember(userId);
      ownerIds.add(userId);
    }

    List<Case> cases = new CaseSelector()
      .selectOpenForConsole(ownerIds, QUERY_LIMIT);
    Set<Id> caseOwnerIds = new Set<Id>();
    for (Case record : cases) {
      caseOwnerIds.add(record.OwnerId);
    }
    Map<Id, String> ownerNames = new OwnerSelector()
      .selectNamesByIds(caseOwnerIds);

    List<CaseQueueItem> items = new List<CaseQueueItem>();
    for (Case record : cases) {
      CaseQueueItem item = new CaseQueueItem(
        record,
        record.SLA_Milestones__r,
        ownerNames.get(record.OwnerId),
        now
      );
      if (
        scope == SCOPE_AT_RISK &&
        item.urgencyRank > CaseQueueItem.RANK_AT_RISK
      ) {
        continue;
      }
      items.add(item);
    }
    items.sort();

    if (items.size() <= MAX_ROWS) {
      return items;
    }
    List<CaseQueueItem> top = new List<CaseQueueItem>();
    for (Integer i = 0; i < MAX_ROWS; i++) {
      top.add(items[i]);
    }
    return top;
  }
}
