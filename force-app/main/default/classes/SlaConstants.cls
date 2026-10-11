/**
 * Picklist values used by the SLA engine, in one place.
 */
public inherited sharing class SlaConstants {
  // Case.Status
  public static final String CASE_STATUS_NEW = 'New';
  public static final String CASE_STATUS_WAITING = 'Waiting on Customer';

  // SLA_Milestone__c.Type__c
  public static final String TYPE_FIRST_RESPONSE = 'First Response';
  public static final String TYPE_RESOLUTION = 'Resolution';
  public static final List<String> MILESTONE_TYPES = new List<String>{
    TYPE_FIRST_RESPONSE,
    TYPE_RESOLUTION
  };

  // SLA_Milestone__c.Status__c
  public static final String MILESTONE_OPEN = 'Open';
  public static final String MILESTONE_AT_RISK = 'At Risk';
  public static final String MILESTONE_PAUSED = 'Paused';
  public static final String MILESTONE_MET = 'Met';
  public static final String MILESTONE_BREACHED = 'Breached';

  // Case.SLA_Status__c
  public static final String SLA_ON_TRACK = 'On Track';
  public static final String SLA_AT_RISK = 'At Risk';
  public static final String SLA_PAUSED = 'Paused';
  public static final String SLA_BREACHED = 'Breached';
  public static final String SLA_MET = 'Met';
}
