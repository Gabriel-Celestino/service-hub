/**
 * Queries on Contact.
 */
public inherited sharing class ContactSelector {
  /** The oldest contact with this email, or null. */
  public Contact selectFirstByEmail(String email) {
    if (String.isBlank(email)) {
      return null;
    }
    List<Contact> contacts = [
      SELECT Id, AccountId
      FROM Contact
      WHERE Email = :email
      WITH SYSTEM_MODE
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    return contacts.isEmpty() ? null : contacts[0];
  }
}
