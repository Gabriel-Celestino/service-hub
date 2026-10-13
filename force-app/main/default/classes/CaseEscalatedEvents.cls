/**
 * Builds Case_Escalated__e events. Pure: no DML, no publishing.
 */
public inherited sharing class CaseEscalatedEvents {
  public static Case_Escalated__e build(
    Escalation__c escalation,
    Case escalatedCase
  ) {
    return new Case_Escalated__e(
      Case_Id__c = escalation.Case__c,
      Case_Number__c = escalatedCase?.CaseNumber,
      External_Id__c = escalatedCase?.External_Id__c,
      Level__c = escalation.Level__c,
      Reason__c = escalation.Reason__c,
      Correlation_Id__c = UUID.randomUUID().toString()
    );
  }
}
