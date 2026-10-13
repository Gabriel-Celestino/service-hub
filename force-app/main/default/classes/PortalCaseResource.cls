/**
 * REST API for the customer portal.
 *
 *   POST /services/apexrest/portal/v1/cases               create a case (idempotent on externalId)
 *   GET  /services/apexrest/portal/v1/cases/{externalId}  read a case and its SLA
 *
 * Every call is logged in Integration_Log__c with the caller's X-Correlation-Id
 * (or a generated one), which is echoed back in the response header.
 * Contract: docs/api/portal-api.yaml
 */
@RestResource(urlMapping='/portal/v1/cases/*')
global with sharing class PortalCaseResource {
  private static final String BASE_PATH = '/portal/v1/cases';

  @HttpPost
  global static void createCase() {
    RestRequest request = RestContext.request;
    String correlationId = PortalApi.correlationId(request);
    String body = request.requestBody == null
      ? null
      : request.requestBody.toString();
    Outcome outcome = new Outcome();

    try {
      PortalCaseRequest caseRequest = PortalCaseRequest.parse(body);
      List<PortalApi.FieldError> errors = caseRequest.validate();
      if (!errors.isEmpty()) {
        throw new PortalApi.PortalApiException(
          400,
          'The request has invalid fields.',
          errors
        );
      }
      PortalCaseService.Result result = PortalCaseService.upsertCase(
        caseRequest
      );
      outcome.succeed(result.created ? 201 : 200, result.view);
    } catch (Exception error) {
      outcome.fail(error, correlationId);
    }
    finish(outcome, 'POST ' + BASE_PATH, correlationId, body);
  }

  @HttpGet
  global static void getCase() {
    RestRequest request = RestContext.request;
    String correlationId = PortalApi.correlationId(request);
    Outcome outcome = new Outcome();

    try {
      outcome.succeed(
        200,
        PortalCaseService.getCase(externalIdFrom(request.requestURI))
      );
    } catch (Exception error) {
      outcome.fail(error, correlationId);
    }
    finish(outcome, 'GET ' + request.requestURI, correlationId, null);
  }

  @TestVisible
  private static String externalIdFrom(String requestUri) {
    String tail = requestUri == null
      ? ''
      : requestUri.substringAfter(BASE_PATH).removeStart('/');
    return String.isBlank(tail) ? null : EncodingUtil.urlDecode(tail, 'UTF-8');
  }

  private static void finish(
    Outcome outcome,
    String endpoint,
    String correlationId,
    String payload
  ) {
    PortalApi.respond(
      RestContext.response,
      outcome.statusCode,
      outcome.body,
      correlationId
    );
    IntegrationLogger.save(
      IntegrationLogger.inbound(
        endpoint,
        outcome.statusCode,
        correlationId,
        outcome.caseId,
        payload,
        outcome.errorMessage
      )
    );
  }

  /** Status, body and log details of one call. */
  private class Outcome {
    public Integer statusCode;
    public Object body;
    public Id caseId;
    public String errorMessage;

    public void succeed(Integer statusCode, PortalCaseView view) {
      this.statusCode = statusCode;
      this.body = view;
      this.caseId = view.caseId;
    }

    public void fail(Exception error, String correlationId) {
      if (error instanceof PortalApi.PortalApiException) {
        PortalApi.PortalApiException apiError = (PortalApi.PortalApiException) error;
        this.statusCode = apiError.statusCode;
        this.body = new PortalApi.ErrorBody(
          apiError.getMessage(),
          apiError.errors,
          correlationId
        );
        this.errorMessage = apiError.getMessage();
        return;
      }
      this.statusCode = 500;
      this.body = new PortalApi.ErrorBody(
        'Unexpected error. Quote the correlation id when reporting it.',
        null,
        correlationId
      );
      this.errorMessage =
        error.getTypeName() +
        ': ' +
        error.getMessage() +
        '\n' +
        error.getStackTraceString();
    }
  }
}
