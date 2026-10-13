/**
 * Creates and reads cases on behalf of the customer portal.
 *
 * Creation is idempotent on externalId: sending the same request twice (for
 * example after a timeout) returns the case created the first time. Writes and
 * reads run in user mode, so the integration user's permission set decides
 * what the portal can do.
 */
public inherited sharing class PortalCaseService {
  public class Result {
    public PortalCaseView view;
    public Boolean created;

    public Result(PortalCaseView view, Boolean created) {
      this.view = view;
      this.created = created;
    }
  }

  public static Result upsertCase(PortalCaseRequest request) {
    CaseSelector cases = new CaseSelector();
    Case existing = cases.selectPortalCaseByExternalId(request.externalId);
    if (existing != null) {
      return new Result(new PortalCaseView(existing), false);
    }

    Contact requester = new ContactSelector()
      .selectFirstByEmail(request.contactEmail);
    Case record = new Case(
      External_Id__c = request.externalId,
      Subject = request.subject,
      Description = request.description,
      Category__c = request.effectiveCategory(),
      Priority = request.effectivePriority(),
      Origin = 'Portal',
      ContactId = requester?.Id,
      AccountId = requester?.AccountId
    );

    try {
      Database.insert(record, AccessLevel.USER_MODE);
    } catch (DmlException error) {
      // Two identical requests raced: the other one created the case first.
      if (error.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
        return new Result(
          new PortalCaseView(
            cases.selectPortalCaseByExternalId(request.externalId)
          ),
          false
        );
      }
      throw error;
    }
    return new Result(
      new PortalCaseView(
        cases.selectPortalCaseByExternalId(request.externalId)
      ),
      true
    );
  }

  public static PortalCaseView getCase(String externalId) {
    if (String.isBlank(externalId)) {
      throw new PortalApi.PortalApiException(
        400,
        'Case external id is required in the URL.',
        null
      );
    }
    Case record = new CaseSelector().selectPortalCaseByExternalId(externalId);
    if (record == null) {
      throw new PortalApi.PortalApiException(
        404,
        'No case with external id ' + externalId + '.',
        null
      );
    }
    return new PortalCaseView(record);
  }
}
