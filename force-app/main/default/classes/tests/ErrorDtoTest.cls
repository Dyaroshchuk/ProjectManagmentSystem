@IsTest
private class ErrorDtoTest {
  // ---- [CODE] message parsing ------------------------------------------------

  @IsTest
  static void parsesCodedMessage() {
    ErrorDto dto = ErrorDto.fromMessage(
      '[OPEN_SUBTASKS] Close all subtasks first.',
      null
    );
    Assert.areEqual(ErrorCodes.OPEN_SUBTASKS, dto.code);
    Assert.areEqual('Close all subtasks first.', dto.message);
  }

  @IsTest
  static void parsesCodedMessageWithWhitespaceAndNewlines() {
    ErrorDto dto = ErrorDto.fromMessage(
      '  [READ_ONLY_CONTAINER]   Project is archived.\nNo edits.  ',
      null
    );
    Assert.areEqual(ErrorCodes.READ_ONLY_CONTAINER, dto.code);
    Assert.areEqual('Project is archived.\nNo edits.', dto.message);
  }

  @IsTest
  static void codeFormatHelperRoundTrips() {
    String raw = ErrorCodes.format(
      ErrorCodes.LAST_OWNER,
      'Add another owner first.'
    );
    Assert.areEqual('[LAST_OWNER] Add another owner first.', raw);
    ErrorDto dto = ErrorDto.fromMessage(raw, null);
    Assert.areEqual(ErrorCodes.LAST_OWNER, dto.code);
    Assert.areEqual('Add another owner first.', dto.message);
  }

  @IsTest
  static void bracketsThatAreNotCodesAreNotParsed() {
    for (
      String raw : new List<String>{
        '[abc] lower case',
        '[A] too short',
        'Text [CONFLICT] not at start',
        '[] empty'
      }
    ) {
      ErrorDto dto = ErrorDto.fromMessage(raw, null);
      Assert.areEqual(
        ErrorCodes.VALIDATION,
        dto.code,
        'must not parse: ' + raw
      );
      Assert.areEqual(raw, dto.message);
    }
  }

  @IsTest
  static void uncodedMessagesAreMappedFromStatusCode() {
    Map<System.StatusCode, String> expected = new Map<System.StatusCode, String>{
      System.StatusCode.INSUFFICIENT_ACCESS_OR_READONLY => ErrorCodes.FORBIDDEN,
      System.StatusCode.INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY => ErrorCodes.FORBIDDEN,
      System.StatusCode.ENTITY_IS_DELETED => ErrorCodes.NOT_FOUND,
      System.StatusCode.UNABLE_TO_LOCK_ROW => ErrorCodes.CONFLICT,
      System.StatusCode.REQUIRED_FIELD_MISSING => ErrorCodes.VALIDATION,
      System.StatusCode.STRING_TOO_LONG => ErrorCodes.VALIDATION
    };
    for (System.StatusCode status : expected.keySet()) {
      Assert.areEqual(
        expected.get(status),
        ErrorDto.fromMessage('Platform message', status).code,
        String.valueOf(status)
      );
    }
  }

  @IsTest
  static void nullMessageIsSafe() {
    ErrorDto dto = ErrorDto.fromMessage(null, null);
    Assert.areEqual(ErrorCodes.VALIDATION, dto.code);
    Assert.areEqual('', dto.message);
  }

  // ---- Real DML errors -------------------------------------------------------

  @IsTest
  static void mapsDmlExceptionFromRealInsert() {
    try {
      insert new Account(); // Name is required
      Assert.fail('expected DmlException');
    } catch (DmlException e) {
      ErrorDto dto = ErrorDto.fromException(e);
      Assert.areEqual(ErrorCodes.VALIDATION, dto.code);
      Assert.areEqual(0, dto.rowIndex);
      Assert.isTrue(dto.fields.contains('Name'), 'fields: ' + dto.fields);
      Assert.isFalse(String.isBlank(dto.message));
    }
  }

  @IsTest
  static void oneErrorPerFailedRow() {
    List<Account> accounts = new List<Account>{
      new Account(Name = 'ok'),
      new Account(),
      new Account()
    };
    try {
      insert accounts;
      Assert.fail('expected DmlException');
    } catch (DmlException e) {
      List<ErrorDto> errors = ErrorDto.fromDmlException(e);
      Assert.areEqual(e.getNumDml(), errors.size());
      Assert.isTrue(errors.size() >= 1);
      for (ErrorDto dto : errors) {
        Assert.areNotEqual(
          0,
          dto.rowIndex,
          'row 0 is valid and must not be reported'
        );
        Assert.areEqual(ErrorCodes.VALIDATION, dto.code);
      }
    }
  }

