@IsTest
private class SlaConsoleControllerTest {
  private static Case insertCase(
    String supportTier,
    String category,
    String priority
  ) {
    Account customer = TestDataFactory.createAccount(supportTier);
    Case record = TestDataFactory.buildCase(customer.Id, category, priority);
    insert record;
    return [SELECT Id, CaseNumber, CreatedDate FROM Case WHERE Id = :record.Id];
  }

  @IsTest
  static void listsOpenCasesMostUrgentFirst() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      Case relaxed = insertCase('Standard', 'Billing', 'Low');
      Case urgent = insertCase('Enterprise', 'Technical', 'Critical');
      Case closed = insertCase('Premium', 'Access', 'Medium');
      update new Case(Id = closed.Id, Status = 'Closed');

      Test.startTest();
      List<CaseQueueItem> queue = SlaConsoleController.getQueue(
        SlaConsoleService.SCOPE_ALL
      );
      Test.stopTest();

      Assert.areEqual(2, queue.size(), 'Closed cases are not listed');
      Assert.areEqual(urgent.Id, queue[0].caseId, 'Nearest deadline first');
      Assert.areEqual(relaxed.Id, queue[1].caseId, 'Later deadline second');
      Assert.areEqual(
        'Technical Support',
        queue[0].ownerName,
        'Owner name exposed'
      );
      Assert.isNotNull(queue[0].accountName, 'Account name exposed');
      Assert.areEqual(
        SlaConstants.TYPE_FIRST_RESPONSE,
        queue[0].nextMilestone.type,
        'Next deadline exposed'
      );
    }
  }

  @IsTest
  static void atRiskScopeShowsOnlyCasesThatNeedAttentionNow() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      Case urgent = insertCase('Enterprise', 'Technical', 'Critical');
      insertCase('Standard', 'Billing', 'Low');

      Test.startTest();
      List<CaseQueueItem> queue = SlaConsoleService.getQueue(
        SlaConsoleService.SCOPE_AT_RISK,
        agent.Id,
        urgent.CreatedDate.addMinutes(25)
      );
      Test.stopTest();

      Assert.areEqual(1, queue.size(), 'Only the at-risk case');
      Assert.areEqual(
        urgent.Id,
        queue[0].caseId,
        'Enterprise Critical is at risk after 22 minutes'
      );
      Assert.areEqual('At Risk', queue[0].urgency, 'Urgency label');
    }
  }

  @IsTest
  static void mineScopeShowsCasesInTheAgentsQueues() {
    User agent = TestDataFactory.createAgentUser();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new GroupMember(
        GroupId = TestDataFactory.queueId('Billing_Support'),
        UserOrGroupId = agent.Id
      );
    }

    System.runAs(agent) {
      Case billing = insertCase('Premium', 'Billing', 'High');
      insertCase('Premium', 'Technical', 'High');

      Test.startTest();
      List<CaseQueueItem> queue = SlaConsoleController.getQueue(
        SlaConsoleService.SCOPE_MINE
      );
      Test.stopTest();

      Assert.areEqual(1, queue.size(), 'Only cases in the agent queues');
      Assert.areEqual(billing.Id, queue[0].caseId, 'The Billing Support case');
    }
  }

  @IsTest
  static void rejectsAnUnknownScope() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      try {
        SlaConsoleController.getQueue('EVERYTHING');
        Assert.fail('Expected an AuraHandledException');
      } catch (AuraHandledException error) {
        Assert.areEqual(
          'Unknown queue scope: EVERYTHING',
          error.getMessage(),
          'Clear message for the UI'
        );
      }
    }
  }

  @IsTest
  static void capsTheNumberOfRows() {
    User agent = TestDataFactory.createAgentUser();

    System.runAs(agent) {
      Account customer = TestDataFactory.createAccount('Standard');
      insert TestDataFactory.buildCases(
        customer.Id,
        'Other',
        SlaConsoleService.MAX_ROWS + 5
      );

      Test.startTest();
      List<CaseQueueItem> queue = SlaConsoleController.getQueue(
        SlaConsoleService.SCOPE_ALL
      );
      Test.stopTest();

      Assert.areEqual(
        SlaConsoleService.MAX_ROWS,
        queue.size(),
        'The console shows at most MAX_ROWS cases'
      );
    }
  }

  @IsTest
  static void resolvesOwnerNamesOfUsersAndQueues() {
    Group queue = [
      SELECT Id, Name
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = 'Billing_Support'
    ];

    Test.startTest();
    Map<Id, String> names = new OwnerSelector()
      .selectNamesByIds(new Set<Id>{ queue.Id, UserInfo.getUserId() });
    Test.stopTest();

    Assert.areEqual(queue.Name, names.get(queue.Id), 'Queue name');
    Assert.areEqual(
      UserInfo.getName(),
      names.get(UserInfo.getUserId()),
      'User name'
    );
    Assert.isTrue(
      new OwnerSelector().selectNamesByIds(new Set<Id>()).isEmpty(),
      'No ids, no names'
    );
  }
}
