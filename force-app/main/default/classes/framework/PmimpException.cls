/**
 * @description Base exception for PMIMP use-case errors. Carries an error code (see
 * {@link ErrorCodes}), an optional field and optional details, and converts to an
 * {@link ErrorDto}. Subclasses fix the default code; a more specific one can be set:
 * {@code throw new ConflictException('Confirm to reopen the parent').withCode(ErrorCodes.CONFIRMATION_REQUIRED);}
 */
public virtual class PmimpException extends Exception {
  private String code;
  private String field;
  private Map<String, Object> details;

  /**
   * @description Sets a specific error code.
   * @param code code from {@link ErrorCodes}
   * @return this exception
   */
  public PmimpException withCode(String code) {
    this.code = code;
    return this;
  }

  /**
   * @description Names the input field the error is about.
   * @param field field or property name
   * @return this exception
   */
  public PmimpException withField(String field) {
    this.field = field;
    return this;
  }

  /**
   * @description Adds machine-readable details for the client (e.g. affected counts).
   * @param details JSON-serializable values
   * @return this exception
   */
  public PmimpException withDetails(Map<String, Object> details) {
    this.details = details;
    return this;
  }

  /**
   * @description Error code: the one set with {@link #withCode(String)}, else the default.
   * @return error code
   */
  public String getCode() {
    return code != null ? code : defaultCode();
  }

  /**
   * @description Field the error is about, or null.
   * @return field name
   */
  public String getField() {
    return field;
  }

  /**
   * @description Details for the client, or null.
   * @return details map
   */
  public Map<String, Object> getDetails() {
    return details;
  }

  /**
   * @description Code used when none is set. Overridden by subclasses.
   * @return default code
   */
  protected virtual String defaultCode() {
    return ErrorCodes.INTERNAL_ERROR;
  }
}
