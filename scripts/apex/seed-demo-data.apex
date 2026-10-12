// Creates demo accounts and cases in every SLA state, for screenshots and demos.
// Run in a scratch org: sf apex run --file scripts/apex/seed-demo-data.apex
//
// Cases go through the real trigger (routing, SLA milestones). To show at-risk
// and breached cases right away, the script then moves some deadlines into the
// past and runs the escalation once, as the scheduled job would.

Map<String, Account> accounts = new Map<String, Account>{
  'Enterprise' => new Account(Name = 'Acme Corporation', Support_Tier__c = 'Enterprise'),
  'Premium' => new Account(Name = 'Globex Industries', Support_Tier__c = 'Premium'),
  'Standard' => new Account(Name = 'Initech', Support_Tier__c = 'Standard')
};
insert accounts.values();

// tier, category, priority, subject, scenario
List<List<String>> scenarios = new List<List<String>>{
  new List<String>{ 'Enterprise', 'Technical', 'Critical', 'Production API returning 500 errors', 'breached' },
  new List<String>{ 'Enterprise', 'Access', 'High', 'SSO login failing for all users', 'at risk' },
  new List<String>{ 'Enterprise', 'Billing', 'Medium', 'Invoice shows the wrong currency', 'in progress' },
  new List<String>{ 'Premium', 'Technical', 'High', 'Data export stuck at 90%', 'waiting' },
  new List<String>{ 'Premium', 'Billing', 'Critical', 'Duplicate charge on credit card', 'at risk' },
  new List<String>{ 'Premium', 'Other', 'Low', 'Feature request: dark mode', 'new' },
  new List<String>{ 'Standard', 'Access', 'Medium', 'Password reset email not arriving', 'new' },
  new List<String>{ 'Standard', 'Billing', 'High', 'Refund not processed after 10 days', 'breached' },
  new List<String>{ 'Standard', 'Technical', 'Low', 'Typo on the reports page', 'closed' },
  new List<String>{ null, 'Other', 'Medium', 'Question about enterprise pricing', 'new' }
};

List<Case> cases = new List<Case>();
Map<String, String> scenarioBySubject = new Map<String, String>();
for (List<String> row : scenarios) {
  cases.add(
    new Case(
      AccountId = row[0] == null ? null : accounts.get(row[0]).Id,
      Category__c = row[1],
      Priority = row[2],
      Subject = row[3],
      Status = 'New',
      Origin = 'Portal'
    )
  );
  scenarioBySubject.put(row[3], row[4]);
}
insert cases;

// Move cases forward in their lifecycle through the trigger.
Map<String, String> statusByScenario = new Map<String, String>{
  'in progress' => 'In Progress',
  'waiting' => 'Waiting on Customer',
  'closed' => 'Closed'
};
List<Case> statusChanges = new List<Case>();
for (Case record : cases) {
  String newStatus = statusByScenario.get(scenarioBySubject.get(record.Subject));
  if (newStatus != null) {
    statusChanges.add(new Case(Id = record.Id, Status = newStatus));
  }
}
update statusChanges;

// Age the first response of at-risk and breached cases.
Map<Id, String> scenarioByCaseId = new Map<Id, String>();
for (Case record : cases) {
  scenarioByCaseId.put(record.Id, scenarioBySubject.get(record.Subject));
}
Datetime now = System.now();
List<SLA_Milestone__c> running = [
  SELECT Id, Case__c, Type__c, Status__c, Target_At__c, At_Risk_At__c, Completed_At__c, Paused_Since__c, Paused_Minutes__c
  FROM SLA_Milestone__c
  WHERE Case__c IN :scenarioByCaseId.keySet() AND Completed_At__c = NULL
];
List<SLA_Milestone__c> aged = new List<SLA_Milestone__c>();
for (SLA_Milestone__c milestone : running) {
  String scenario = scenarioByCaseId.get(milestone.Case__c);
  if (milestone.Type__c != SlaConstants.TYPE_FIRST_RESPONSE) {
    continue;
  }
  if (scenario == 'at risk') {
    milestone.At_Risk_At__c = now.addMinutes(-2);
    milestone.Target_At__c = now.addMinutes(12);
  } else if (scenario == 'breached') {
    milestone.At_Risk_At__c = now.addMinutes(-40);
    milestone.Target_At__c = now.addMinutes(-25);
  } else {
    continue;
  }
  aged.add(new SLA_Milestone__c(Id = milestone.Id, At_Risk_At__c = milestone.At_Risk_At__c, Target_At__c = milestone.Target_At__c));
}
update aged;

SlaEscalationService.escalate(running, now);

System.debug('Demo data: ' + accounts.size() + ' accounts, ' + cases.size() + ' cases, ' + aged.size() + ' aged milestones.');
