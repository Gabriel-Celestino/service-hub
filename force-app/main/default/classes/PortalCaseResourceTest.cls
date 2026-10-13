/**
 * End-to-end tests of the portal REST API, called as the integration user
 * with nothing but the Service_Hub_Integration permission set.
 */
@IsTest
private class PortalCaseResourceTest {
  private static final String CONTACT_EMAIL = 'ana@acme.test';

  @TestSetup
  static void createCustomer() {
    Account customer = TestDataFactory.createAccount('Enterprise');
    insert new Contact(
      LastName = 'Silva',
      FirstName = 'Ana',
      Email = CONTACT_EMAIL,
      AccountId = customer.Id
    );
  }

  private static RestResponse post(String body, String correlationId) {
    RestRequest request = new RestRequest();
    request.requestURI = '/portal/v1/cases';
    request.httpMethod = 'POST';
    request.requestBody = body == null ? null : Blob.valueOf(body);
    if (correlationId != null) {
      request.addHeader('x-correlation-id', correlationId);
    }
    RestContext.request = request;
    RestContext.response = new RestResponse();
    PortalCaseResource.createCase();
    return RestContext.response;
  }

  private static RestResponse get(String externalId) {
    RestRequest request = new RestRequest();
    request.requestURI =
      '/portal/v1/cases' + (externalId == null ? '' : '/' + externalId);
    request.httpMethod = 'GET';
    RestContext.request = request;
    RestContext.response = new RestResponse();
    PortalCaseResource.getCase();
    return RestContext.response;
  }

  private static Map<String, Object> json(RestResponse response) {
    return (Map<String, Object>) JSON.deserializeUntyped(
      response.responseBody.toString()
    );
  }

  private static String newCaseBody(String externalId) {
    return JSON.serialize(
      new Map<String, Object>{
        'externalId' => externalId,
        'subject' => 'Checkout page is down',
        'description' => 'Customers get an error on payment.',
        'category' => 'Technical',
        'priority' => 'Critical',
        'contactEmail' => CONTACT_EMAIL
      }
    );
  }

