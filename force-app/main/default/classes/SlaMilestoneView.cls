/**
 * Read-only view of an SLA milestone for Lightning components. Shared by the
 * case SLA panel and the queue console.
 */
public inherited sharing class SlaMilestoneView {
  @AuraEnabled
  public Id id;
  @AuraEnabled
  public String type;
  @AuraEnabled
  public String status;
  @AuraEnabled
  public Datetime targetAt;
  @AuraEnabled
  public Datetime atRiskAt;
  @AuraEnabled
  public Datetime completedAt;
  @AuraEnabled
  public Datetime pausedSince;
  @AuraEnabled
  public Integer pausedMinutes;

  public SlaMilestoneView(SLA_Milestone__c milestone) {
    this.id = milestone.Id;
    this.type = milestone.Type__c;
    this.status = milestone.Status__c;
    this.targetAt = milestone.Target_At__c;
    this.atRiskAt = milestone.At_Risk_At__c;
    this.completedAt = milestone.Completed_At__c;
    this.pausedSince = milestone.Paused_Since__c;
    this.pausedMinutes = milestone.Paused_Minutes__c == null
      ? 0
      : milestone.Paused_Minutes__c.intValue();
  }
}
