/**
 * Keeps SLA milestones in step with their cases.
 *
 * - before insert: the case starts On Track.
 * - after insert: a First Response and a Resolution milestone are created.
 * - before update: status and priority changes complete, pause, resume or
 *   recalculate milestones, and Case.SLA_Status__c is summarized.
 *
 * Updates run in before update on purpose: the case summary is set on the
 * record being saved, so no second Case DML (and no trigger recursion) is
 * needed. Milestones are child records, so updating them here is allowed and
 * rolls back with the case if the save fails.
 */
public inherited sharing class SlaService {
  @TestVisible
  private static Datetime nowOverride;
  @TestVisible
  private static BusinessClock clock = new PlatformBusinessClock();

  /** Current time. Tests can move it with nowOverride. */
  public static Datetime now() {
    return nowOverride != null ? nowOverride : System.now();
  }

  public static void initializeCases(List<Case> cases) {
    for (Case record : cases) {
      record.SLA_Status__c = SlaConstants.SLA_ON_TRACK;
      if (record.Escalation_Level__c == null) {
        record.Escalation_Level__c = 0;
      }
    }
  }

  public static void createMilestones(List<Case> cases) {
    SlaContext context = new SlaContext(cases);
    SlaMilestoneCalculator calculator = new SlaMilestoneCalculator(clock);
    List<SLA_Milestone__c> milestones = new List<SLA_Milestone__c>();

    for (Case record : cases) {
      if (!context.hasPolicy(record.Id)) {
        continue;
      }
      for (String milestoneType : SlaConstants.MILESTONE_TYPES) {
        SLA_Milestone__c milestone = new SLA_Milestone__c(
          Case__c = record.Id,
          Type__c = milestoneType,
          Status__c = SlaConstants.MILESTONE_OPEN,
          Paused_Minutes__c = 0
        );
        calculator.applyTargets(
          milestone,
          record.CreatedDate,
          context.policyFor(record.Id),
          context.businessHoursFor(record.Id)
        );
        milestones.add(milestone);
      }
    }
    insert as system milestones;
  }

  public static void applyCaseChanges(
    List<Case> cases,
    Map<Id, Case> oldCases
  ) {
    Datetime currentTime = now();
    List<Case> changedCases = new List<Case>();

    for (Case record : cases) {
      Case previous = oldCases.get(record.Id);
      if (leftNew(record, previous) && record.First_Response_At__c == null) {
        record.First_Response_At__c = currentTime;
      }
      if (
        record.Status != previous.Status ||
        record.Priority != previous.Priority
      ) {
        changedCases.add(record);
      }
    }
    if (changedCases.isEmpty()) {
      return;
    }

    Map<Id, List<SLA_Milestone__c>> milestonesByCaseId = new SlaMilestoneSelector()
      .selectByCaseIds(new Map<Id, Case>(changedCases).keySet());
    if (milestonesByCaseId.isEmpty()) {
      return;
    }
    Set<String> closedStatuses = new CaseStatusSelector()
      .selectClosedApiNames();
    SlaContext context = new SlaContext(changedCases);
    SlaMilestoneCalculator calculator = new SlaMilestoneCalculator(clock);
    List<SLA_Milestone__c> milestonesToUpdate = new List<SLA_Milestone__c>();

    for (Case record : changedCases) {
      List<SLA_Milestone__c> milestones = milestonesByCaseId.get(record.Id);
      if (milestones == null) {
        continue;
      }
      Case previous = oldCases.get(record.Id);
      CaseChange change = new CaseChange(record, previous, closedStatuses);

      for (SLA_Milestone__c milestone : milestones) {
        if (SlaMilestoneCalculator.isCompleted(milestone)) {
          continue;
        }
        applyChange(
          milestone,
          change,
          record,
          context,
          calculator,
          currentTime
        );
        milestonesToUpdate.add(forUpdate(milestone));
      }

      String summary = SlaStatusSummarizer.summarize(milestones);
      if (summary != null) {
        record.SLA_Status__c = summary;
      }
    }
    update as system milestonesToUpdate;
  }

  private static void applyChange(
    SLA_Milestone__c milestone,
    CaseChange change,
    Case record,
    SlaContext context,
    SlaMilestoneCalculator calculator,
    Datetime currentTime
  ) {
    Id businessHoursId = context.businessHoursFor(record.Id);
    Boolean canRecalculate = context.hasPolicy(record.Id);

    if (change.leftPause && canRecalculate) {
      calculator.resume(milestone, currentTime, businessHoursId);
    }
    if ((change.leftPause || change.priorityChanged) && canRecalculate) {
      calculator.applyTargets(
        milestone,
        record.CreatedDate,
        context.policyFor(record.Id),
        businessHoursId
      );
      calculator.refreshStatus(milestone, currentTime);
    }

    Boolean firstResponseGiven =
      change.leftNew && milestone.Type__c == SlaConstants.TYPE_FIRST_RESPONSE;
    if (change.closed || firstResponseGiven) {
      calculator.complete(milestone, currentTime);
    } else if (change.enteredPause) {
      calculator.pause(milestone, currentTime);
    }
  }

  /**
   * Copies only the fields the SLA engine changes. Queried milestones carry
   * Case__c, a master-detail field that cannot be updated, so they are never
   * sent back to the database as they are.
   */
  public static SLA_Milestone__c forUpdate(SLA_Milestone__c milestone) {
    return new SLA_Milestone__c(
      Id = milestone.Id,
      Status__c = milestone.Status__c,
      Target_At__c = milestone.Target_At__c,
      At_Risk_At__c = milestone.At_Risk_At__c,
      Completed_At__c = milestone.Completed_At__c,
      Paused_Since__c = milestone.Paused_Since__c,
      Paused_Minutes__c = milestone.Paused_Minutes__c
    );
  }

  private static Boolean leftNew(Case record, Case previous) {
    return previous.Status == SlaConstants.CASE_STATUS_NEW &&
      record.Status != SlaConstants.CASE_STATUS_NEW;
  }

  /** What changed on a case, in SLA terms. */
  private class CaseChange {
    public final Boolean leftNew;
    public final Boolean enteredPause;
    public final Boolean leftPause;
    public final Boolean priorityChanged;
    public final Boolean closed;

    public CaseChange(Case record, Case previous, Set<String> closedStatuses) {
      String waiting = SlaConstants.CASE_STATUS_WAITING;
      this.leftNew = SlaService.leftNew(record, previous);
      this.enteredPause =
        record.Status == waiting &&
        previous.Status != waiting;
      this.leftPause = previous.Status == waiting && record.Status != waiting;
      this.priorityChanged = record.Priority != previous.Priority;
      this.closed = closedStatuses.contains(record.Status);
    }
  }

  /** Policy and Business Hours for each case, loaded in bulk. */
  private class SlaContext {
    private final Map<Id, SLA_Policy__mdt> policiesByCaseId = new Map<Id, SLA_Policy__mdt>();
    private final Map<Id, Id> businessHoursIdsByCaseId = new Map<Id, Id>();

    public SlaContext(List<Case> cases) {
      Map<Id, Account> accountsById = new AccountSelector()
        .selectByCases(cases);
      SlaPolicyResolver resolver = new SlaPolicyResolver(
        new SlaPolicySelector().selectAll()
      );
      Set<String> businessHoursNames = new Set<String>();

      for (Case record : cases) {
        Account parentAccount = accountsById.get(record.AccountId);
        String supportTier = parentAccount == null
          ? null
          : parentAccount.Support_Tier__c;
        SLA_Policy__mdt policy = resolver.resolve(supportTier, record.Priority);
        if (policy == null) {
          System.debug(
            LoggingLevel.WARN,
            'SLA: no policy for tier ' +
              supportTier +
              ' and priority ' +
              record.Priority
          );
          continue;
        }
        policiesByCaseId.put(record.Id, policy);
        businessHoursNames.add(policy.Business_Hours_Name__c);
      }

      Map<String, Id> businessHoursIdsByName = new BusinessHoursSelector()
        .selectActiveIdsByName(businessHoursNames);
      for (Id caseId : policiesByCaseId.keySet()) {
        String hoursName = policiesByCaseId.get(caseId).Business_Hours_Name__c;
        Id businessHoursId = businessHoursIdsByName.get(hoursName);
        if (businessHoursId == null) {
          System.debug(
            LoggingLevel.WARN,
            'SLA: Business Hours not found: ' + hoursName
          );
          continue;
        }
        businessHoursIdsByCaseId.put(caseId, businessHoursId);
      }
    }

    public Boolean hasPolicy(Id caseId) {
      return businessHoursIdsByCaseId.containsKey(caseId);
    }

    public SLA_Policy__mdt policyFor(Id caseId) {
      return policiesByCaseId.get(caseId);
    }

    public Id businessHoursFor(Id caseId) {
      return businessHoursIdsByCaseId.get(caseId);
    }
  }
}
