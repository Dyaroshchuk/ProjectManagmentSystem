@IsTest
private class TriggerDispatcherTest {
  private static final Id ID_1 = fakeId(1);
  private static final Id ID_2 = fakeId(2);

  private static Id fakeId(Integer n) {
    String suffix = String.valueOf(n);
    return Id.valueOf('001' + '0'.repeat(12 - suffix.length()) + suffix);
  }

  private static List<SObject> newList() {
    return new List<SObject>{
      new Account(Id = ID_1, Name = 'New 1'),
      new Account(Id = ID_2, Name = 'New 2')
    };
  }

  private static Map<Id, SObject> newMap() {
    return new Map<Id, SObject>(newList());
  }

  private static Map<Id, SObject> oldMap() {
    return new Map<Id, SObject>{
      ID_1 => new Account(Id = ID_1, Name = 'Old 1')
    };
  }

  /** Records which context ran and with what arguments. */
  private class RecordingHandler extends TriggerHandler {
    List<String> calls = new List<String>();
    List<SObject> receivedNew;
    Map<Id, SObject> receivedNewMap;
    Map<Id, SObject> receivedOldMap;

    public override String getName() {
      return 'RecordingHandler';
    }
    public override void beforeInsert(List<SObject> newRecords) {
      calls.add('beforeInsert');
      receivedNew = newRecords;
    }
    public override void beforeUpdate(
      List<SObject> newRecords,
      Map<Id, SObject> oldMap
    ) {
      calls.add('beforeUpdate');
      receivedNew = newRecords;
      receivedOldMap = oldMap;
    }
    public override void beforeDelete(Map<Id, SObject> oldMap) {
      calls.add('beforeDelete');
      receivedOldMap = oldMap;
    }
    public override void afterInsert(Map<Id, SObject> newMap) {
      calls.add('afterInsert');
      receivedNewMap = newMap;
    }
    public override void afterUpdate(
      Map<Id, SObject> newMap,
      Map<Id, SObject> oldMap
    ) {
      calls.add('afterUpdate');
      receivedNewMap = newMap;
      receivedOldMap = oldMap;
    }
    public override void afterDelete(Map<Id, SObject> oldMap) {
      calls.add('afterDelete');
      receivedOldMap = oldMap;
    }
    public override void afterUndelete(Map<Id, SObject> newMap) {
      calls.add('afterUndelete');
      receivedNewMap = newMap;
    }
  }

  /** Re-enters the dispatcher from beforeInsert, like DML on the same object would. */
  private class ReentrantHandler extends TriggerHandler {
    Integer invocations = 0;
    Integer maxDepth = TriggerHandler.DEFAULT_MAX_RECURSION_DEPTH;
    List<Integer> depthsSeen = new List<Integer>();

    public override String getName() {
      return 'ReentrantHandler';
    }
    public override Integer getMaxRecursionDepth() {
      return maxDepth;
    }
    public override void beforeInsert(List<SObject> newRecords) {
      invocations++;
      depthsSeen.add(TriggerDispatcher.getDepth(getName()));
      if (invocations < 10) {
        TriggerDispatcher.run(
          this,
          new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
            .withNew(newRecords)
        );
      }
    }
  }

  private class FailingHandler extends TriggerHandler {
    public override String getName() {
      return 'FailingHandler';
    }
    public override void beforeInsert(List<SObject> newRecords) {
      throw new IllegalArgumentException('boom');
    }
  }

  private class DefaultHandler extends TriggerHandler {
  }

  // ---- Dispatch per context ----------------------------------------------

