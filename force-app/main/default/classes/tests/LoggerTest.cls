@IsTest
private class LoggerTest {
  private static List<Log__c> deliverAndQuery() {
    Test.getEventBus().deliver();
    return [
      SELECT
        Type__c,
        Message__c,
        Code__c,
        Source__c,
        Stack_Trace__c,
        Correlation_Id__c,
        User__c,
        Record_Id__c,
        Context__c,
        Logged_At__c
      FROM Log__c
      WITH SYSTEM_MODE
      ORDER BY Logged_At__c, Name
      LIMIT 5000
    ];
  }

  @IsTest
  static void entriesArePublishedAndStoredInLog() {
    Id recordId = UserInfo.getUserId();
    Logger.error('SvcA.run', 'Error message')
      .withRecordId(recordId)
      .withCode(ErrorCodes.CONFLICT);
    Logger.warn('SvcB.run', 'Warn message')
      .withContext(new Map<String, Object>{ 'count' => 2 });
    Logger.info('SvcC.run', 'Info message');
    Assert.areEqual(3, Logger.pendingCount());

    Logger.flush();
    Assert.areEqual(0, Logger.pendingCount());

    List<Log__c> logs = deliverAndQuery();
    Assert.areEqual(3, logs.size());
    Map<String, Log__c> byType = new Map<String, Log__c>();
    for (Log__c log : logs) {
      byType.put(log.Type__c, log);
      Assert.areEqual(UserInfo.getUserId(), log.User__c);
      Assert.areEqual(Logger.getCorrelationId(), log.Correlation_Id__c);
      Assert.isNotNull(log.Logged_At__c);
    }
    Log__c error = byType.get(Logger.TYPE_ERROR);
    Assert.areEqual('Error message', error.Message__c);
    Assert.areEqual('SvcA.run', error.Source__c);
    Assert.areEqual(ErrorCodes.CONFLICT, error.Code__c);
    Assert.areEqual(recordId, error.Record_Id__c);
    Assert.areEqual('{"count":2}', byType.get(Logger.TYPE_WARN).Context__c);
    Assert.areEqual('Info message', byType.get(Logger.TYPE_INFO).Message__c);
  }

  @IsTest
  static void exceptionEntryHasStackTraceAndCode() {
    try {
      throw new ForbiddenException('Only admins can edit workflows.');
    } catch (Exception e) {
      Logger.error('WorkflowService.save', e);
    }
    Logger.flush();
    Log__c log = deliverAndQuery()[0];
    Assert.areEqual(Logger.TYPE_ERROR, log.Type__c);
    Assert.areEqual('Only admins can edit workflows.', log.Message__c);
    Assert.areEqual(ErrorCodes.FORBIDDEN, log.Code__c);
    Assert.isTrue(
      log.Stack_Trace__c.startsWith('ForbiddenException'),
      log.Stack_Trace__c
    );
  }

  @IsTest
  static void nonPmimpExceptionHasNoCode() {
    Logger.error('X.y', new MathException('boom'));
    Logger.flush();
    Log__c log = deliverAndQuery()[0];
    Assert.isNull(log.Code__c);
    Assert.isTrue(
      log.Stack_Trace__c.startsWith('System.MathException'),
      log.Stack_Trace__c
    );
  }

  @IsTest
  static void nullExceptionIsSafe() {
    Logger.error('X.y', (Exception) null);
    Assert.areEqual(1, Logger.pendingCount());
  }

  // ---- Bulk safety -----------------------------------------------------------

  @IsTest
  static void twoHundredEntriesCostOnePublish() {
    for (Integer i = 0; i < 200; i++) {
      Logger.info('Bulk.run', 'Entry ' + i).withRecordId(UserInfo.getUserId());
    }
    Integer dmlBefore = Limits.getPublishImmediateDML();
    Logger.flush();
    Assert.areEqual(
      1,
      Limits.getPublishImmediateDML() - dmlBefore,
      'flush must publish in one call'
    );
    Assert.areEqual(200, deliverAndQuery().size());
  }

