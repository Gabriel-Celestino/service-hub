@IsTest
private class PortalCaseRequestTest {
  private static PortalCaseRequest valid() {
    return PortalCaseRequest.parse(
      '{"externalId":"WEB-1001","subject":"Cannot log in","contactEmail":"ana@acme.test"}'
    );
  }

  private static Set<String> fieldsWithErrors(PortalCaseRequest request) {
    Set<String> fields = new Set<String>();
    for (PortalApi.FieldError error : request.validate()) {
      fields.add(error.field);
    }
    return fields;
  }

  @IsTest
  static void validRequestHasNoErrorsAndDefaults() {
    PortalCaseRequest request = valid();

    Assert.isTrue(request.validate().isEmpty(), 'Valid request');
    Assert.areEqual('Other', request.effectiveCategory(), 'Default category');
    Assert.areEqual('Medium', request.effectivePriority(), 'Default priority');
  }

  @IsTest
  static void reportsEveryInvalidFieldAtOnce() {
    PortalCaseRequest request = PortalCaseRequest.parse(
      '{"externalId":"has spaces","subject":"","category":"Sales","priority":"Urgent","contactEmail":"not-an-email"}'
    );

    Assert.areEqual(
      new Set<String>{
        'externalId',
        'subject',
        'category',
        'priority',
        'contactEmail'
      },
      fieldsWithErrors(request),
      'One error per invalid field'
    );
  }

  @IsTest
  static void requiresExternalIdAndLimitsLengths() {
    PortalCaseRequest request = valid();
    request.externalId = null;
    request.subject = 'x'.repeat(256);
    request.description = 'x'.repeat(32001);

    Assert.areEqual(
      new Set<String>{ 'externalId', 'subject', 'description' },
      fieldsWithErrors(request),
      'Missing id and over-long texts'
    );
  }

  @IsTest
  static void ignoresUnknownProperties() {
    PortalCaseRequest request = PortalCaseRequest.parse(
      '{"externalId":"WEB-1","subject":"Hi","unexpected":true}'
    );

    Assert.isTrue(request.validate().isEmpty(), 'Extra properties are ignored');
  }

  @IsTest
  static void rejectsMissingOrMalformedBodies() {
    for (String body : new List<String>{ null, '', '{not json', 'null' }) {
      try {
        PortalCaseRequest.parse(body);
        Assert.fail('Expected a PortalApiException for: ' + body);
      } catch (PortalApi.PortalApiException error) {
        Assert.areEqual(400, error.statusCode, 'Bad request for: ' + body);
      }
    }
  }
}
