/**
 * @description The one error payload of PMIMP, returned by the REST API and (as JSON in an
 * AuraHandledException) to LWC. Built from exceptions:
 * <ul>
 *   <li>{@link PmimpException}: its code, message, field and details.</li>
 *   <li>{@code DmlException} / {@code Database.Error}: the validator message
 *       {@code [CODE] message} is parsed; messages without a code are mapped from the
 *       StatusCode (access -> FORBIDDEN, deleted -> NOT_FOUND, row lock -> CONFLICT,
 *       anything else -> VALIDATION).</li>
 *   <li>Anything else: INTERNAL_ERROR with a generic message; details stay in Log__c.</li>
 * </ul>
 */
public with sharing class ErrorDto {
  private static final Pattern CODED_MESSAGE = Pattern.compile(
    '^\\s*\\[([A-Z][A-Z0-9_]{1,63})\\]\\s*([\\s\\S]*)$'
  );

  private static final Map<System.StatusCode, String> CODE_BY_STATUS = new Map<System.StatusCode, String>{
    System.StatusCode.INSUFFICIENT_ACCESS_OR_READONLY => ErrorCodes.FORBIDDEN,
    System.StatusCode.INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY => ErrorCodes.FORBIDDEN,
    System.StatusCode.ENTITY_IS_DELETED => ErrorCodes.NOT_FOUND,
    System.StatusCode.UNABLE_TO_LOCK_ROW => ErrorCodes.CONFLICT
  };

  /** @description Error code from {@link ErrorCodes}. */
  public String code;
  /** @description Human-readable message (safe to show to the user). */
  public String message;
  /** @description Fields the error is about, if known. */
  public List<String> fields;
  /** @description Record the error is about, if known. */
  public Id recordId;
  /** @description Row of a bulk request the error is about, if known. */
  public Integer rowIndex;
  /** @description Machine-readable details, if any. */
  public Map<String, Object> details;
  /** @description Request ID; matches Log__c.Correlation_Id__c. */
  public String correlationId;

  /**
   * @description Creates an error with the current correlation ID.
   * @param code error code
   * @param message message
   */
  public ErrorDto(String code, String message) {
    this.code = code;
    this.message = message;
    this.correlationId = Logger.getCorrelationId();
  }

  /**
   * @description Converts any exception; for a DmlException, the first failed row.
   * @param e exception
   * @return error payload
   */
  public static ErrorDto fromException(Exception e) {
    if (e instanceof PmimpException) {
      PmimpException pe = (PmimpException) e;
      ErrorDto dto = new ErrorDto(pe.getCode(), pe.getMessage());
      if (pe.getField() != null) {
        dto.fields = new List<String>{ pe.getField() };
      }
      dto.details = pe.getDetails();
      return dto;
    }
    // Only DmlExceptions raised by DML have rows; one constructed in code would throw an
    // uncatchable UnexpectedException on getNumDml(), so never construct DmlException.
    if (e instanceof DmlException && ((DmlException) e).getNumDml() > 0) {
      return fromDmlException((DmlException) e)[0];
    }
    return new ErrorDto(
      ErrorCodes.INTERNAL_ERROR,
      System.Label.PMIMP_Error_Unexpected
    );
  }

  /**
   * @description One error per failed row of a DML operation.
   * @param e DML exception
   * @return errors in row order
   */
  public static List<ErrorDto> fromDmlException(DmlException e) {
    List<ErrorDto> errors = new List<ErrorDto>();
    for (Integer i = 0; i < e.getNumDml(); i++) {
      ErrorDto dto = fromMessage(e.getDmlMessage(i), e.getDmlType(i));
      dto.rowIndex = e.getDmlIndex(i);
      dto.recordId = e.getDmlId(i);
      List<String> fieldNames = e.getDmlFieldNames(i);
      if (fieldNames != null && !fieldNames.isEmpty()) {
        dto.fields = fieldNames;
      }
      errors.add(dto);
    }
    return errors;
  }

  /**
   * @description Converts an error from a partial-success DML call (allOrNone = false).
   * @param error database error
   * @return error payload
   */
  public static ErrorDto fromDatabaseError(Database.Error error) {
    ErrorDto dto = fromMessage(error.getMessage(), error.getStatusCode());
    List<String> fieldNames = error.getFields();
    if (fieldNames != null && !fieldNames.isEmpty()) {
      dto.fields = fieldNames;
    }
    return dto;
  }

  /**
   * @description Parses {@code [CODE] message}; without a code, maps the status code.
   * @param rawMessage DML message
   * @param status DML status code, may be null
   * @return error payload
   */
  @TestVisible
  private static ErrorDto fromMessage(
    String rawMessage,
    System.StatusCode status
  ) {
    Matcher m = CODED_MESSAGE.matcher(rawMessage == null ? '' : rawMessage);
    if (m.matches()) {
      return new ErrorDto(m.group(1), m.group(2).trim());
    }
    String code = (status != null && CODE_BY_STATUS.containsKey(status))
      ? CODE_BY_STATUS.get(status)
      : ErrorCodes.VALIDATION;
    return new ErrorDto(code, rawMessage == null ? '' : rawMessage.trim());
  }

  /**
   * @description Wraps this payload for LWC: the message is the JSON of this DTO, so the
   * client parses {@code error.body.message}.
   * @return exception to throw from an @AuraEnabled method
   */
  public AuraHandledException toAuraHandledException() {
    String payload = JSON.serialize(this, true);
    AuraHandledException ex = new AuraHandledException(payload);
    ex.setMessage(payload);
    return ex;
  }
}
