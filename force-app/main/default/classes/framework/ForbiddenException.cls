/**
 * @description The user lacks the role or permission for the action (HTTP 403). Default code: {@code ErrorCodes.FORBIDDEN}.
 */
public virtual class ForbiddenException extends PmimpException {
  /**
   * @description Default code for this exception type.
   * @return ErrorCodes.FORBIDDEN
   */
  protected override String defaultCode() {
    return ErrorCodes.FORBIDDEN;
  }
}
