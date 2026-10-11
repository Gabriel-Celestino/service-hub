@IsTest
private class TriggerHandlerTest {
  /** Records which handler method was called. */
  private class RecordingHandler extends TriggerHandler {
    public List<String> calls = new List<String>();

    protected override void beforeInsert(List<SObject> newRecords) {
      calls.add('beforeInsert');
    }
    protected override void beforeUpdate(
      List<SObject> newRecords,
      Map<Id, SObject> oldMap
    ) {
      calls.add('beforeUpdate');
    }
    protected override void beforeDelete(Map<Id, SObject> oldMap) {
      calls.add('beforeDelete');
    }
    protected override void afterInsert(List<SObject> newRecords) {
      calls.add('afterInsert');
    }
    protected override void afterUpdate(
      List<SObject> newRecords,
      Map<Id, SObject> oldMap
    ) {
      calls.add('afterUpdate');
    }
    protected override void afterDelete(Map<Id, SObject> oldMap) {
      calls.add('afterDelete');
    }
    protected override void afterUndelete(List<SObject> newRecords) {
      calls.add('afterUndelete');
    }
  }

  @IsTest
  static void dispatchesEachOperationToItsMethod() {
    Map<System.TriggerOperation, String> expectedMethods = new Map<System.TriggerOperation, String>{
      System.TriggerOperation.BEFORE_INSERT => 'beforeInsert',
      System.TriggerOperation.BEFORE_UPDATE => 'beforeUpdate',
      System.TriggerOperation.BEFORE_DELETE => 'beforeDelete',
      System.TriggerOperation.AFTER_INSERT => 'afterInsert',
      System.TriggerOperation.AFTER_UPDATE => 'afterUpdate',
      System.TriggerOperation.AFTER_DELETE => 'afterDelete',
      System.TriggerOperation.AFTER_UNDELETE => 'afterUndelete'
    };

    for (System.TriggerOperation operation : expectedMethods.keySet()) {
      RecordingHandler handler = new RecordingHandler();
      TriggerHandler base = handler;
      base.operation = operation;

      handler.run();

      Assert.areEqual(
        new List<String>{ expectedMethods.get(operation) },
        handler.calls,
        'Operation ' + operation + ' should call exactly one matching method'
      );
    }
  }

  @IsTest
  static void doesNothingOutsideTriggerContext() {
    RecordingHandler handler = new RecordingHandler();

    handler.run();

    Assert.isTrue(
      handler.calls.isEmpty(),
      'No method should run outside a trigger'
    );
  }

  @IsTest
  static void bypassCanBeSetAndCleared() {
    TriggerHandler.bypass(CaseTriggerHandler.class);
    Assert.isTrue(
      TriggerHandler.isBypassed(CaseTriggerHandler.class),
      'Handler should be bypassed'
    );

    TriggerHandler.clearBypass(CaseTriggerHandler.class);
    Assert.isFalse(
      TriggerHandler.isBypassed(CaseTriggerHandler.class),
      'Bypass should be cleared'
    );
  }
}
