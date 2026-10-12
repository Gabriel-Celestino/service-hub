/**
 * Scheduled job that escalates at-risk and breached cases.
 *
 * Runs as a batch so any number of due milestones is processed in chunks of
 * 200. Declared without sharing on purpose: it is a system job and must see
 * every case, whoever scheduled it.
 *
 * Schedule it with SlaEscalationBatch.scheduleEvery15Minutes().
 */
public without sharing class SlaEscalationBatch implements Database.Batchable<SObject>, Schedulable {
  public static final String JOB_NAME_PREFIX = 'SLA escalation at minute ';
  public static final Integer BATCH_SIZE = 200;

  private final Datetime asOf;

  public SlaEscalationBatch() {
    this(null);
  }

  /** @param asOf evaluation time; null means "now". Lets tests move the clock. */
  public SlaEscalationBatch(Datetime asOf) {
    this.asOf = asOf;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return new SlaMilestoneSelector()
      .queryLocatorDueForEscalation(effectiveTime());
  }

  public void execute(
    Database.BatchableContext context,
    List<SLA_Milestone__c> scope
  ) {
    SlaEscalationService.escalate(scope, effectiveTime());
  }

  public void finish(Database.BatchableContext context) {
    System.debug(
      LoggingLevel.INFO,
      'SLA escalation batch finished: ' + context?.getJobId()
    );
  }

  public void execute(SchedulableContext context) {
    Database.executeBatch(new SlaEscalationBatch(), BATCH_SIZE);
  }

  /**
   * Schedules four hourly jobs, at minutes 0, 15, 30 and 45. Idempotent: jobs
   * that are already scheduled are kept, so running it twice is safe.
   * Returns the ids of all four jobs.
   */
  public static List<Id> scheduleEvery15Minutes() {
    String namePattern = JOB_NAME_PREFIX + '%';
    Map<String, Id> existingJobIds = new Map<String, Id>();
    for (CronTrigger job : [
      SELECT Id, CronJobDetail.Name
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE :namePattern
    ]) {
      existingJobIds.put(job.CronJobDetail.Name, job.Id);
    }

    List<Id> jobIds = new List<Id>();
    for (Integer minute : new List<Integer>{ 0, 15, 30, 45 }) {
      String jobName = JOB_NAME_PREFIX + minute;
      if (existingJobIds.containsKey(jobName)) {
        jobIds.add(existingJobIds.get(jobName));
        continue;
      }
      String cron = '0 ' + minute + ' * * * ?';
      jobIds.add(System.schedule(jobName, cron, new SlaEscalationBatch()));
    }
    return jobIds;
  }

  private Datetime effectiveTime() {
    return asOf != null ? asOf : System.now();
  }
}
