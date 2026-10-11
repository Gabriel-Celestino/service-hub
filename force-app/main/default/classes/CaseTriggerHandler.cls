/**
 * Maps Case trigger events to services. Contains no business logic.
 */
public inherited sharing class CaseTriggerHandler extends TriggerHandler {
  protected override void beforeInsert(List<SObject> newRecords) {
    List<Case> cases = (List<Case>) newRecords;
    CaseRoutingService.assignQueues(cases);
    SlaService.initializeCases(cases);
  }

  protected override void afterInsert(List<SObject> newRecords) {
    SlaService.createMilestones((List<Case>) newRecords);
  }

  protected override void beforeUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> oldMap
  ) {
    SlaService.applyCaseChanges(
      (List<Case>) newRecords,
      (Map<Id, Case>) oldMap
    );
  }
}
