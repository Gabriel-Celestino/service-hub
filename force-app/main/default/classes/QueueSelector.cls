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

  /** Ids of the queues the user belongs to directly. */
  public Set<Id> selectQueueIdsForMember(Id userId) {
    Set<Id> queueIds = new Set<Id>();
    for (GroupMember membership : [
      SELECT GroupId
      FROM GroupMember
      WHERE UserOrGroupId = :userId AND Group.Type = 'Queue'
    ]) {
      queueIds.add(membership.GroupId);
    }
    return queueIds;
  }
}
