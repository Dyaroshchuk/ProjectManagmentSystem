/**
 * @description All PMIMP error codes. Validators use them as {@code [CODE] message} in
 * {@code addError}; services and APIs return them in {@link ErrorDto}. Codes are part of
 * the public API contract: never rename one, only add.
 */
public with sharing class ErrorCodes {
  // ---- Generic (map to HTTP 400 / 403 / 404 / 409 / 500 in the REST layer)
  /** @description Invalid input or a broken business rule without a more specific code. */
  public static final String VALIDATION = 'VALIDATION';
  /** @description The user lacks the role or permission for the action. */
  public static final String FORBIDDEN = 'FORBIDDEN';
  /** @description The record doesn't exist or isn't visible to the user. */
  public static final String NOT_FOUND = 'NOT_FOUND';
  /** @description Stale data or a concurrent change (positions, versions, row locks). */
  public static final String CONFLICT = 'CONFLICT';
  /** @description The action has side effects the client must confirm first. */
  public static final String CONFIRMATION_REQUIRED = 'CONFIRMATION_REQUIRED';
  /** @description Unexpected failure; details are only in Log__c. */
  public static final String INTERNAL_ERROR = 'INTERNAL_ERROR';

  // ---- Business rules
  /** @description A parent can't move to DONE while active subtasks aren't DONE. */
  public static final String OPEN_SUBTASKS = 'OPEN_SUBTASKS';
  /** @description A subtask can't be restored under an archived parent. */
  public static final String PARENT_ARCHIVED = 'PARENT_ARCHIVED';
  /** @description Items of an archived project or workspace are read-only. */
  public static final String READ_ONLY_CONTAINER = 'READ_ONLY_CONTAINER';
  /** @description The last Owner of a workspace can't be removed or demoted. */
  public static final String LAST_OWNER = 'LAST_OWNER';
  /** @description A workflow status that items still use can't be removed without a mapping. */
  public static final String STATUS_IN_USE = 'STATUS_IN_USE';

  private static final Pattern CODE_FORMAT = Pattern.compile(
    '^[A-Z][A-Z0-9_]{1,63}$'
  );

  /**
   * @description Whether a string has the shape of an error code (UPPER_SNAKE_CASE).
   * @param code candidate code
   * @return true for a well-formed code
   */
  public static Boolean isWellFormed(String code) {
    return code != null && CODE_FORMAT.matcher(code).matches();
  }

  /**
   * @description Formats a message for {@code record.addError()}: {@code [CODE] message}.
   * @param code error code
   * @param message human-readable message
   * @return formatted message
   */
  public static String format(String code, String message) {
    return '[' + code + '] ' + message;
  }
}
