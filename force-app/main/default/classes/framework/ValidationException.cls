/**
 * @description Invalid input or a broken business rule (HTTP 400). Default code: {@code ErrorCodes.VALIDATION}.
 */
public virtual class ValidationException extends PmimpException {
  /**
   * @description Default code for this exception type.
   * @return ErrorCodes.VALIDATION
   */
  protected override String defaultCode() {
    return ErrorCodes.VALIDATION;
  }
}
