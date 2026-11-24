/**
 * Guards the data model contract from the HLD/LLD (section 4). Code relies on these
 * properties (key formats, unique keys, sharing reasons, delete behaviour), so a metadata
 * change that breaks one fails here instead of in production.
 */
@IsTest
private class SchemaContractTest {
  private static Schema.DescribeFieldResult describe(
    Schema.SObjectField field
  ) {
    return field.getDescribe();
  }

  private static void assertText(Schema.SObjectField field, Integer length) {
    Schema.DescribeFieldResult d = describe(field);
    Assert.areEqual(Schema.DisplayType.STRING, d.getType(), d.getName());
    Assert.areEqual(length, d.getLength(), d.getName() + ' length');
  }

  private static void assertUniqueKey(
    Schema.SObjectField field,
    Boolean externalId
  ) {
    Schema.DescribeFieldResult d = describe(field);
    Assert.isTrue(d.isUnique(), d.getName() + ' must be unique');
    Assert.areEqual(externalId, d.isExternalId(), d.getName() + ' external ID');
  }

  private static void assertPicklist(
    Schema.SObjectField field,
    List<String> values,
    Boolean restricted
  ) {
    Schema.DescribeFieldResult d = describe(field);
    List<String> actual = new List<String>();
    for (Schema.PicklistEntry e : d.getPicklistValues()) {
      actual.add(e.getValue());
    }
    Assert.areEqual(values, actual, d.getName() + ' values');
    Assert.areEqual(
      restricted,
      d.isRestrictedPicklist(),
      d.getName() + ' restricted'
    );
  }

  private static void assertClearsOnDelete(
    Schema.SObjectField field,
    Schema.SObjectType target
  ) {
    Schema.DescribeFieldResult d = describe(field);
    Assert.areEqual(
      new List<Schema.SObjectType>{ target },
      d.getReferenceTo(),
      d.getName() + ' target'
    );
    Assert.isFalse(
      d.isCascadeDelete(),
      d.getName() + ' must clear the value, not cascade'
    );
    Assert.isTrue(
      d.isNillable(),
      d.getName() + ' required-ness is enforced in Apex'
    );
  }

  private static void assertMasterDetail(
    Schema.SObjectField field,
    Schema.SObjectType master
  ) {
    Schema.DescribeFieldResult d = describe(field);
    Assert.areEqual(
      new List<Schema.SObjectType>{ master },
      d.getReferenceTo(),
      d.getName()
    );
    Assert.isTrue(d.isCascadeDelete(), d.getName() + ' must be master-detail');
  }

  @IsTest
  static void workspace() {
    Assert.areEqual(80, describe(Workspace__c.Name).getLength());
    for (
      Schema.SObjectField f : new List<Schema.SObjectField>{
        Workspace__c.Admins_Group_Id__c,
        Workspace__c.Editors_Group_Id__c,
        Workspace__c.Viewers_Group_Id__c
      }
    ) {
      assertText(f, 18);
    }
    Assert.areEqual(
      Schema.DisplayType.BOOLEAN,
      describe(Workspace__c.Is_Archived__c).getType()
    );
  }

  @IsTest
  static void workspaceMember() {
    Assert.isTrue(
      describe(Workspace_Member__c.Name).isAutoNumber(),
      'MEM-n name'
    );
    assertMasterDetail(
      Workspace_Member__c.Workspace__c,
      Workspace__c.SObjectType
    );
    assertPicklist(
      Workspace_Member__c.Role__c,
      new List<String>{ 'Owner', 'Admin', 'Member', 'Viewer' },
      true
    );
    assertPicklist(
      Workspace_Member__c.Status__c,
      new List<String>{ 'Active', 'Removed' },
      true
    );
    assertUniqueKey(Workspace_Member__c.Unique_Key__c, true);
  }

