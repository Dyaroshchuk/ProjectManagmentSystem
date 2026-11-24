@IsTest
private class BypassServiceTest {
  private static User createUser(Boolean withBypassPermission) {
    User u;
    // Setup objects: create in runAs to avoid mixed DML with any test data.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
      String unique = String.valueOf(Crypto.getRandomInteger()).remove('-');
      u = new User(
        Username = 'pmimp.bypass.' + unique + '@test.pmimp.example.com',
        Email = 'bypass@test.pmimp.example.com',
        LastName = 'Bypass Test',
        Alias = 'bypass',
        ProfileId = p.Id,
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        LanguageLocaleKey = 'en_US',
        EmailEncodingKey = 'UTF-8'
      );
      insert u;

      if (withBypassPermission) {
        PermissionSet ps = new PermissionSet(
          Name = 'PMIMP_Test_Bypass_' + unique,
          Label = 'PMIMP Test Bypass'
        );
        insert ps;
        CustomPermission cp = [
          SELECT Id
          FROM CustomPermission
          WHERE DeveloperName = :BypassService.BYPASS_PERMISSION
        ];
        insert new SetupEntityAccess(ParentId = ps.Id, SetupEntityId = cp.Id);
        insert new PermissionSetAssignment(
          AssigneeId = u.Id,
          PermissionSetId = ps.Id
        );
      }
    }
    return u;
  }

  private class CountingHandler extends TriggerHandler {
    Integer calls = 0;
    public override String getName() {
      return 'CountingHandler';
    }
    public override void beforeInsert(List<SObject> newRecords) {
      calls++;
    }
  }

  // ---- Programmatic bypass -------------------------------------------------

  @IsTest
  static void nothingIsBypassedByDefault() {
    System.runAs(createUser(false)) {
      Assert.isFalse(BypassService.hasBypassPermission());
      Assert.isFalse(BypassService.isBypassed('AnyHandler'));
    }
  }

  @IsTest
  static void bypassAndClearOneHandler() {
    System.runAs(createUser(false)) {
      BypassService.bypass('HandlerA');
      BypassService.bypass('HandlerB');
      Assert.isTrue(BypassService.isBypassed('HandlerA'));
      Assert.isTrue(BypassService.isBypassed('HandlerB'));
      Assert.isFalse(BypassService.isBypassed('HandlerC'));

      BypassService.clearBypass('HandlerA');
      Assert.isFalse(BypassService.isBypassed('HandlerA'));
      Assert.isTrue(
        BypassService.isBypassed('HandlerB'),
        'clearing A must not clear B'
      );
    }
  }

  @IsTest
  static void clearAllBypasses() {
    System.runAs(createUser(false)) {
      BypassService.bypass('HandlerA');
      BypassService.bypass('HandlerB');
      BypassService.clearAllBypasses();
      Assert.isFalse(BypassService.isBypassed('HandlerA'));
      Assert.isFalse(BypassService.isBypassed('HandlerB'));
    }
  }

  @IsTest
  static void blankHandlerNameIsRejected() {
    for (String blank : new List<String>{ null, '', '   ' }) {
      try {
        BypassService.bypass(blank);
        Assert.fail('expected IllegalArgumentException for "' + blank + '"');
      } catch (IllegalArgumentException e) {
        Assert.areEqual('Handler name is required.', e.getMessage());
      }
    }
  }

  // ---- Custom permission bypass ---------------------------------------------

  @IsTest
  static void bypassPermissionSkipsEveryHandler() {
    User bypassUser = createUser(true);
    CountingHandler h = new CountingHandler();
    System.runAs(bypassUser) {
      Assert.isTrue(BypassService.hasBypassPermission());
      Assert.isTrue(BypassService.isBypassed('CountingHandler'));
      Assert.isTrue(BypassService.isBypassed('AnyOtherHandler'));
      TriggerDispatcher.run(
        h,
        new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
          .withNew(new List<SObject>())
      );
    }
    Assert.areEqual(
      0,
      h.calls,
      'user with the bypass permission must not run handlers'
    );
  }

  @IsTest
  static void userWithoutPermissionRunsHandlers() {
    User normalUser = createUser(false);
    CountingHandler h = new CountingHandler();
    System.runAs(normalUser) {
      TriggerDispatcher.run(
        h,
        new TriggerDispatcher.Context(System.TriggerOperation.BEFORE_INSERT)
          .withNew(new List<SObject>())
      );
    }
    Assert.areEqual(1, h.calls);
  }

  @IsTest
  static void permissionIsEvaluatedPerUser() {
    User bypassUser = createUser(true);
    User normalUser = createUser(false);
    System.runAs(bypassUser) {
      Assert.isTrue(BypassService.hasBypassPermission());
    }
    System.runAs(normalUser) {
      Assert.isFalse(
        BypassService.hasBypassPermission(),
        'cache must not leak between users'
      );
    }
  }
}
