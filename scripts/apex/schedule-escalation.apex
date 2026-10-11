// Schedules the SLA escalation job at minutes 0, 15, 30 and 45 of every hour.
// Run once per org: sf apex run --file scripts/apex/schedule-escalation.apex
System.debug(SlaEscalationBatch.scheduleEvery15Minutes());
