/**
 * Body of POST /portal/v1/cases, with its validation rules. Pure: no SOQL or DML.
 */
public inherited sharing class PortalCaseRequest {
  public static final Set<String> CATEGORIES = new Set<String>{
    'Billing',
    'Technical',
    'Access',
    'Other'
  };
  public static final Set<String> PRIORITIES = new Set<String>{
    'Low',
    'Medium',
    'High',
    'Critical'
  };
  public static final String DEFAULT_CATEGORY = 'Other';
  public static final String DEFAULT_PRIORITY = 'Medium';

  private static final Pattern EXTERNAL_ID = Pattern.compile(
    '^[A-Za-z0-9._:-]{1,64}$'
  );
  private static final Pattern EMAIL = Pattern.compile(
    '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
  );
  private static final Integer SUBJECT_MAX = 255;
  private static final Integer DESCRIPTION_MAX = 32000;

  public String externalId;
  public String subject;
  public String description;
  public String category;
  public String priority;
  public String contactEmail;

  /** Parses the JSON body. Unknown properties are ignored. */
  public static PortalCaseRequest parse(String body) {
    if (String.isBlank(body)) {
      throw new PortalApi.PortalApiException(
        400,
        'Request body is required.',
        null
      );
    }
    try {
      PortalCaseRequest request = (PortalCaseRequest) JSON.deserialize(
        body,
        PortalCaseRequest.class
      );
      if (request == null) {
        throw new PortalApi.PortalApiException(
          400,
          'Request body must be a JSON object.',
          null
        );
      }
      return request;
    } catch (JSONException error) {
      throw new PortalApi.PortalApiException(
        400,
        'Request body is not valid JSON.',
        null
      );
    }
  }

  /** Returns every problem at once, so the caller can fix them in one go. */
  public List<PortalApi.FieldError> validate() {
    List<PortalApi.FieldError> errors = new List<PortalApi.FieldError>();
    if (String.isBlank(externalId)) {
      errors.add(new PortalApi.FieldError('externalId', 'is required'));
    } else if (!EXTERNAL_ID.matcher(externalId).matches()) {
      errors.add(
        new PortalApi.FieldError(
          'externalId',
          'must be 1-64 letters, digits or . _ : -'
        )
      );
    }
    if (String.isBlank(subject)) {
      errors.add(new PortalApi.FieldError('subject', 'is required'));
    } else if (subject.length() > SUBJECT_MAX) {
      errors.add(
        new PortalApi.FieldError(
          'subject',
          'must be at most ' + SUBJECT_MAX + ' characters'
        )
      );
    }
    if (description != null && description.length() > DESCRIPTION_MAX) {
      errors.add(
        new PortalApi.FieldError(
          'description',
          'must be at most ' + DESCRIPTION_MAX + ' characters'
        )
      );
    }
    if (String.isNotBlank(category) && !CATEGORIES.contains(category)) {
      errors.add(
        new PortalApi.FieldError(
          'category',
          'must be one of ' + String.join(new List<String>(CATEGORIES), ', ')
        )
      );
    }
    if (String.isNotBlank(priority) && !PRIORITIES.contains(priority)) {
      errors.add(
        new PortalApi.FieldError(
          'priority',
          'must be one of ' + String.join(new List<String>(PRIORITIES), ', ')
        )
      );
    }
    if (
      String.isNotBlank(contactEmail) && !EMAIL.matcher(contactEmail).matches()
    ) {
      errors.add(
        new PortalApi.FieldError(
          'contactEmail',
          'must be a valid email address'
        )
      );
    }
    return errors;
  }

  public String effectiveCategory() {
    return String.isBlank(category) ? DEFAULT_CATEGORY : category;
  }

  public String effectivePriority() {
    return String.isBlank(priority) ? DEFAULT_PRIORITY : priority;
  }
}
