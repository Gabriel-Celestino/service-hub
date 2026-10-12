/**
 * Serves the SLA queue console. Runs with sharing; the selector reads in user
 * mode, so agents only see cases and fields their permissions allow.
 */
public with sharing class SlaConsoleController {
  @AuraEnabled
  public static List<CaseQueueItem> getQueue(String scope) {
    try {
      return SlaConsoleService.getQueue(
        scope,
        UserInfo.getUserId(),
        System.now()
      );
    } catch (IllegalArgumentException error) {
      AuraHandledException handled = new AuraHandledException(
        error.getMessage()
      );
      handled.setMessage(error.getMessage());
      throw handled;
    }
  }
}
