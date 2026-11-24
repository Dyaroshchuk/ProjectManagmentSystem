/**
 * @description Stale data, a concurrent change or a required confirmation (HTTP 409). Default code: {@code ErrorCodes.CONFLICT}.
 */
public virtual class ConflictException extends PmimpException {
  /**
   * @description Default code for this exception type.
   * @return ErrorCodes.CONFLICT
   */
  protected override String defaultCode() {
    return ErrorCodes.CONFLICT;
  }
}
