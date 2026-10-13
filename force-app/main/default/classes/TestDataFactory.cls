/**
 * Builds test records with valid defaults. "build" methods return records in
 * memory; "create" methods also insert them.
 */
@IsTest
public class TestDataFactory {
  private static Integer sequence = 0;

  public static Account buildAccount(String supportTier) {
    sequence++;
    return new Account(
      Name = 'Test Account ' + sequence,
      Support_Tier__c = supportTier
    );
  }

  public static Account createAccount(String supportTier) {
    Account record = buildAccount(supportTier);
    insert record;
    return record;
  }

  public static Case buildCase(Id accountId, String category) {
    return buildCase(accountId, category, 'Medium');
  }

  public static Case buildCase(Id accountId, String category, String priority) {
    sequence++;
    return new Case(
      AccountId = accountId,
      Category__c = category,
      Subject = 'Test case ' + sequence,
      Priority = priority,
      Status = 'New',
      Origin = 'Portal'
    );
  }

  public static List<Case> buildCases(
    Id accountId,
    String category,
    Integer count
  ) {
    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < count; i++) {
      cases.add(buildCase(accountId, category));
    }
    return cases;
  }

  public static Id queueId(String developerName) {
    return [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = :developerName
      LIMIT 1
    ]
    .Id;
  }

  /**
   * A support agent: System Administrator profile (sees every record) plus
   * the Service_Hub_Agent permission set, which is the only source of access
   * to the project's custom fields.
   */
  public static User createAgentUser() {
    sequence++;
    Profile adminProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User agent = new User(
      Alias = 'agent' + Math.mod(sequence, 100),
      Email = 'agent@servicehub.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Agent ' + sequence,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = adminProfile.Id,
      TimeZoneSidKey = 'America/Sao_Paulo',
      Username = 'agent' +
        sequence +
        '.' +
        System.now().getTime() +
        '@servicehub.test'
    );
    insert agent;
    PermissionSet agentPermissions = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Service_Hub_Agent'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = agent.Id,
      PermissionSetId = agentPermissions.Id
    );
    return agent;
  }

  /**
   * The customer portal's integration user: Minimum Access profile plus the
   * Service_Hub_Integration permission set, so tests prove that the
   * permission set alone is enough.
   */
  public static User createIntegrationUser() {
    sequence++;
    Profile minimumAccess = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];
    User integration = new User(
      Alias = 'portal' + Math.mod(sequence, 10),
      Email = 'portal@servicehub.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Portal Integration ' + sequence,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = minimumAccess.Id,
      TimeZoneSidKey = 'America/Sao_Paulo',
      Username = 'portal' +
        sequence +
        '.' +
        System.now().getTime() +
        '@servicehub.test'
    );
    insert integration;
    PermissionSet permissions = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Service_Hub_Integration'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = integration.Id,
      PermissionSetId = permissions.Id
    );
    return integration;
  }
}
