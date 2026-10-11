/**
 * Queries on queues (Group records of type Queue).
 */
public inherited sharing class QueueSelector {
  public Map<String, Id> selectIdsByDeveloperName(Set<String> developerNames) {
    Map<String, Id> queueIdsByName = new Map<String, Id>();
    if (developerNames == null || developerNames.isEmpty()) {
      return queueIdsByName;
    }
    for (Group queue : [
      SELECT Id, DeveloperName
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName IN :developerNames
    ]) {
      queueIdsByName.put(queue.DeveloperName, queue.Id);
    }
    return queueIdsByName;
  }
}
