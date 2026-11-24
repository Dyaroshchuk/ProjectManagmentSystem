/**
 * @description Writes Log__c rows for published Log_Event__e events (runs as the
 * Automated Process user). Partial success: one bad event never blocks the others.
 */
public with sharing class LogEventTriggerHandler extends TriggerHandler {
  /**
   * @description Platform event triggers only fire after insert and have no Trigger.newMap,
   * so the events are read from the context.
   * @param newMap unused (null for platform events)
   */
  public override void afterInsert(Map<Id, SObject> newMap) {
    List<Log__c> logs = new List<Log__c>();
    for (SObject record : context.newRecords) {
      Log_Event__e evt = (Log_Event__e) record;
      logs.add(
        new Log__c(
          Type__c = evt.Type__c,
          Message__c = evt.Message__c,
          Code__c = evt.Code__c,
          Source__c = evt.Source__c,
          Stack_Trace__c = evt.Stack_Trace__c,
          Correlation_Id__c = evt.Correlation_Id__c,
          User__c = toId(evt.User_Id__c),
          Record_Id__c = evt.Record_Id__c,
          Context__c = evt.Context__c,
          Logged_At__c = evt.Logged_At__c
        )
      );
    }
    Database.insert(logs, false, System.AccessLevel.SYSTEM_MODE);
  }

  private static Id toId(String value) {
    try {
      return String.isBlank(value) ? null : Id.valueOf(value);
    } catch (Exception e) {
      return null;
    }
  }
}
