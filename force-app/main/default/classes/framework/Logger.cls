/**
 * @description Technical logging to Log__c. Entries are buffered and published together
 * as Log_Event__e (Publish Immediately), so they survive a rolled-back transaction; a
 * trigger on the event writes Log__c.
 *
 * <pre>
 * try { ... } catch (Exception e) {
 *   Logger.error('WorkItemService.move', e).withRecordId(itemId);
 *   Logger.flush();
 *   throw ErrorDto.fromException(e).toAuraHandledException();
 * }
 * </pre>
 *
 * Bulk-safe: any number of entries cost one publish call in {@link #flush()}.
 * Never throws: logging must not break the business transaction, so every public method
 * swallows its own failures.
 */
public with sharing class Logger {
  /** @description Log__c.Type__c value for errors. */
  public static final String TYPE_ERROR = 'Error';
  /** @description Log__c.Type__c value for warnings. */
  public static final String TYPE_WARN = 'Warn';
  /** @description Log__c.Type__c value for info. */
  public static final String TYPE_INFO = 'Info';

  @TestVisible
  private static final Integer MAX_MESSAGE = 32768;
  @TestVisible
  private static final Integer MAX_CONTEXT = 131072;
  @TestVisible
  private static final Integer MAX_BUFFER = 2000;

  private static List<Log_Event__e> buffer = new List<Log_Event__e>();
  private static String correlationId;

  /** Test hook: make the next publish fail, to prove flush() never throws. */
  @TestVisible
  private static Boolean simulatePublishFailure = false;

  /**
   * @description Logs an error message.
   * @param source Class.method or component name
   * @param message message
   * @return entry, for optional details
   */
  public static Entry error(String source, String message) {
    return add(TYPE_ERROR, source, message);
  }

  /**
   * @description Logs an exception: message, type and stack trace, and its code if it is
   * a {@link PmimpException}.
   * @param source Class.method or component name
   * @param e exception
   * @return entry, for optional details
   */
  public static Entry error(String source, Exception e) {
    Entry entry = add(TYPE_ERROR, source, e == null ? null : e.getMessage());
    if (e != null) {
      entry.withStackTrace(e);
    }
    if (e instanceof PmimpException) {
      entry.withCode(((PmimpException) e).getCode());
    }
    return entry;
  }

  /**
   * @description Logs a warning.
   * @param source Class.method or component name
   * @param message message
   * @return entry, for optional details
   */
  public static Entry warn(String source, String message) {
    return add(TYPE_WARN, source, message);
  }

  /**
   * @description Logs an informational message.
   * @param source Class.method or component name
   * @param message message
   * @return entry, for optional details
   */
  public static Entry info(String source, String message) {
    return add(TYPE_INFO, source, message);
  }

  /**
   * @description Publishes all buffered entries in one call and clears the buffer.
   * Does nothing when the buffer is empty. Never throws.
   */
  public static void flush() {
    if (buffer.isEmpty()) {
      return;
    }
    List<Log_Event__e> events = buffer;
    buffer = new List<Log_Event__e>();
    try {
      if (simulatePublishFailure) {
        throw new LoggerException('Simulated publish failure');
      }
      if (
        Limits.getPublishImmediateDML() >= Limits.getLimitPublishImmediateDML()
      ) {
        return; // no immediate-publish allowance left: drop rather than break the transaction
      }
      EventBus.publish(events);
    } catch (Exception e) {
      // Logging must never fail the caller. Nothing else can record this failure.
      return;
    }
  }

  /**
   * @description Number of entries waiting for {@link #flush()}.
   * @return buffered entry count
   */
  public static Integer pendingCount() {
    return buffer.size();
  }

  /**
   * @description Correlation ID of this transaction: set explicitly (e.g. from an API
   * header) or the platform request ID.
   * @return correlation ID
   */
  public static String getCorrelationId() {
    if (correlationId == null) {
      try {
        correlationId = Request.getCurrent().getRequestId();
      } catch (Exception e) {
        correlationId = String.valueOf(Crypto.getRandomLong());
      }
    }
    return correlationId;
  }

  /**
   * @description Overrides the correlation ID for the rest of the transaction.
   * @param value correlation ID (blank resets to the request ID)
   */
  public static void setCorrelationId(String value) {
    correlationId = String.isBlank(value) ? null : value.left(100);
  }

  private static Entry add(String type, String source, String message) {
    Entry entry = new Entry();
    try {
      if (buffer.size() >= MAX_BUFFER) {
        return entry; // detached entry: calls on it still work, nothing is published
      }
      entry.event.Type__c = type;
      entry.event.Source__c = truncate(source, 255);
      entry.event.Message__c = truncate(message, MAX_MESSAGE);
      entry.event.Correlation_Id__c = getCorrelationId();
      entry.event.User_Id__c = UserInfo.getUserId();
      entry.event.Logged_At__c = System.now();
      buffer.add(entry.event);
    } catch (Exception ignored) {
      return entry;
    }
    return entry;
  }

  private static String truncate(String value, Integer maxLength) {
    return value == null ? null : value.abbreviate(maxLength);
  }

  /**
   * @description Optional details for a log entry. All methods are safe to chain and never throw.
   */
  public class Entry {
    private final Log_Event__e event = new Log_Event__e();

    /**
     * @description Sets the related record.
     * @param recordId record ID
     * @return this entry
     */
    public Entry withRecordId(Id recordId) {
      event.Record_Id__c = recordId;
      return this;
    }

    /**
     * @description Sets the error code.
     * @param code code from {@link ErrorCodes}
     * @return this entry
     */
    public Entry withCode(String code) {
      event.Code__c = truncate(code, 80);
      return this;
    }

    /**
     * @description Sets exception type and stack trace.
     * @param e exception
     * @return this entry
     */
    public Entry withStackTrace(Exception e) {
      try {
        event.Stack_Trace__c = truncate(
          e.getTypeName() + '\n' + e.getStackTraceString(),
          MAX_MESSAGE
        );
      } catch (Exception ignored) {
        event.Stack_Trace__c = null;
      }
      return this;
    }

    /**
     * @description Attaches context, serialized as JSON.
     * @param context any JSON-serializable value
     * @return this entry
     */
    public Entry withContext(Object context) {
      try {
        event.Context__c = truncate(JSON.serialize(context, true), MAX_CONTEXT);
      } catch (Exception e) {
        event.Context__c = 'Context not serializable: ' + e.getMessage();
      }
      return this;
    }
  }

  private class LoggerException extends Exception {
  }
}
