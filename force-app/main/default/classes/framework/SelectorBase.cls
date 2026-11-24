/**
 * @description Base class for selectors (one per object). Builds SOQL from a fixed field
 * list and runs it with bind variables only, in USER_MODE by default (CRUD, FLS and
 * sharing of the running user). Only KeyService and SharingService may use selectors
 * that override {@link #getAccessLevel()}.
 *
 * <pre>
 * public with sharing class ProjectSelector extends SelectorBase {
 *   protected override Schema.SObjectType getSObjectType() { return Project__c.SObjectType; }
 *   protected override List<Schema.SObjectField> getFields() {
 *     return new List<Schema.SObjectField>{ Project__c.Name, Project__c.Key_Prefix__c };
 *   }
 *   public List<Project__c> selectByWorkspace(Set<Id> workspaceIds) {
 *     return (List<Project__c>) query('Workspace__c IN :workspaceIds',
 *       new Map<String, Object>{ 'workspaceIds' => workspaceIds });
 *   }
 * }
 * </pre>
 */
public abstract inherited sharing class SelectorBase {
  /**
   * @description Object this selector queries.
   * @return SObject type
   */
  protected abstract Schema.SObjectType getSObjectType();

  /**
   * @description Fields every query returns (Id is always added).
   * @return fields
   */
  protected abstract List<Schema.SObjectField> getFields();

  /**
   * @description ORDER BY clause used by {@link #query(String, Map<String, Object>)}.
   * @return order by expression, or blank for none
   */
  protected virtual String getOrderBy() {
    return 'Id';
  }

  /**
   * @description Access level of every query.
   * @return USER_MODE unless overridden
   */
  protected virtual System.AccessLevel getAccessLevel() {
    return System.AccessLevel.USER_MODE;
  }

  /**
   * @description Records by ID (empty input returns an empty list without a query).
   * @param ids record IDs
   * @return records visible to the user
   */
  public List<SObject> selectSObjectsById(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) {
      return new List<SObject>();
    }
    return query('Id IN :ids', new Map<String, Object>{ 'ids' => ids });
  }

  /**
   * @description Runs a query with bind variables.
   * @param whereClause condition with :bind references, or blank for none
   * @param binds bind variable values by name
   * @return records
   */
  protected List<SObject> query(String whereClause, Map<String, Object> binds) {
    return Database.queryWithBinds(
      buildQuery(whereClause),
      binds == null ? new Map<String, Object>() : binds,
      getAccessLevel()
    );
  }

  /**
   * @description SOQL text for a condition (no values, only bind references).
   * @param whereClause condition, or blank for none
   * @return SOQL
   */
  @TestVisible
  protected String buildQuery(String whereClause) {
    String soql =
      'SELECT ' +
      getFieldListString() +
      ' FROM ' +
      getSObjectType().getDescribe().getName();
    if (String.isNotBlank(whereClause)) {
      soql += ' WHERE ' + whereClause;
    }
    if (String.isNotBlank(getOrderBy())) {
      soql += ' ORDER BY ' + getOrderBy();
    }
    return soql;
  }

  /**
   * @description Comma-separated field list, Id first, without duplicates.
   * @return field list
   */
  public String getFieldListString() {
    List<String> names = new List<String>{ 'Id' };
    Set<String> seen = new Set<String>{ 'id' };
    for (Schema.SObjectField field : getFields()) {
      String name = field.getDescribe().getName();
      if (seen.add(name.toLowerCase())) {
        names.add(name);
      }
    }
    return String.join(names, ', ');
  }
}