  @IsTest
  static void createsACaseWithItsSla() {
    User integration = TestDataFactory.createIntegrationUser();

    System.runAs(integration) {
      Test.startTest();
      RestResponse response = post(newCaseBody('WEB-1001'), 'corr-1001');
      Test.stopTest();

      Assert.areEqual(201, response.statusCode, 'Created');
      Assert.areEqual(
        'corr-1001',
        response.headers.get('X-Correlation-Id'),
        'Correlation id echoed'
      );
      Map<String, Object> body = json(response);
      Assert.areEqual(
        'WEB-1001',
        body.get('externalId'),
        'External id returned'
      );
      Assert.isNotNull(body.get('caseNumber'), 'Case number returned');
      Assert.areEqual('On Track', body.get('slaStatus'), 'SLA started');
      Assert.areEqual(
        2,
        ((List<Object>) body.get('milestones')).size(),
        'Both deadlines returned'
      );
    }

    Case saved = [
      SELECT
        Origin,
        Priority,
        Category__c,
        Contact.Email,
        Account.Support_Tier__c
      FROM Case
      WHERE External_Id__c = 'WEB-1001'
    ];
    Assert.areEqual('Portal', saved.Origin, 'Origin set by the API');
    Assert.areEqual(
      CONTACT_EMAIL,
      saved.Contact.Email,
      'Linked to the contact by email'
    );
    Assert.areEqual(
      'Enterprise',
      saved.Account.Support_Tier__c,
      'Account taken from the contact, so the tier SLA applies'
    );

    Integration_Log__c log = [
      SELECT
        Direction__c,
        Status_Code__c,
        Correlation_Id__c,
        Related_Record_Id__c
      FROM Integration_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual('Inbound', log.Direction__c, 'Inbound call logged');
    Assert.areEqual(201, log.Status_Code__c.intValue(), 'Status logged');
    Assert.areEqual(
      'corr-1001',
      log.Correlation_Id__c,
      'Correlation id logged'
    );
    Assert.areEqual(
      saved.Id,
      log.Related_Record_Id__c,
      'Case linked in the log'
    );
  }

  @IsTest
  static void repeatingARequestReturnsTheSameCase() {
    User integration = TestDataFactory.createIntegrationUser();

    System.runAs(integration) {
      RestResponse first = post(newCaseBody('WEB-2002'), null);

      Test.startTest();
      RestResponse second = post(newCaseBody('WEB-2002'), null);
      Test.stopTest();

      Assert.areEqual(201, first.statusCode, 'First call creates');
      Assert.areEqual(
        200,
        second.statusCode,
        'Second call returns the existing case'
      );
      Assert.areEqual(
        json(first).get('caseId'),
        json(second).get('caseId'),
        'Same case'
      );
    }
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Case WHERE External_Id__c = 'WEB-2002'],
      'No duplicate'
    );
  }

  @IsTest
  static void rejectsInvalidRequestsWithFieldErrors() {
    User integration = TestDataFactory.createIntegrationUser();

    System.runAs(integration) {
      Test.startTest();
      RestResponse response = post(
        '{"externalId":"WEB 3003","priority":"Urgent"}',
        null
      );
      Test.stopTest();

      Assert.areEqual(400, response.statusCode, 'Bad request');
      Map<String, Object> body = json(response);
      Assert.areEqual(
        3,
        ((List<Object>) body.get('errors')).size(),
        'externalId, subject and priority'
      );
      Assert.isNotNull(
        body.get('correlationId'),
        'A correlation id is generated when none is sent'
      );
      Assert.isNotNull(
        response.headers.get('X-Correlation-Id'),
        'And returned in the header'
      );
    }
    Assert.areEqual(0, [SELECT COUNT() FROM Case], 'Nothing created');
    Assert.areEqual(
      400,
      [SELECT Status_Code__c FROM Integration_Log__c WITH SYSTEM_MODE]
        .Status_Code__c.intValue(),
      'Failure logged'
    );
  }

  @IsTest
  static void rejectsMalformedJson() {
    User integration = TestDataFactory.createIntegrationUser();

    System.runAs(integration) {
      Test.startTest();
      RestResponse response = post('{oops', null);
      Test.stopTest();

      Assert.areEqual(400, response.statusCode, 'Bad request');
      Assert.areEqual(
        'Request body is not valid JSON.',
        json(response).get('message'),
        'Clear message'
      );
    }
  }

  @IsTest
  static void readsACaseByExternalId() {
    User integration = TestDataFactory.createIntegrationUser();

    System.runAs(integration) {
      post(newCaseBody('WEB-4004'), null);

      Test.startTest();
      RestResponse found = get('WEB-4004');
      RestResponse missing = get('WEB-9999');
      RestResponse blank = get(null);
      Test.stopTest();

      Assert.areEqual(200, found.statusCode, 'Found');
      Assert.areEqual(
        'Critical',
        json(found).get('priority'),
        'Case data returned'
      );
      Assert.areEqual(404, missing.statusCode, 'Unknown id');
      Assert.areEqual(400, blank.statusCode, 'No id in the URL');
    }
  }

  @IsTest
  static void decodesExternalIdsFromTheUrl() {
    Assert.areEqual(
      'WEB:1',
      PortalCaseResource.externalIdFrom('/portal/v1/cases/WEB%3A1'),
      'URL-decoded'
    );
    Assert.isNull(
      PortalCaseResource.externalIdFrom('/portal/v1/cases/'),
      'Trailing slash only'
    );
    Assert.isNull(PortalCaseResource.externalIdFrom(null), 'No URI');
  }

  @IsTest
  static void ignoresAnUnsafeCorrelationId() {
    RestRequest request = new RestRequest();
    request.addHeader('X-Correlation-Id', 'bad id with spaces');

    String correlationId = PortalApi.correlationId(request);

    Assert.areNotEqual(
      'bad id with spaces',
      correlationId,
      'Replaced by a generated id'
    );
    Assert.areEqual(36, correlationId.length(), 'A UUID');
  }
}
