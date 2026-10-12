// Aborts every scheduled SLA escalation job in the org.
// Only needed when the org does not allow deployments with pending Apex jobs
// (Setup > Deployment Settings). Reschedule afterwards with
// scripts/apex/schedule-escalation.apex.
List<CronTrigger> jobs = [
  SELECT Id, CronJobDetail.Name
  FROM CronTrigger
  WHERE CronJobDetail.Name LIKE 'SLA escalation%'
];
for (CronTrigger job : jobs) {
  System.abortJob(job.Id);
}
System.debug('Aborted ' + jobs.size() + ' SLA escalation jobs.');
