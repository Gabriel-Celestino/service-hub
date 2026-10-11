/**
 * Queries on BusinessHours.
 */
public inherited sharing class BusinessHoursSelector {
  public Map<String, Id> selectActiveIdsByName(Set<String> names) {
    Map<String, Id> idsByName = new Map<String, Id>();
    if (names == null || names.isEmpty()) {
      return idsByName;
    }
    for (BusinessHours hours : [
      SELECT Id, Name
      FROM BusinessHours
      WHERE IsActive = TRUE AND Name IN :names
    ]) {
      idsByName.put(hours.Name, hours.Id);
    }
    return idsByName;
  }
}