  @IsTest
  static void beforeInsertGetsNewList() {
    RecordingHandler h = new RecordingHandler();
    List<SObject> records = newList();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
        .withNew(records)
    );
    Assert.areEqual(new List<String>{ 'beforeInsert' }, h.calls);
    Assert.areEqual(records, h.receivedNew);
  }

  @IsTest
  static void beforeUpdateGetsNewListAndOldMap() {
    RecordingHandler h = new RecordingHandler();
    List<SObject> records = newList();
    Map<Id, SObject> old = oldMap();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_UPDATE)
        .withNew(records)
        .withNewMap(newMap())
        .withOldMap(old)
    );
    Assert.areEqual(new List<String>{ 'beforeUpdate' }, h.calls);
    Assert.areEqual(records, h.receivedNew);
    Assert.areEqual(old, h.receivedOldMap);
  }

  @IsTest
  static void beforeDeleteGetsOldMap() {
    RecordingHandler h = new RecordingHandler();
    Map<Id, SObject> old = oldMap();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_DELETE)
        .withOldMap(old)
    );
    Assert.areEqual(new List<String>{ 'beforeDelete' }, h.calls);
    Assert.areEqual(old, h.receivedOldMap);
  }

  @IsTest
  static void afterInsertGetsNewMap() {
    RecordingHandler h = new RecordingHandler();
    Map<Id, SObject> records = newMap();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.AFTER_INSERT)
        .withNew(newList())
        .withNewMap(records)
    );
    Assert.areEqual(new List<String>{ 'afterInsert' }, h.calls);
    Assert.areEqual(records, h.receivedNewMap);
  }

  @IsTest
  static void afterUpdateGetsNewMapAndOldMap() {
    RecordingHandler h = new RecordingHandler();
    Map<Id, SObject> records = newMap();
    Map<Id, SObject> old = oldMap();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.AFTER_UPDATE)
        .withNew(newList())
        .withNewMap(records)
        .withOldMap(old)
    );
    Assert.areEqual(new List<String>{ 'afterUpdate' }, h.calls);
    Assert.areEqual(records, h.receivedNewMap);
    Assert.areEqual(old, h.receivedOldMap);
  }

  @IsTest
  static void afterDeleteGetsOldMap() {
    RecordingHandler h = new RecordingHandler();
    Map<Id, SObject> old = oldMap();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.AFTER_DELETE)
        .withOldMap(old)
    );
    Assert.areEqual(new List<String>{ 'afterDelete' }, h.calls);
    Assert.areEqual(old, h.receivedOldMap);
  }

  @IsTest
  static void afterUndeleteGetsNewMap() {
    RecordingHandler h = new RecordingHandler();
    Map<Id, SObject> records = newMap();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.AFTER_UNDELETE)
        .withNew(newList())
        .withNewMap(records)
    );
    Assert.areEqual(new List<String>{ 'afterUndelete' }, h.calls);
    Assert.areEqual(records, h.receivedNewMap);
  }

  @IsTest
  static void baseHandlerContextsAreNoOps() {
    DefaultHandler h = new DefaultHandler();
    for (System.TriggerOperation op : System.TriggerOperation.values()) {
      TriggerDispatcher.run(
        h,
        new TriggerDispatcher.Context(op)
          .withNew(newList())
          .withNewMap(newMap())
          .withOldMap(oldMap())
      );
    }
    Assert.areEqual(
      0,
      TriggerDispatcher.getDepth(h.getName()),
      'depth must be back to 0 after each call'
    );
  }

  @IsTest
  static void defaultNameIsClassName() {
    String name = new DefaultHandler().getName();
    Assert.isTrue(
      name.endsWith('DefaultHandler'),
      'unexpected default name: ' + name
    );
    Assert.isFalse(
      name.contains(':'),
      'name must not include field values: ' + name
    );
  }

  @IsTest
  static void runOutsideTriggerThrows() {
    try {
      TriggerDispatcher.run(new RecordingHandler());
      Assert.fail('expected TriggerDispatcherException');
    } catch (TriggerDispatcher.TriggerDispatcherException e) {
      Assert.isTrue(
        e.getMessage().contains('must be called from a trigger'),
        e.getMessage()
      );
    }
  }

  @IsTest
  static void nullHandlerThrows() {
    try {
      TriggerDispatcher.run(
        null,
        new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
          .withNew(newList())
      );
      Assert.fail('expected TriggerDispatcherException');
    } catch (TriggerDispatcher.TriggerDispatcherException e) {
      Assert.isTrue(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void contextFromTriggerIsEmptyOutsideTrigger() {
    TriggerDispatcher.Context ctx = TriggerDispatcher.contextFromTrigger();
    Assert.isNull(ctx.operation);
    Assert.isNull(ctx.newRecords);
    Assert.isNull(ctx.newMap);
    Assert.isNull(ctx.oldMap);
  }

  @IsTest
  static void contextKeepsWhatWasSet() {
    List<SObject> records = newList();
    Map<Id, SObject> recordMap = newMap();
    Map<Id, SObject> old = oldMap();
    TriggerDispatcher.Context ctx = new TriggerDispatcher.Context(
        System.TriggerOperation.AFTER_UPDATE
      )
      .withNew(records)
      .withNewMap(recordMap)
      .withOldMap(old);
    Assert.areEqual(System.TriggerOperation.AFTER_UPDATE, ctx.operation);
    Assert.areEqual(records, ctx.newRecords);
    Assert.areEqual(recordMap, ctx.newMap);
    Assert.areEqual(old, ctx.oldMap);
  }

  // ---- Recursion guard ---------------------------------------------------

  @IsTest
  static void recursionStopsAtDefaultDepth() {
    ReentrantHandler h = new ReentrantHandler();
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
        .withNew(newList())
    );
    Assert.areEqual(TriggerHandler.DEFAULT_MAX_RECURSION_DEPTH, h.invocations);
    Assert.areEqual(new List<Integer>{ 1, 2, 3 }, h.depthsSeen);
    Assert.areEqual(0, TriggerDispatcher.getDepth('ReentrantHandler'));
  }

  @IsTest
  static void recursionDepthCanBeOverridden() {
    ReentrantHandler h = new ReentrantHandler();
    h.maxDepth = 1;
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
        .withNew(newList())
    );
    Assert.areEqual(1, h.invocations, 'max depth 1 must block any re-entry');
  }

  @IsTest
  static void recursionDepthBelowOneIsTreatedAsOne() {
    ReentrantHandler h = new ReentrantHandler();
    h.maxDepth = 0;
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
        .withNew(newList())
    );
    Assert.areEqual(1, h.invocations, 'the outer call must always run');
  }

  @IsTest
  static void sequentialCallsAreNotRecursion() {
    // Large DML fires the trigger in 200-record chunks one after another.
    RecordingHandler h = new RecordingHandler();
    for (Integer i = 0; i < 5; i++) {
      TriggerDispatcher.run(
        h,
        new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
          .withNew(newList())
      );
    }
    Assert.areEqual(5, h.calls.size());
  }

  @IsTest
  static void depthIsRestoredWhenHandlerThrows() {
    FailingHandler h = new FailingHandler();
    try {
      TriggerDispatcher.run(
        h,
        new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
          .withNew(newList())
      );
      Assert.fail('expected the handler exception');
    } catch (IllegalArgumentException e) {
      Assert.areEqual('boom', e.getMessage());
    }
    Assert.areEqual(0, TriggerDispatcher.getDepth('FailingHandler'));
  }

  // ---- Programmatic bypass (dispatcher side) ------------------------------

  @IsTest
  static void bypassedHandlerIsSkipped() {
    RecordingHandler h = new RecordingHandler();
    BypassService.bypass('RecordingHandler');
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
        .withNew(newList())
    );
    Assert.areEqual(0, h.calls.size(), 'bypassed handler must not run');

    BypassService.clearBypass('RecordingHandler');
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
        .withNew(newList())
    );
    Assert.areEqual(
      1,
      h.calls.size(),
      'handler must run again after clearBypass'
    );
  }

  @IsTest
  static void bypassOfOtherHandlerDoesNotAffectThisOne() {
    RecordingHandler h = new RecordingHandler();
    BypassService.bypass('SomeOtherHandler');
    TriggerDispatcher.run(
      h,
      new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
        .withNew(newList())
    );
    Assert.areEqual(1, h.calls.size());
  }
}
