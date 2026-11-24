trigger LogEventTrigger on Log_Event__e(after insert) {
  TriggerDispatcher.run(new LogEventTriggerHandler());
}
