/**
 * Queries on CaseStatus, so closed statuses come from the org's configuration
 * instead of a hard-coded list.
 */
public inherited sharing class CaseStatusSelector {
  public Set<String> selectClosedApiNames() {
    Set<String> closedStatuses = new Set<String>();
    for (CaseStatus status : [
      SELECT ApiName
      FROM CaseStatus
      WHERE IsClosed = TRUE
    ]) {
      closedStatuses.add(status.ApiName);
    }
    return closedStatuses;
  }
}
