/**
 * Writes Integration_Log__c records. Runs in system mode: every call is
 * logged, whatever the caller's permissions.
 */
public inherited sharing class IntegrationLogger {
  public static final String INBOUND = 'Inbound';
  public static final String OUTBOUND = 'Outbound';

  private static final Integer PAYLOAD_MAX = 131072;
  private static final Integer ERROR_MAX = 32768;

  public static Integration_Log__c inbound(
    String endpoint,
    Integer statusCode,
    String correlationId,
    Id relatedRecordId,
    String payload,
    String errorMessage
  ) {
    return new Integration_Log__c(
      Direction__c = INBOUND,
      Endpoint__c = endpoint?.left(255),
      Status_Code__c = statusCode,
      Correlation_Id__c = correlationId,
      Related_Record_Id__c = relatedRecordId,
      Payload__c = payload?.left(PAYLOAD_MAX),
      Error_Message__c = errorMessage?.left(ERROR_MAX)
    );
  }

  public static void save(Integration_Log__c log) {
    save(new List<Integration_Log__c>{ log });
  }

  /** Always system mode: a call is logged even when the caller cannot see the log object. */
  public static void save(List<Integration_Log__c> logs) {
    if (logs == null || logs.isEmpty()) {
      return;
    }
    Database.insert(logs, AccessLevel.SYSTEM_MODE);
  }

  public static Integration_Log__c outbound(
    String endpoint,
    String correlationId,
    Id relatedRecordId,
    String errorMessage
  ) {
    return new Integration_Log__c(
      Direction__c = OUTBOUND,
      Endpoint__c = endpoint?.left(255),
      Correlation_Id__c = correlationId,
      Related_Record_Id__c = relatedRecordId,
      Error_Message__c = errorMessage?.left(ERROR_MAX)
    );
  }
}
