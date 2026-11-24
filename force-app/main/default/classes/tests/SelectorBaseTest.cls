@IsTest
private class SelectorBaseTest {
  private virtual class AccountSelector extends SelectorBase {
    protected override Schema.SObjectType getSObjectType() {
      return Account.SObjectType;
    }
    protected override List<Schema.SObjectField> getFields() {
      return new List<Schema.SObjectField>{
        Account.Name,
        Account.Id,
        Account.Name,
        Account.Description
      };
    }
    List<Account> selectByName(String name) {
      return (List<Account>) query(
        'Name = :name',
        new Map<String, Object>{ 'name' => name }
      );
    }
    List<Account> selectAll() {
      return (List<Account>) query(null, null);
    }
  }

  private class UnorderedAccountSelector extends AccountSelector {
    protected override String getOrderBy() {
      return null;
    }
  }

  private class SystemModeAccountSelector extends AccountSelector {
    protected override System.AccessLevel getAccessLevel() {
      return System.AccessLevel.SYSTEM_MODE;
    }
  }

  @TestSetup
  static void setup() {
    insert new List<Account>{
      new Account(Name = 'Alpha'),
      new Account(Name = 'Beta'),
      new Account(Name = 'Gamma')
    };
  }

  @IsTest
  static void fieldListHasIdFirstWithoutDuplicates() {
    Assert.areEqual(
      'Id, Name, Description',
      new AccountSelector().getFieldListString()
    );
  }

  @IsTest
  static void buildsQueryWithWhereAndOrder() {
    Assert.areEqual(
      'SELECT Id, Name, Description FROM Account WHERE Name = :name ORDER BY Id',
      new AccountSelector().buildQuery('Name = :name')
    );
    Assert.areEqual(
      'SELECT Id, Name, Description FROM Account',
      new UnorderedAccountSelector().buildQuery('')
    );
  }

  @IsTest
  static void selectsByIdWithBinds() {
    Map<Id, Account> all = new Map<Id, Account>([SELECT Id, Name FROM Account]);
    List<Account> found = (List<Account>) new AccountSelector()
      .selectSObjectsById(all.keySet());
    Assert.areEqual(3, found.size());
    Assert.isNotNull(found[0].Name, 'selected fields are populated');
  }

  @IsTest
  static void emptyIdSetRunsNoQuery() {
    Integer queriesBefore = Limits.getQueries();
    Assert.areEqual(
      0,
      new AccountSelector().selectSObjectsById(new Set<Id>()).size()
    );
    Assert.areEqual(0, new AccountSelector().selectSObjectsById(null).size());
    Assert.areEqual(queriesBefore, Limits.getQueries());
  }

  @IsTest
  static void bindValuesAreNotInjectable() {
    Assert.areEqual(1, new AccountSelector().selectByName('Beta').size());
    Assert.areEqual(
      0,
      new AccountSelector().selectByName('Beta\' OR Name != \'').size()
    );
    Assert.areEqual(3, new AccountSelector().selectAll().size());
  }

  @IsTest
  static void userModeIsTheDefault() {
    Profile minimal = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];
    User u = new User(
      Username = 'pmimp.selector.' +
        String.valueOf(Crypto.getRandomInteger()).remove('-') +
        '@test.pmimp.example.com',
      Email = 'selector@test.pmimp.example.com',
      LastName = 'Selector Test',
      Alias = 'seltest',
      ProfileId = minimal.Id,
      TimeZoneSidKey = 'GMT',
      LocaleSidKey = 'en_US',
      LanguageLocaleKey = 'en_US',
      EmailEncodingKey = 'UTF-8'
    );
    insert u;
    System.runAs(u) {
      try {
        new AccountSelector().selectAll();
        Assert.fail(
          'user without Account access must not be able to query in USER_MODE'
        );
      } catch (QueryException e) {
        Assert.isNotNull(e.getMessage());
      }
      Assert.areEqual(
        3,
        new SystemModeAccountSelector().selectAll().size(),
        'SYSTEM_MODE skips CRUD and FLS; sharing follows the calling class'
      );
    }
  }
}
