/**
 * Escalates cases whose running milestones are at risk or breached.
 *
 * For each due milestone the status is refreshed (Open -> At Risk ->
 * Breached). When a case reaches a higher escalation level, an Escalation__c
 * audit record is created, Escalation_Level__c is raised and, at level 2, the
 * case moves to the Tier 2 queue. A level is never escalated twice.
 */
public inherited sharing class SlaEscalationService {
  public static void escalate(
    List<SLA_Milestone__c> dueMilestones,
    Datetime asOf
  ) {
    if (dueMilestones == null || dueMilestones.isEmpty()) {
      return;
    }

    // refreshStatus only compares times, so the clock is never called here.
    SlaMilestoneCalculator calculator = new SlaMilestoneCalculator(
      new PlatformBusinessClock()
    );
    Map<Id, SLA_Milestone__c> refreshedById = new Map<Id, SLA_Milestone__c>();
    List<SLA_Milestone__c> milestonesToUpdate = new List<SLA_Milestone__c>();
    Set<Id> caseIds = new Set<Id>();

    for (SLA_Milestone__c milestone : dueMilestones) {
      String previousStatus = milestone.Status__c;
      calculator.refreshStatus(milestone, asOf);
      refreshedById.put(milestone.Id, milestone);
      caseIds.add(milestone.Case__c);
      if (milestone.Status__c != previousStatus) {
        milestonesToUpdate.add(SlaService.forUpdate(milestone));
      }
    }

    Map<Id, List<SLA_Milestone__c>> milestonesByCaseId = new SlaMilestoneSelector()
      .selectByCaseIds(caseIds);
    Map<Id, Case> casesById = new CaseSelector().selectByIds(caseIds);
    Map<String, Id> queueIdsByName = new QueueSelector()
      .selectIdsByDeveloperName(
        new Set<String>{ EscalationPolicy.TIER2_QUEUE }
      );

    List<Case> casesToUpdate = new List<Case>();
    List<Escalation__c> escalations = new List<Escalation__c>();

    for (Id caseId : caseIds) {
      Case current = casesById.get(caseId);
      if (current == null) {
        continue;
      }
      List<SLA_Milestone__c> milestones = withRefreshed(
        milestonesByCaseId.get(caseId),
        refreshedById
      );
      Case changes = new Case(Id = caseId);
      Boolean changed = false;

      String summary = SlaStatusSummarizer.summarize(milestones);
      if (summary != null && summary != current.SLA_Status__c) {
        changes.SLA_Status__c = summary;
        changed = true;
      }

      Integer currentLevel = current.Escalation_Level__c == null
        ? 0
        : current.Escalation_Level__c.intValue();
      Integer newLevel = EscalationPolicy.levelFor(milestones);
      if (newLevel > currentLevel) {
        String targetQueue = EscalationPolicy.targetQueueFor(newLevel);
        escalations.add(
          new Escalation__c(
            Case__c = caseId,
            Level__c = newLevel,
            Reason__c = EscalationPolicy.reasonFor(newLevel),
            Target_Queue__c = targetQueue
          )
        );
        changes.Escalation_Level__c = newLevel;
        Id queueId = targetQueue == null
          ? null
          : queueIdsByName.get(targetQueue);
        if (queueId != null) {
          changes.OwnerId = queueId;
        }
        changed = true;
      }

      if (changed) {
        casesToUpdate.add(changes);
      }
    }

    update milestonesToUpdate;
    insert escalations;
    update casesToUpdate;
  }

  /** Stored milestones of a case, with the ones refreshed in this run replacing their stale copies. */
  private static List<SLA_Milestone__c> withRefreshed(
    List<SLA_Milestone__c> stored,
    Map<Id, SLA_Milestone__c> refreshedById
  ) {
    List<SLA_Milestone__c> result = new List<SLA_Milestone__c>();
    if (stored == null) {
      return result;
    }
    for (SLA_Milestone__c milestone : stored) {
      result.add(
        refreshedById.containsKey(milestone.Id)
          ? refreshedById.get(milestone.Id)
          : milestone
      );
    }
    return result;
  }
}