  @IsTest
  static void emptyFlushDoesNothing() {
    Integer dmlBefore = Limits.getPublishImmediateDML();
    Logger.flush();
    Assert.areEqual(dmlBefore, Limits.getPublishImmediateDML());
  }

  @IsTest
  static void bufferIsCapped() {
    for (Integer i = 0; i < Logger.MAX_BUFFER + 5; i++) {
      Logger.info('Cap.run', 'x');
    }
    Assert.areEqual(Logger.MAX_BUFFER, Logger.pendingCount());
  }

  // ---- Never throws ----------------------------------------------------------

  @IsTest
  static void publishFailureDoesNotThrow() {
    Logger.error('X.y', 'lost on purpose');
    Logger.simulatePublishFailure = true;
    Logger.flush(); // must not throw
    Assert.areEqual(
      0,
      Logger.pendingCount(),
      'buffer is cleared even when publish fails'
    );
    Logger.simulatePublishFailure = false;
    Assert.areEqual(0, deliverAndQuery().size());
  }

  @IsTest
  static void exhaustedPublishLimitDropsEntriesWithoutThrowing() {
    Integer remaining =
      Limits.getLimitPublishImmediateDML() - Limits.getPublishImmediateDML();
    for (Integer i = 0; i < remaining; i++) {
      EventBus.publish(new Log_Event__e(Type__c = Logger.TYPE_INFO));
    }
    Logger.error('X.y', 'no allowance left');
    Logger.flush(); // must not throw
    Assert.areEqual(0, Logger.pendingCount());
    Assert.areEqual(
      Limits.getLimitPublishImmediateDML(),
      Limits.getPublishImmediateDML(),
      'flush must not attempt a publish over the limit'
    );
  }

  @IsTest
  static void longValuesAreTruncated() {
    String longText = 'x'.repeat(Logger.MAX_MESSAGE + 100);
    Logger.error('Y'.repeat(300), longText)
      .withContext(
        new Map<String, Object>{ 'blob' => 'z'.repeat(Logger.MAX_CONTEXT) }
      );
    Logger.flush();
    Log__c log = deliverAndQuery()[0];
    Assert.areEqual(Logger.MAX_MESSAGE, log.Message__c.length());
    Assert.areEqual(255, log.Source__c.length());
    Assert.areEqual(Logger.MAX_CONTEXT, log.Context__c.length());
  }

  @IsTest
  static void entryMethodsAreSafeOnDetachedEntry() {
    for (Integer i = 0; i < Logger.MAX_BUFFER; i++) {
      Logger.info('Cap.run', 'x');
    }
    Logger.Entry detached = Logger.error('Over.cap', 'not buffered');
    detached.withCode('X').withRecordId(null).withContext(null);
    Assert.areEqual(Logger.MAX_BUFFER, Logger.pendingCount());
  }

  // ---- Correlation ID --------------------------------------------------------

  @IsTest
  static void correlationIdDefaultsToRequestId() {
    String requestId = Request.getCurrent().getRequestId();
    Assert.areEqual(requestId, Logger.getCorrelationId());
  }

  @IsTest
  static void correlationIdCanBeOverriddenAndReset() {
    Logger.setCorrelationId('client-abc-123');
    Assert.areEqual('client-abc-123', Logger.getCorrelationId());
    Logger.setCorrelationId('');
    Assert.areEqual(
      Request.getCurrent().getRequestId(),
      Logger.getCorrelationId()
    );
  }

  // ---- Event handler ---------------------------------------------------------

  @IsTest
  static void invalidUserIdInEventIsIgnored() {
    EventBus.publish(
      new Log_Event__e(
        Type__c = Logger.TYPE_WARN,
        Message__c = 'from outside',
        User_Id__c = 'not-an-id'
      )
    );
    List<Log__c> logs = deliverAndQuery();
    Assert.areEqual(1, logs.size());
    Assert.isNull(logs[0].User__c);
    Assert.areEqual('from outside', logs[0].Message__c);
  }
}
