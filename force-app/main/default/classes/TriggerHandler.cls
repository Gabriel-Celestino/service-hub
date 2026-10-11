/**
 * Base class for every trigger handler.
 *
 * Each object has exactly one trigger, which instantiates its handler and
 * calls run(). Handlers override only the events they need. A handler can be
 * bypassed, for example during data loads or in tests.
 */
public virtual class TriggerHandler {
  private static final Set<String> BYPASSED_HANDLERS = new Set<String>();

  private final String handlerName;

  @TestVisible
  private System.TriggerOperation operation;
  @TestVisible
  private List<SObject> newRecords;
  @TestVisible
  private Map<Id, SObject> oldMap;

  public TriggerHandler() {
    // Resolved before any field is set, so the string stays short.
    this.handlerName = String.valueOf(this).substringBefore(':');
    if (Trigger.isExecuting) {
      this.operation = Trigger.operationType;
      this.newRecords = Trigger.new;
      this.oldMap = Trigger.oldMap;
    }
  }

  /**
   * Dispatches the current trigger event to the matching handler method.
   * Does nothing outside a trigger context or when the handler is bypassed.
   */
  public void run() {
    if (operation == null || BYPASSED_HANDLERS.contains(handlerName)) {
      return;
    }
    switch on operation {
      when BEFORE_INSERT {
        beforeInsert(newRecords);
      }
      when BEFORE_UPDATE {
        beforeUpdate(newRecords, oldMap);
      }
      when BEFORE_DELETE {
        beforeDelete(oldMap);
      }
      when AFTER_INSERT {
        afterInsert(newRecords);
      }
      when AFTER_UPDATE {
        afterUpdate(newRecords, oldMap);
      }
      when AFTER_DELETE {
        afterDelete(oldMap);
      }
      when AFTER_UNDELETE {
        afterUndelete(newRecords);
      }
    }
  }

  public static void bypass(Type handlerType) {
    BYPASSED_HANDLERS.add(handlerType.getName());
  }

  public static void clearBypass(Type handlerType) {
    BYPASSED_HANDLERS.remove(handlerType.getName());
  }

  public static Boolean isBypassed(Type handlerType) {
    return BYPASSED_HANDLERS.contains(handlerType.getName());
  }

  protected virtual void beforeInsert(List<SObject> newRecords) {
  }

  protected virtual void beforeUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  protected virtual void beforeDelete(Map<Id, SObject> oldMap) {
  }

  protected virtual void afterInsert(List<SObject> newRecords) {
  }

  protected virtual void afterUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> oldMap
  ) {
  }

  protected virtual void afterDelete(Map<Id, SObject> oldMap) {
  }

  protected virtual void afterUndelete(List<SObject> newRecords) {
  }
}
