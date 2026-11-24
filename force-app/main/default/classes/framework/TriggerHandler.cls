/**
 * @description Base class for all PMIMP trigger handlers. A handler overrides only the
 * contexts it needs; the rest are no-ops. Triggers stay logic-free and call
 * {@code TriggerDispatcher.run(new XTriggerHandler());}.
 *
 * Every context receives the whole trigger batch (up to 200 records per chunk), so
 * implementations must be bulk-safe: no SOQL or DML per record.
 */
public abstract with sharing class TriggerHandler {
  /**
   * @description Default for {@link #getMaxRecursionDepth()}: the outer call plus two
   * nested re-entries (for example parent update -> subtask cascade -> parent reopen).
   */
  public static final Integer DEFAULT_MAX_RECURSION_DEPTH = 3;

  private String name;

  /**
   * @description Name used for bypass and recursion tracking. Defaults to the class name.
   * @return the handler name
   */
  public virtual String getName() {
    if (name == null) {
      name = String.valueOf(this).substringBefore(':');
    }
    return name;
  }

  /**
   * @description How many nested invocations of this handler may run at once (re-entry
   * through DML on the same object). Deeper invocations are skipped.
   * @return maximum nesting depth, at least 1
   */
  public virtual Integer getMaxRecursionDepth() {
    return DEFAULT_MAX_RECURSION_DEPTH;
  }

  /**
   * @description before insert
   * @param newRecords Trigger.new
   */
  public virtual void beforeInsert(List<SObject> newRecords) {
    return;
  }

  /**
   * @description before update
   * @param newRecords Trigger.new
   * @param oldMap Trigger.oldMap
   */
  public virtual void beforeUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> oldMap
  ) {
    return;
  }

  /**
   * @description before delete
   * @param oldMap Trigger.oldMap
   */
  public virtual void beforeDelete(Map<Id, SObject> oldMap) {
    return;
  }

  /**
   * @description after insert
   * @param newMap Trigger.newMap
   */
  public virtual void afterInsert(Map<Id, SObject> newMap) {
    return;
  }

  /**
   * @description after update
   * @param newMap Trigger.newMap
   * @param oldMap Trigger.oldMap
   */
  public virtual void afterUpdate(
    Map<Id, SObject> newMap,
    Map<Id, SObject> oldMap
  ) {
    return;
  }

  /**
   * @description after delete
   * @param oldMap Trigger.oldMap
   */
  public virtual void afterDelete(Map<Id, SObject> oldMap) {
    return;
  }

  /**
   * @description after undelete
   * @param newMap Trigger.newMap
   */
  public virtual void afterUndelete(Map<Id, SObject> newMap) {
    return;
  }
}
