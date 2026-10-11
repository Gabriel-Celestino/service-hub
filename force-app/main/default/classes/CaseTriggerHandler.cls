/**
 * Maps Case trigger events to services. Contains no business logic.
 */
public inherited sharing class CaseTriggerHandler extends TriggerHandler {
  protected override void beforeInsert(List<SObject> newRecords) {
    CaseRoutingService.assignQueues((List<Case>) newRecords);
  }
}
