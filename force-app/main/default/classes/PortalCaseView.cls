/**
 * What the portal API returns for a case.
 */
public inherited sharing class PortalCaseView {
  public Id caseId;
  public String caseNumber;
  public String externalId;
  public String status;
  public String priority;
  public String category;
  public String slaStatus;
  public Integer escalationLevel;
  public List<SlaMilestoneView> milestones = new List<SlaMilestoneView>();

  public PortalCaseView(Case record) {
    this.caseId = record.Id;
    this.caseNumber = record.CaseNumber;
    this.externalId = record.External_Id__c;
    this.status = record.Status;
    this.priority = record.Priority;
    this.category = record.Category__c;
    this.slaStatus = record.SLA_Status__c;
    this.escalationLevel = record.Escalation_Level__c == null
      ? 0
      : record.Escalation_Level__c.intValue();
    for (SLA_Milestone__c milestone : record.SLA_Milestones__r) {
      this.milestones.add(new SlaMilestoneView(milestone));
    }
  }
}
