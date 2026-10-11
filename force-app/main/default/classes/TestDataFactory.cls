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
}
