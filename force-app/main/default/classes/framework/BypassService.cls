/**
 * @description Decides whether trigger automation is skipped. Two paths:
 * <ul>
 *   <li>Custom permission {@code PMIMP_Bypass_Automation}: the running user skips every
 *       PMIMP handler (data migrations, admin fixes).</li>
 *   <li>Programmatic bypass per handler, for the current transaction only, e.g.
 *       {@code BypassService.bypass('WorkItemTriggerHandler')} around a system update.</li>
 * </ul>
 */
public with sharing class BypassService {
  /** API name of the custom permission that bypasses all automation. */
  public static final String BYPASS_PERMISSION = 'PMIMP_Bypass_Automation';

  private static Set<String> bypassedHandlers = new Set<String>();
  private static Map<Id, Boolean> permissionByUser = new Map<Id, Boolean>();

  /**
   * @description Skips a handler for the rest of the transaction (until cleared).
   * @param handlerName handler name, see {@link TriggerHandler#getName()}
   */
  public static void bypass(String handlerName) {
    bypassedHandlers.add(requireName(handlerName));
  }

  /**
   * @description Re-enables a handler bypassed with {@link #bypass(String)}.
   * @param handlerName handler name
   */
  public static void clearBypass(String handlerName) {
    bypassedHandlers.remove(requireName(handlerName));
  }

  /**
   * @description Re-enables all programmatically bypassed handlers.
   */
  public static void clearAllBypasses() {
    bypassedHandlers.clear();
  }

  /**
   * @description True when the handler must not run: the running user has the bypass
   * permission or the handler was bypassed programmatically.
   * @param handlerName handler name
   * @return whether to skip the handler
   */
  public static Boolean isBypassed(String handlerName) {
    return bypassedHandlers.contains(handlerName) || hasBypassPermission();
  }

  /**
   * @description Whether the running user has {@code PMIMP_Bypass_Automation}.
   * Cached per user for the transaction ({@code System.runAs} switches users in tests).
   * @return true if the user bypasses all automation
   */
  public static Boolean hasBypassPermission() {
    Id userId = UserInfo.getUserId();
    if (!permissionByUser.containsKey(userId)) {
      permissionByUser.put(
        userId,
        FeatureManagement.checkPermission(BYPASS_PERMISSION)
      );
    }
    return permissionByUser.get(userId);
  }

  private static String requireName(String handlerName) {
    if (String.isBlank(handlerName)) {
      throw new IllegalArgumentException('Handler name is required.');
    }
    return handlerName;
  }
}
