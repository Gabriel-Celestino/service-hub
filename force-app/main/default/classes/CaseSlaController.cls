/**
 * Serves the SLA view of a case to Lightning components.
 *
 * Runs with sharing and every query uses user mode, so agents only see what
 * their permissions allow. Returns small view objects instead of SObjects, so
 * the component contract does not change when the data model does.
 */
public with sharing class CaseSlaController {
  @AuraEnabled(cacheable=true)
  public static CaseSlaView getCaseSla(Id caseId) {
    Case record = new CaseSelector().selectVisibleById(caseId);
    if (record == null) {
      throw new AuraHandledException('Case not found or not accessible.');
    }

    CaseSlaView view = new CaseSlaView();
    view.slaStatus = record.SLA_Status__c;
    view.escalationLevel = record.Escalation_Level__c == null
      ? 0
      : record.Escalation_Level__c.intValue();
    for (
      SLA_Milestone__c milestone : new SlaMilestoneSelector()
        .selectVisibleByCaseId(caseId)
    ) {
      view.milestones.add(new SlaMilestoneView(milestone));
    }
    for (
      Escalation__c escalation : new EscalationSelector()
        .selectVisibleByCaseId(caseId)
    ) {
      view.escalations.add(new EscalationView(escalation));
    }
    return view;
  }

  public class CaseSlaView {
    @AuraEnabled
    public String slaStatus;
    @AuraEnabled
    public Integer escalationLevel;
    @AuraEnabled
    public List<SlaMilestoneView> milestones = new List<SlaMilestoneView>();
    @AuraEnabled
    public List<EscalationView> escalations = new List<EscalationView>();
  }

  public class EscalationView {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer level;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public String targetQueue;
    @AuraEnabled
    public Datetime createdDate;

    public EscalationView(Escalation__c escalation) {
      this.id = escalation.Id;
      this.name = escalation.Name;
      this.level = escalation.Level__c == null
        ? null
        : escalation.Level__c.intValue();
      this.reason = escalation.Reason__c;
      this.targetQueue = escalation.Target_Queue__c;
      this.createdDate = escalation.CreatedDate;
    }
  }
}