  @IsTest
  static void mapsDatabaseErrorFromPartialSuccess() {
    List<Database.SaveResult> results = Database.insert(
      new List<Account>{ new Account(Name = 'ok'), new Account() },
      false
    );
    Assert.isTrue(results[0].isSuccess());
    Assert.isFalse(results[1].isSuccess());
    ErrorDto dto = ErrorDto.fromDatabaseError(results[1].getErrors()[0]);
    Assert.areEqual(ErrorCodes.VALIDATION, dto.code);
    Assert.isTrue(dto.fields.contains('Name'), 'fields: ' + dto.fields);
  }

  // ---- PmimpException --------------------------------------------------------

  @IsTest
  static void subclassesHaveDefaultCodes() {
    Assert.areEqual(
      ErrorCodes.VALIDATION,
      new ValidationException('x').getCode()
    );
    Assert.areEqual(
      ErrorCodes.FORBIDDEN,
      new ForbiddenException('x').getCode()
    );
    Assert.areEqual(ErrorCodes.NOT_FOUND, new NotFoundException('x').getCode());
    Assert.areEqual(ErrorCodes.CONFLICT, new ConflictException('x').getCode());
    Assert.areEqual(
      ErrorCodes.INTERNAL_ERROR,
      new PmimpException('x').getCode()
    );
  }

  @IsTest
  static void pmimpExceptionMapsWithAllDetails() {
    Map<String, Object> details = new Map<String, Object>{
      'subtaskCount' => 3
    };
    try {
      throw new ConflictException('Confirm to reopen the parent.')
        .withCode(ErrorCodes.CONFIRMATION_REQUIRED)
        .withField('statusKey')
        .withDetails(details);
    } catch (PmimpException e) {
      ErrorDto dto = ErrorDto.fromException(e);
      Assert.areEqual(ErrorCodes.CONFIRMATION_REQUIRED, dto.code);
      Assert.areEqual('Confirm to reopen the parent.', dto.message);
      Assert.areEqual(new List<String>{ 'statusKey' }, dto.fields);
      Assert.areEqual(details, dto.details);
      Assert.areEqual(Logger.getCorrelationId(), dto.correlationId);
    }
  }

  @IsTest
  static void exceptionWithoutFieldHasNoFields() {
    ErrorDto dto = ErrorDto.fromException(
      new NotFoundException('Project not found.')
    );
    Assert.areEqual(ErrorCodes.NOT_FOUND, dto.code);
    Assert.isNull(dto.fields);
    Assert.isNull(dto.details);
  }

  @IsTest
  static void unexpectedExceptionHidesInternals() {
    ErrorDto dto = ErrorDto.fromException(
      new MathException('Divide by 0 at line 42')
    );
    Assert.areEqual(ErrorCodes.INTERNAL_ERROR, dto.code);
    Assert.areEqual(System.Label.PMIMP_Error_Unexpected, dto.message);
  }

  // ---- LWC payload -----------------------------------------------------------

  @IsTest
  static void auraHandledExceptionCarriesJsonPayload() {
    ErrorDto dto = ErrorDto.fromException(
      new ValidationException('Title is required.').withField('title')
    );
    AuraHandledException ex = dto.toAuraHandledException();
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      ex.getMessage()
    );
    Assert.areEqual(ErrorCodes.VALIDATION, payload.get('code'));
    Assert.areEqual('Title is required.', payload.get('message'));
    Assert.areEqual(new List<Object>{ 'title' }, payload.get('fields'));
    Assert.isFalse(payload.containsKey('recordId'), 'nulls are omitted');
  }

  // ---- ErrorCodes ------------------------------------------------------------

  @IsTest
  static void wellFormedCodes() {
    Assert.isTrue(ErrorCodes.isWellFormed(ErrorCodes.STATUS_IN_USE));
    Assert.isTrue(ErrorCodes.isWellFormed('A1'));
    Assert.isFalse(ErrorCodes.isWellFormed('lower'));
    Assert.isFalse(ErrorCodes.isWellFormed('1ABC'));
    Assert.isFalse(ErrorCodes.isWellFormed(null));
  }
}
