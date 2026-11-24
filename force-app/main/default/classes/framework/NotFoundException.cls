/**
 * @description The record doesn't exist or isn't visible to the user (HTTP 404). Default code: {@code ErrorCodes.NOT_FOUND}.
 */
public virtual class NotFoundException extends PmimpException {
  /**
   * @description Default code for this exception type.
   * @return ErrorCodes.NOT_FOUND
   */
  protected override String defaultCode() {
    return ErrorCodes.NOT_FOUND;
  }
}
