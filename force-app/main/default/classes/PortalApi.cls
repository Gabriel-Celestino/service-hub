/**
 * Shared plumbing for the portal REST API: correlation ids, JSON responses
 * and the error format.
 *
 * Error body: { "message": "...", "errors": [{ "field": "...", "message": "..." }], "correlationId": "..." }
 */
public inherited sharing class PortalApi {
  public static final String CORRELATION_HEADER = 'X-Correlation-Id';
  private static final Pattern SAFE_ID = Pattern.compile(
    '^[A-Za-z0-9._:-]{1,64}$'
  );

  /** The caller's correlation id when it is safe to reuse, otherwise a new one. */
  public static String correlationId(RestRequest request) {
    String provided = header(request, CORRELATION_HEADER);
    if (provided != null && SAFE_ID.matcher(provided).matches()) {
      return provided;
    }
    return UUID.randomUUID().toString();
  }

  /** Header value by name, ignoring case (HTTP header names are case-insensitive). */
  public static String header(RestRequest request, String name) {
    if (request?.headers == null) {
      return null;
    }
    for (String key : request.headers.keySet()) {
      if (key.equalsIgnoreCase(name)) {
        return request.headers.get(key);
      }
    }
    return null;
  }

  public static void respond(
    RestResponse response,
    Integer statusCode,
    Object body,
    String correlationId
  ) {
    response.statusCode = statusCode;
    response.addHeader('Content-Type', 'application/json');
    response.addHeader(CORRELATION_HEADER, correlationId);
    response.responseBody = Blob.valueOf(JSON.serialize(body, true));
  }

  public class FieldError {
    public String field;
    public String message;

    public FieldError(String field, String message) {
      this.field = field;
      this.message = message;
    }
  }

  public class ErrorBody {
    public String message;
    public List<FieldError> errors;
    public String correlationId;

    public ErrorBody(
      String message,
      List<FieldError> errors,
      String correlationId
    ) {
      this.message = message;
      this.errors = errors;
      this.correlationId = correlationId;
    }
  }

  /** An error the API reports to the caller with a specific HTTP status. */
  public class PortalApiException extends Exception {
    public Integer statusCode = 400;
    public List<FieldError> errors = new List<FieldError>();

    public PortalApiException(
      Integer statusCode,
      String message,
      List<FieldError> errors
    ) {
      this.setMessage(message);
      this.statusCode = statusCode;
      this.errors = errors == null ? new List<FieldError>() : errors;
    }
  }
}
