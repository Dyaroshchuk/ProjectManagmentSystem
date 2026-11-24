/**
 * @description Routes a trigger invocation to the matching {@link TriggerHandler} method.
 * Usage in a trigger (the only line a trigger may contain):
 * {@code TriggerDispatcher.run(new WorkItemTriggerHandler());}
 *
 * Before dispatching it checks {@link BypassService} (custom permission or programmatic
 * bypass) and the handler's recursion guard.
 */
public with sharing class TriggerDispatcher {
  /** Current nesting depth per handler name within this transaction. */
  @TestVisible
  private static Map<String, Integer> depthByHandler = new Map<String, Integer>();

  /**
   * @description Dispatches the current trigger context to the handler.
   * @param handler handler for the trigger's object
   */
  public static void run(TriggerHandler handler) {
    if (!Trigger.isExecuting) {
      throw new TriggerDispatcherException(
        'TriggerDispatcher.run() must be called from a trigger.'
      );
    }
    run(handler, contextFromTrigger());
  }

  /**
   * @description Snapshot of the currently executing trigger (all values are null
   * outside a trigger).
   * @return context built from Trigger.*
   */
  @TestVisible
  private static Context contextFromTrigger() {
    return new Context(Trigger.operationType)
      .withNew(Trigger.new)
      .withNewMap(Trigger.newMap)
      .withOldMap(Trigger.oldMap);
  }

  /**
   * @description Dispatches an explicit context. Separate from {@link #run(TriggerHandler)}
   * so the framework can be unit tested without a trigger.
   * @param handler handler to call
   * @param context trigger context
   */
  @TestVisible
  private static void run(TriggerHandler handler, Context context) {
    if (handler == null) {
      throw new TriggerDispatcherException('Trigger handler is required.');
    }
    String name = handler.getName();
    if (BypassService.isBypassed(name)) {
      return;
    }

    Integer depth = depthByHandler.containsKey(name)
      ? depthByHandler.get(name)
      : 0;
    if (depth >= Math.max(1, handler.getMaxRecursionDepth())) {
      return;
    }

    depthByHandler.put(name, depth + 1);
    TriggerDispatcher.Context outerContext = handler.context;
    handler.context = context;
    try {
      dispatch(handler, context);
    } finally {
      handler.context = outerContext;
      depthByHandler.put(name, depth);
    }
  }

  /**
   * @description Current nesting depth of a handler (0 when it is not running).
   * @param handlerName handler name
   * @return nesting depth
   */
  public static Integer getDepth(String handlerName) {
    return depthByHandler.containsKey(handlerName)
      ? depthByHandler.get(handlerName)
      : 0;
  }

  private static void dispatch(TriggerHandler handler, Context ctx) {
    switch on ctx.operation {
      when BEFORE_INSERT {
        handler.beforeInsert(ctx.newRecords);
      }
      when BEFORE_UPDATE {
        handler.beforeUpdate(ctx.newRecords, ctx.oldMap);
      }
      when BEFORE_DELETE {
        handler.beforeDelete(ctx.oldMap);
      }
      when AFTER_INSERT {
        handler.afterInsert(ctx.newMap);
      }
      when AFTER_UPDATE {
        handler.afterUpdate(ctx.newMap, ctx.oldMap);
      }
      when AFTER_DELETE {
        handler.afterDelete(ctx.oldMap);
      }
      when AFTER_UNDELETE {
        handler.afterUndelete(ctx.newMap);
      }
    }
  }

  /**
   * @description Snapshot of a trigger invocation: operation plus the Trigger.* collections.
   */
  public class Context {
    /** @description trigger operation */
    public final System.TriggerOperation operation;
    /** @description Trigger.new */
    public List<SObject> newRecords { get; private set; }
    /** @description Trigger.newMap */
    public Map<Id, SObject> newMap { get; private set; }
    /** @description Trigger.oldMap */
    public Map<Id, SObject> oldMap { get; private set; }

    /**
     * @description Creates a context for an operation; add collections with the with* methods.
     * @param operation trigger operation
     */
    public Context(System.TriggerOperation operation) {
      this.operation = operation;
    }

    /**
     * @description Sets Trigger.new.
     * @param records new versions of the records
     * @return this context
     */
    public Context withNew(List<SObject> records) {
      this.newRecords = records;
      return this;
    }

    /**
     * @description Sets Trigger.newMap.
     * @param records new versions by Id
     * @return this context
     */
    public Context withNewMap(Map<Id, SObject> records) {
      this.newMap = records;
      return this;
    }

    /**
     * @description Sets Trigger.oldMap.
     * @param records old versions by Id
     * @return this context
     */
    public Context withOldMap(Map<Id, SObject> records) {
      this.oldMap = records;
      return this;
    }
  }

  /**
   * @description Misuse of the dispatcher (called outside a trigger, missing handler).
   */
  public class TriggerDispatcherException extends Exception {
  }
}