  @IsTest
  static void project() {
    assertMasterDetail(Project__c.Workspace__c, Workspace__c.SObjectType);
    assertText(Project__c.Key_Prefix__c, 10);
    assertUniqueKey(Project__c.Prefix_Unique_Key__c, true);
    Schema.DescribeFieldResult counter = describe(
      Project__c.Last_Item_Number__c
    );
    Assert.areEqual(18, counter.getPrecision());
    Assert.areEqual(0, counter.getScale());
  }

  @IsTest
  static void workflow() {
    assertMasterDetail(Workflow__c.Project__c, Project__c.SObjectType);
    Assert.areEqual(131072, describe(Workflow__c.Definition__c).getLength());
    assertUniqueKey(Workflow__c.Unique_Key__c, false);
  }

  @IsTest
  static void workItem() {
    assertClearsOnDelete(Work_Item__c.Workspace__c, Workspace__c.SObjectType);
    assertClearsOnDelete(Work_Item__c.Project__c, Project__c.SObjectType);
    assertClearsOnDelete(Work_Item__c.Parent__c, Work_Item__c.SObjectType);
    assertText(Work_Item__c.Status_Key__c, 40);
    assertPicklist(
      Work_Item__c.Status_Category__c,
      new List<String>{ 'NOT_STARTED', 'IN_PROGRESS', 'DONE' },
      true
    );
    assertPicklist(
      Work_Item__c.Priority__c,
      new List<String>{ 'Lowest', 'Low', 'Medium', 'High', 'Highest' },
      true
    );
    assertUniqueKey(Work_Item__c.Unique_Key__c, true);
    Schema.DescribeFieldResult position = describe(Work_Item__c.Position__c);
    Assert.areEqual(18, position.getPrecision());
    Assert.areEqual(6, position.getScale());
    Assert.areEqual(
      Schema.DisplayType.TEXTAREA,
      describe(Work_Item__c.Description__c).getType()
    );
    Assert.isTrue(
      describe(Work_Item__c.Description__c).isHtmlFormatted(),
      'Description is rich text'
    );
  }

  @IsTest
  static void subtaskFormulaFollowsParent() {
    Work_Item__c parent = new Work_Item__c(
      Id = Work_Item__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
          .getKeyPrefix() + '000000000001'
    );
    List<Work_Item__c> items = new List<Work_Item__c>{
      new Work_Item__c(),
      new Work_Item__c(Parent__c = parent.Id)
    };
    Formula.recalculateFormulas(items);
    Assert.isFalse(items[0].Is_Subtask__c);
    Assert.isTrue(items[1].Is_Subtask__c);
  }

  @IsTest
  static void activityLog() {
    Assert.isTrue(describe(Activity_Log__c.Name).isAutoNumber(), 'ACT-n name');
    assertClearsOnDelete(
      Activity_Log__c.Workspace__c,
      Workspace__c.SObjectType
    );
    assertClearsOnDelete(
      Activity_Log__c.Work_Item__c,
      Work_Item__c.SObjectType
    );
    assertUniqueKey(Activity_Log__c.Unique_Key__c, true);
    assertText(Activity_Log__c.Transaction_Id__c, 64);
  }

  @IsTest
  static void log() {
    Assert.isTrue(describe(Log__c.Name).isAutoNumber(), 'LOG-n name');
    assertPicklist(
      Log__c.Type__c,
      new List<String>{ 'Error', 'Warn', 'Info' },
      true
    );
    assertText(Log__c.Error_Code__c, 64);
    assertText(Log__c.Correlation_Id__c, 64);
  }

  @IsTest
  static void sharingReasonsExist() {
    // Compile-time references: this class does not compile if a reason is missing.
    Set<String> reasons = new Set<String>{
      Schema.Workspace__Share.RowCause.Workspace_Access__c,
      Schema.Work_Item__Share.RowCause.Workspace_Access__c,
      Schema.Activity_Log__Share.RowCause.Workspace_Access__c
    };
    Assert.areEqual(new Set<String>{ 'Workspace_Access__c' }, reasons);
  }
}
