/**
 * Registration handler used for LINE based single sign-on.
 *
 * The handler provisions Community Plus users against the default account named '共通購入者'.
 */
global with sharing class LineSSORegistrationHandler implements Auth.RegistrationHandler {
  private class RegistrationException extends Exception {}
  private static final String DEFAULT_ACCOUNT_NAME = '共通購入者';
  private static final String DEFAULT_ALIAS = 'lineuser';
  private static final String DEFAULT_TIME_ZONE = 'Asia/Tokyo';
  private static final String DEFAULT_LOCALE = 'ja_JP';
  private static final String DEFAULT_LANGUAGE = 'ja';
  private static final Integer MAX_COMMUNITY_NICKNAME_LENGTH = 40;

  global User createUser(Id portalId, Auth.UserData data) {
    validateUserData(data);

    User existing = findExistingUser(data);
    if (existing != null) {
      updateUser(existing.Id, portalId, data);
      return [
        SELECT
          Id,
          Username,
          Email,
          ContactId,
          ProfileId,
          CommunityNickname,
          FederationIdentifier
        FROM User
        WHERE Id = :existing.Id
      ];
    }

    Account defaultAccount = getDefaultAccount();
    Contact contact = ensureContact(defaultAccount.Id, data);

    User newUser = buildUserSkeleton(portalId, data, contact);
    insert newUser;

    return [
      SELECT
        Id,
        Username,
        Email,
        ContactId,
        ProfileId,
        CommunityNickname,
        FederationIdentifier
      FROM User
      WHERE Id = :newUser.Id
    ];
  }

  global void updateUser(Id userId, Id portalId, Auth.UserData data) {
    validateUserData(data);

    User userToUpdate = [
      SELECT
        Id,
        Email,
        FirstName,
        LastName,
        CommunityNickname,
        FederationIdentifier,
        ContactId
      FROM User
      WHERE Id = :userId
    ];

    String email = getEmail(data);
    String firstName = resolveFirstName(data, userToUpdate.FirstName);
    String lastName = resolveLastName(data, userToUpdate.LastName);
    String nickname = generateCommunityNickname(
      data,
      firstName,
      lastName,
      userToUpdate.CommunityNickname
    );

    userToUpdate.Email = email;
    userToUpdate.FirstName = firstName;
    userToUpdate.LastName = lastName;
    userToUpdate.CommunityNickname = nickname;
    userToUpdate.FederationIdentifier = getIdentifier(data);

    update userToUpdate;

    if (userToUpdate.ContactId != null) {
      Contact contactToUpdate = [
        SELECT Id, FirstName, LastName, Email
        FROM Contact
        WHERE Id = :userToUpdate.ContactId
      ];
      Boolean requiresUpdate = false;

      if (contactToUpdate.Email != email) {
        contactToUpdate.Email = email;
        requiresUpdate = true;
      }

      if (contactToUpdate.FirstName != firstName) {
        contactToUpdate.FirstName = firstName;
        requiresUpdate = true;
      }

      if (contactToUpdate.LastName != lastName) {
        contactToUpdate.LastName = lastName;
        requiresUpdate = true;
      }

      if (requiresUpdate) {
        update contactToUpdate;
      }
    }
  }

  private static void validateUserData(Auth.UserData data) {
    if (data == null) {
      throw new RegistrationException('Auth.UserData must not be null.');
    }

    if (String.isBlank(getEmail(data))) {
      throw new RegistrationException('Email address is required for registration.');
    }
  }

  private static User findExistingUser(Auth.UserData data) {
    String identifier = getIdentifier(data);
    if (String.isNotBlank(identifier)) {
      List<User> users = [
        SELECT Id
        FROM User
        WHERE FederationIdentifier = :identifier
        LIMIT 1
      ];
      if (!users.isEmpty()) {
        return users[0];
      }
    }

    String email = getEmail(data);
    if (String.isNotBlank(email)) {
      List<User> users = [SELECT Id FROM User WHERE Username = :email LIMIT 1];
      if (!users.isEmpty()) {
        return users[0];
      }
    }

    return null;
  }

  private static Account getDefaultAccount() {
    List<Account> accounts = [
      SELECT Id
      FROM Account
      WHERE Name = :DEFAULT_ACCOUNT_NAME
      LIMIT 1
    ];
    if (accounts.isEmpty()) {
      throw new RegistrationException(
        'Default account "' + DEFAULT_ACCOUNT_NAME + '" not found.'
      );
    }
    return accounts[0];
  }

  private static Contact ensureContact(Id accountId, Auth.UserData data) {
    String email = getEmail(data);
    Contact contact;

    if (String.isNotBlank(email)) {
      List<Contact> contacts = [
        SELECT Id, AccountId, FirstName, LastName, Email
        FROM Contact
        WHERE Email = :email
        LIMIT 1
      ];
      if (!contacts.isEmpty()) {
        contact = contacts[0];
      }
    }

    if (contact == null) {
      contact = new Contact();
      contact.AccountId = accountId;
      contact.FirstName = resolveFirstName(data, null);
      contact.LastName = resolveLastName(data, null);
      contact.Email = email;
      insert contact;
    } else {
      Boolean requiresUpdate = false;
      String desiredFirstName = resolveFirstName(data, contact.FirstName);
      String desiredLastName = resolveLastName(data, contact.LastName);

      if (contact.AccountId != accountId) {
        contact.AccountId = accountId;
        requiresUpdate = true;
      }

      if (contact.FirstName != desiredFirstName) {
        contact.FirstName = desiredFirstName;
        requiresUpdate = true;
      }

      if (contact.LastName != desiredLastName) {
        contact.LastName = desiredLastName;
        requiresUpdate = true;
      }

      if (contact.Email != email) {
        contact.Email = email;
        requiresUpdate = true;
      }

      if (requiresUpdate) {
        update contact;
      }
    }

    return contact;
  }

  private static User buildUserSkeleton(
    Id portalId,
    Auth.UserData data,
    Contact contact
  ) {
    User newUser = new User();
    newUser.Username = generateUsername(data);
    newUser.Email = getEmail(data);
    newUser.FirstName = resolveFirstName(data, contact.FirstName);
    newUser.LastName = contact.LastName;
    newUser.Alias = generateAlias(newUser.FirstName, newUser.LastName);
    newUser.CommunityNickname = generateCommunityNickname(
      data,
      newUser.FirstName,
      newUser.LastName,
      null
    );
    newUser.TimeZoneSidKey = resolveTimeZone(data);
    newUser.LocaleSidKey = resolveLocaleSid(data);
    newUser.EmailEncodingKey = 'UTF-8';
    newUser.LanguageLocaleKey = resolveLanguage(data);
    newUser.ProfileId = resolveProfileId(portalId);
    newUser.ContactId = contact.Id;
    newUser.IsActive = true;
    newUser.FederationIdentifier = getIdentifier(data);
    return newUser;
  }

  private static String generateUsername(Auth.UserData data) {
    String username = getUsername(data);
    if (String.isBlank(username)) {
      username = getEmail(data);
    }
    if (String.isBlank(username)) {
      String identifier = getIdentifier(data);
      if (String.isBlank(identifier)) {
        identifier = String.valueOf(DateTime.now().getTime());
      }
      username = identifier + '@line.sso';
    }
    if (!username.contains('@')) {
      username += '@line.sso';
    }
    return username;
  }

  private static String generateAlias(String firstName, String lastName) {
    String base = '';
    if (String.isNotBlank(firstName)) {
      base += firstName;
    }
    if (String.isNotBlank(lastName)) {
      base += lastName.substring(0, Math.min(1, lastName.length()));
    }
    if (String.isBlank(base)) {
      base = DEFAULT_ALIAS;
    }
    base = base.replaceAll('[^a-zA-Z0-9]', '');
    if (base.length() > 8) {
      base = base.substring(0, 8);
    }
    while (base.length() < 2) {
      base += 'x';
    }
    return base.toLowerCase();
  }

  private static String generateCommunityNickname(
    Auth.UserData data,
    String firstName,
    String lastName,
    String fallback
  ) {
    String nickname = fallback;
    if (String.isBlank(nickname)) {
      List<String> parts = new List<String>();
      if (String.isNotBlank(firstName)) {
        parts.add(firstName);
      }
      if (String.isNotBlank(lastName)) {
        parts.add(lastName);
      }
      if (!parts.isEmpty()) {
        nickname = String.join(parts, ' ');
      }
    }
    if (String.isBlank(nickname)) {
      nickname = getIdentifier(data);
    }
    if (String.isBlank(nickname)) {
      nickname = DEFAULT_ALIAS;
    }
    nickname = nickname.trim();
    nickname = nickname.length() > MAX_COMMUNITY_NICKNAME_LENGTH
      ? nickname.substring(0, MAX_COMMUNITY_NICKNAME_LENGTH)
      : nickname;
    return nickname;
  }

  private static String resolveFirstName(Auth.UserData data, String fallback) {
    String firstName = getFirstName(data);
    if (String.isBlank(firstName)) {
      firstName = fallback;
    }
    if (String.isBlank(firstName)) {
      String fullName = getFullName(data);
      if (String.isNotBlank(fullName) && fullName.contains(' ')) {
        firstName = fullName.trim().split('\\s+')[0];
      }
    }
    if (String.isBlank(firstName)) {
      firstName = 'Line';
    }
    return firstName;
  }

  private static String resolveLastName(Auth.UserData data, String fallback) {
    String lastName = getLastName(data);
    if (String.isBlank(lastName)) {
      lastName = fallback;
    }
    if (String.isBlank(lastName)) {
      String fullName = getFullName(data);
      if (String.isNotBlank(fullName)) {
        List<String> parts = fullName.trim().split('\\s+');
        lastName = parts.size() > 1 ? parts[parts.size() - 1] : parts[0];
      }
    }
    if (String.isBlank(lastName)) {
      lastName = 'User';
    }
    return lastName;
  }

  private static String resolveTimeZone(Auth.UserData data) {
    // String timeZone = getTimeZone(data);
    return DEFAULT_TIME_ZONE;
  }

  private static String resolveLocaleSid(Auth.UserData data) {
    String locale = getLocale(data);
    if (String.isNotBlank(locale)) {
      return locale;
    }
    return DEFAULT_LOCALE;
  }

  private static String resolveLanguage(Auth.UserData data) {
    String language = getLanguage(data);
    if (String.isNotBlank(language)) {
      return language;
    }
    return DEFAULT_LANGUAGE;
  }

  private static Id resolveProfileId(Id portalId) {
    Id profileId = null;
    try {
      Profile profile = [
        SELECT Id
        FROM Profile
        WHERE UserLicense.Name = '購入者'
        LIMIT 1
      ];
      profileId = profile.Id;
    } catch (Exception ex) {
      profileId = UserInfo.getProfileId();
    }

    return profileId;
  }

  private static String getEmail(Auth.UserData data) {
    if (data == null) {
      return null;
    }
    String value = data.email;
    return !String.isBlank(value) ? value : getAttributeValue(data, 'Email');
  }

  private static String getFirstName(Auth.UserData data) {
    if (data == null) {
      return null;
    }
    String value = data.firstName;
    return !String.isBlank(value) ? value : getAttributeValue(data, 'FirstName');
  }

  private static String getLastName(Auth.UserData data) {
    if (data == null) {
      return null;
    }
    String value = data.lastName;
    return !String.isBlank(value) ? value : getAttributeValue(data, 'LastName');
  }

  private static String getFullName(Auth.UserData data) {
    if (data == null) {
      return null;
    }
    String value = data.fullName;
    return !String.isBlank(value) ? value : getAttributeValue(data, 'FullName');
  }

  private static String getUsername(Auth.UserData data) {
    if (data == null) {
      return null;
    }
    String value = data.username;
    return !String.isBlank(value) ? value : getAttributeValue(data, 'Username');
  }

  private static String getIdentifier(Auth.UserData data) {
    if (data == null) {
      return null;
    }
    String value = data.identifier;
    return !String.isBlank(value) ? value : getAttributeValue(data, 'Identifier');
  }

  private static String getLocale(Auth.UserData data) {
    String locale = getAttributeValue(data, 'Locale');
    if (String.isBlank(locale)) {
      locale = getAttributeValue(data, 'LocaleSidKey');
    }
    return locale;
  }

  private static String getLanguage(Auth.UserData data) {
    String language = getAttributeValue(data, 'Language');
    if (String.isBlank(language)) {
      language = getAttributeValue(data, 'LanguageLocaleKey');
    }
    return language;
  }

  private static String getAttributeValue(Auth.UserData data, String key) {
    if (data == null || String.isBlank(key)) {
      return null;
    }

    Map<String, String> attributes = data.attributeMap;
    if (attributes != null && attributes.containsKey(key)) {
      return attributes.get(key);
    }
    return null;
  }
}
