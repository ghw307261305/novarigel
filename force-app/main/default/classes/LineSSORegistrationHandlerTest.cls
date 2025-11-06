@IsTest
private class LineSSORegistrationHandlerTest {
  @IsTest
  static void createUserCreatesCommunityUserWithContact() {
    Account defaultAccount = new Account(Name = '共通購入者');
    insert defaultAccount;

    Auth.UserData data = buildUserData(
      new Map<String, Object>{
        'Identifier' => 'line-identifier-001',
        'Email' => 'line.user001@example.com',
        'FirstName' => 'Hanako',
        'LastName' => 'Suzuki',
        'FullName' => 'Hanako Suzuki',
        'Nickname' => 'hanako',
        'Username' => 'line.user001@example.com',
        'TimeZone' => 'Asia/Tokyo',
        'Locale' => 'ja_JP',
        'Language' => 'ja'
      }
    );

    LineSSORegistrationHandler handler = new LineSSORegistrationHandler();

    Test.startTest();
    User created = handler.createUser(null, data);
    Test.stopTest();

    User userRecord = [
      SELECT
        Id,
        Username,
        Email,
        ProfileId,
        ContactId,
        CommunityNickname,
        FederationIdentifier
      FROM User
      WHERE Id = :created.Id
    ];
    System.assertEquals('line.user001@example.com', userRecord.Username);
    System.assertEquals('line.user001@example.com', userRecord.Email);
    System.assertEquals('line-identifier-001', userRecord.FederationIdentifier);
    System.assertNotEquals(null, userRecord.ContactId);

    Contact relatedContact = [
      SELECT AccountId, FirstName, LastName, Email
      FROM Contact
      WHERE Id = :userRecord.ContactId
    ];
    System.assertEquals(defaultAccount.Id, relatedContact.AccountId);
    System.assertEquals('Hanako', relatedContact.FirstName);
    System.assertEquals('Suzuki', relatedContact.LastName);
    System.assertEquals('line.user001@example.com', relatedContact.Email);
    System.assertEquals('hanako', userRecord.CommunityNickname);
  }

  @IsTest
  static void updateUserRefreshesContactInformation() {
    Account defaultAccount = new Account(Name = '共通購入者');
    insert defaultAccount;

    LineSSORegistrationHandler handler = new LineSSORegistrationHandler();

    Auth.UserData initialData = buildUserData(
      new Map<String, Object>{
        'Identifier' => 'line-identifier-002',
        'Email' => 'line.user002@example.com',
        'FullName' => 'Taro Yamada'
      }
    );

    User created = handler.createUser(null, initialData);

    Auth.UserData updatedData = buildUserData(
      new Map<String, Object>{
        'Identifier' => 'line-identifier-002',
        'Email' => 'line.user002.updated@example.com',
        'FirstName' => 'Taro',
        'LastName' => 'Yamada',
        'Nickname' => 'tyamada'
      }
    );

    Test.startTest();
    handler.updateUser(created.Id, null, updatedData);
    Test.stopTest();

    User updatedUser = [
      SELECT Email, FirstName, LastName, CommunityNickname, ContactId
      FROM User
      WHERE Id = :created.Id
    ];
    System.assertEquals('line.user002.updated@example.com', updatedUser.Email);
    System.assertEquals('Taro', updatedUser.FirstName);
    System.assertEquals('Yamada', updatedUser.LastName);
    System.assertEquals('tyamada', updatedUser.CommunityNickname);

    Contact updatedContact = [
      SELECT Email, FirstName, LastName, AccountId
      FROM Contact
      WHERE Id = :updatedUser.ContactId
    ];
    System.assertEquals(
      'line.user002.updated@example.com',
      updatedContact.Email
    );
    System.assertEquals('Taro', updatedContact.FirstName);
    System.assertEquals('Yamada', updatedContact.LastName);
    System.assertEquals(defaultAccount.Id, updatedContact.AccountId);
  }

  @IsTest
  static void createUserWithoutDefaultAccountThrows() {
    LineSSORegistrationHandler handler = new LineSSORegistrationHandler();
    Auth.UserData data = buildUserData(
      new Map<String, Object>{
        'Identifier' => 'line-identifier-003',
        'Email' => 'line.user003@example.com'
      }
    );

    Test.startTest();
    Boolean thrown = false;
    try {
      handler.createUser(null, data);
    } catch (Exception ex) {
      thrown = true;
    }
    Test.stopTest();
    System.assert(
      thrown,
      'Expected missing default account to raise an exception.'
    );
  }

  private static Auth.UserData buildUserData(Map<String, Object> values) {
    if (values == null) {
      values = new Map<String, Object>();
    }
    if (!values.containsKey('AttributeMap')) {
      values.put('AttributeMap', new Map<String, String>());
    }
    return (Auth.UserData) Test.createStub(
      Auth.UserData.class,
      new AuthUserDataStub(values)
    );
  }

  private class AuthUserDataStub implements System.StubProvider {
    private final Map<String, Object> values;

    AuthUserDataStub(Map<String, Object> values) {
      this.values = values;
    }

    public Object invokeMethod(
      Object state,
      String methodName,
      Type[] paramTypes,
      Object[] paramValues
    ) {
      if (
        methodName != null &&
        methodName.startsWith('get') &&
        (paramTypes == null || paramTypes.isEmpty())
      ) {
        String key = methodName.substring(3);
        if (values.containsKey(key)) {
          return values.get(key);
        }
        if ('AttributeMap'.equals(key)) {
          return new Map<String, String>();
        }
        return null;
      }
      return null;
    }
  }
}
