/**
 * Display names of record owners, which can be users or queues.
 *
 * Owner is a polymorphic relationship, and Owner.Name comes back empty for
 * queues when queried in user mode. Names of users and queues are not
 * sensitive, so they are read here in a separate query.
 */
public inherited sharing class OwnerSelector {
  public Map<Id, String> selectNamesByIds(Set<Id> ownerIds) {
    Map<Id, String> namesById = new Map<Id, String>();
    if (ownerIds == null || ownerIds.isEmpty()) {
      return namesById;
    }
    for (Group queue : [
      SELECT Id, Name
      FROM Group
      WHERE Id IN :ownerIds
      WITH SYSTEM_MODE
    ]) {
      namesById.put(queue.Id, queue.Name);
    }
    for (User person : [
      SELECT Id, Name
      FROM User
      WHERE Id IN :ownerIds
      WITH SYSTEM_MODE
    ]) {
      namesById.put(person.Id, person.Name);
    }
    return namesById;
  }
}
