public without sharing class HumanPublicRegistrationService {
  private static final String INDIVIDUAL_RECORD_TYPE = 'RecordType_Person';
  private static final String RECEIVED_STATUS = '受付';
  private static final String KATAKANA_PATTERN = '^[ァ-ンヴー]+$';
  private static final String EMAIL_PATTERN = '^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$';
  private static final String PHONE_PATTERN = '^[0-9]{10,11}$';
  private static final String POSTAL_CODE_PATTERN = '^[0-9]{7}$';
  private static final Set<String> SPORTS_ACTIVITY_VALUES = new Set<String>{
    '部活動指導(運動系)',
    '部活動指導(文化系)'
  };

  public static HumanPublicRegistrationController.FormConfig getFormConfig() {
    HumanPublicRegistrationController.FormConfig config = new HumanPublicRegistrationController.FormConfig();

    config.prefectureOptions = buildOptions(Human__c.Prefectures__c);
    config.sexOptions = buildOptions(Human__c.Sex__c);
    config.occupationOptions = buildOptions(Human__c.Occupation__c);
    config.experienceOptions = buildOptions(Human__c.Experience__c);
    config.kensyuKibouOptions = buildOptions(Human__c.KensyuKibou__c);
    config.requestActivityOptions = buildOptions(Human__c.RequestActivity__c);
    config.schoolOptions = buildOptions(Human__c.School__c);
    config.activityFormOptions = buildOptions(Human__c.ActivityForm__c);
    config.activityWeekTimeOptions = buildOptions(Human__c.ActivityWeekTime__c);
    config.areaOptions = buildOptions(Human__c.Area__c);
    config.teachingSexOptions = buildOptions(Human__c.TeachingSex__c);
    config.teachingLevelOptions = buildOptions(Human__c.TeachingLevel__c);
    config.sportsActivityValues = new List<String>(SPORTS_ACTIVITY_VALUES);

    return config;
  }

  public static HumanPublicRegistrationController.SubmissionResponse submitRegistration(
    HumanPublicRegistrationController.RegistrationRequest request
  ) {
    if (request == null) {
      throwHandled('入力データが不足しています。');
    }

    List<String> errors = new List<String>();
    Human__c record = new Human__c();

    record.RecordTypeId = getIndividualRecordTypeId();
    record.Status__c = RECEIVED_STATUS;
    record.ApplicationDate__c = Date.today();

    if (request.acceptedTerms != true) {
      errors.add('利用規約への同意が必要です。');
    }

    record.KanjiSei__c = normalizeText(
      request.kanjiSei,
      '姓（漢字）',
      30,
      true,
      errors
    );
    record.KanjiMei__c = normalizeText(
      request.kanjiMei,
      '名（漢字）',
      30,
      true,
      errors
    );
    record.KanaSei__c = normalizeKatakana(
      request.kanaSei,
      '姓（カナ）',
      30,
      errors
    );
    record.KanaMei__c = normalizeKatakana(
      request.kanaMei,
      '名（カナ）',
      30,
      errors
    );

    String emailAdress = normalizeEmail(
      request.emailAdress,
      'メールアドレス',
      errors
    );
    String emailAdressCheck = normalizeEmail(
      request.emailAdressCheck,
      'メールアドレス(確認)',
      errors
    );
    if (
      !String.isBlank(emailAdress) &&
      !String.isBlank(emailAdressCheck) &&
      emailAdress != emailAdressCheck
    ) {
      errors.add('メールアドレスと確認用メールアドレスが一致しません。');
    }
    record.EmailAdress__c = emailAdress;
    record.EmailAdressCheck__c = emailAdressCheck;

    String phoneDigits = digitsOnly(request.tel);
    if (String.isBlank(phoneDigits)) {
      errors.add('電話番号を入力してください。');
    } else if (!Pattern.matches(PHONE_PATTERN, phoneDigits)) {
      errors.add('電話番号は10桁または11桁の数字で入力してください。');
    }
    record.Tel__c = phoneDigits;

    Date birthday = parseDate(request.birthday, '生年月日', true, errors);
    if (birthday != null && birthday > Date.today()) {
      errors.add('生年月日は本日以前の日付を入力してください。');
    }
    record.Birthday__c = birthday;

    String postalCode = digitsOnly(request.postalCode);
    if (String.isBlank(postalCode)) {
      errors.add('郵便番号を入力してください。');
    } else if (!Pattern.matches(POSTAL_CODE_PATTERN, postalCode)) {
      errors.add('郵便番号は7桁の数字で入力してください。');
    }
    record.PostalCode__c = postalCode;
    record.Prefectures__c = validatePicklist(
      request.prefectures,
      Human__c.Prefectures__c,
      '都道府県',
      true,
      errors
    );
    record.LocalAddress__c = normalizeText(
      request.localAddress,
      '都道府県以下の住所',
      80,
      true,
      errors
    );
    record.Station1__c = normalizeText(
      request.station1,
      '自宅最寄り駅・バス停(1)',
      50,
      true,
      errors
    );
    record.Commute1__c = normalizeText(
      request.commute1,
      '所要時間(1)',
      20,
      true,
      errors
    );

    record.Station2__c = normalizeText(
      request.station2,
      '自宅最寄り駅・バス停(2)',
      50,
      false,
      errors
    );
    record.Commute2__c = normalizeText(
      request.commute2,
      '所要時間(2)',
      20,
      false,
      errors
    );
    validatePair(record.Station2__c, record.Commute2__c, '経路(2)', errors);

    record.Station3__c = normalizeText(
      request.station3,
      '自宅最寄り駅・バス停(3)',
      50,
      false,
      errors
    );
    record.Commute3__c = normalizeText(
      request.commute3,
      '所要時間(3)',
      20,
      false,
      errors
    );
    validatePair(record.Station3__c, record.Commute3__c, '経路(3)', errors);

    record.Sex__c = validatePicklist(
      request.sex,
      Human__c.Sex__c,
      '性別',
      true,
      errors
    );
    record.Occupation__c = validatePicklist(
      request.occupation,
      Human__c.Occupation__c,
      '現在の職業',
      true,
      errors
    );
    record.Experience__c = validatePicklist(
      request.experience,
      Human__c.Experience__c,
      '学校活動経験',
      true,
      errors
    );
    record.KensyuKibou__c = validatePicklist(
      request.kensyuKibou,
      Human__c.KensyuKibou__c,
      '登録前研修',
      true,
      errors
    );

    List<String> requestActivities = validateMultiSelect(
      request.requestActivity,
      Human__c.RequestActivity__c,
      '希望内容',
      true,
      errors
    );
    List<String> schoolValues = validateMultiSelect(
      request.school,
      Human__c.School__c,
      '希望校種',
      true,
      errors
    );
    List<String> activityFormValues = validateMultiSelect(
      request.activityForm,
      Human__c.ActivityForm__c,
      '希望活動形態',
      true,
      errors
    );
    List<String> activityWeekTimeValues = validateMultiSelect(
      request.activityWeekTime,
      Human__c.ActivityWeekTime__c,
      '活動可能な曜日・時間帯',
      true,
      errors
    );
    List<String> areaValues = validateMultiSelect(
      request.area,
      Human__c.Area__c,
      '希望する地域',
      false,
      errors
    );

    Boolean requiresTeachingSelections = containsSportsActivity(
      requestActivities
    );
    List<String> teachingSexValues = validateMultiSelect(
      request.teachingSex,
      Human__c.TeachingSex__c,
      '指導可能対象（性別）',
      requiresTeachingSelections,
      errors
    );
    List<String> teachingLevelValues = validateMultiSelect(
      request.teachingLevel,
      Human__c.TeachingLevel__c,
      '指導可能対象（レベル）',
      requiresTeachingSelections,
      errors
    );
    if (
      !requiresTeachingSelections &&
      (!teachingSexValues.isEmpty() || !teachingLevelValues.isEmpty())
    ) {
      errors.add(
        '部活動指導を選択していない場合、指導可能対象（性別）と指導可能対象（レベル）は入力できません。'
      );
    }

    record.RequestActivity__c = joinMultiSelect(requestActivities);
    record.School__c = joinMultiSelect(schoolValues);
    record.ActivityForm__c = joinMultiSelect(activityFormValues);
    record.ActivityWeekTime__c = joinMultiSelect(activityWeekTimeValues);
    record.Area__c = joinMultiSelect(areaValues);
    record.TeachingSex__c = joinMultiSelect(teachingSexValues);
    record.TeachingLevel__c = joinMultiSelect(teachingLevelValues);

    record.TeacherLicense__c = request.teacherLicense == true;
    record.LicenseType__c = validateDependentText(
      request.licenseType,
      '教員免許状の種類',
      50,
      record.TeacherLicense__c,
      '教員免許状を有する',
      errors
    );

    record.MedicalCare__c = request.medicalCare == true;
    record.MedicalCareName__c = validateDependentText(
      request.medicalCareName,
      '医療・看護の資格の名称',
      50,
      record.MedicalCare__c,
      '医療・看護の資格を有する',
      errors
    );

    record.Welfare__c = request.welfare == true;
    record.WelfareName__c = validateDependentText(
      request.welfareName,
      '心理・福祉の資格の名称',
      50,
      record.Welfare__c,
      '心理・福祉の資格を有する',
      errors
    );

    record.Telecommunications__c = request.telecommunications == true;
    record.TelecommunicationsName__c = validateDependentText(
      request.telecommunicationsName,
      '情報通信の資格の名称',
      50,
      record.Telecommunications__c,
      '情報通信の資格を有する',
      errors
    );

    record.SportsCulture__c = request.sportsCulture == true;
    record.SportsCultureName__c = validateDependentText(
      request.sportsCultureName,
      '運動・文化の資格の名称',
      50,
      record.SportsCulture__c,
      '運動・文化の資格を有する',
      errors
    );

    record.OtherQualification__c = request.otherQualification == true;
    record.NameQualification__c = validateDependentText(
      request.nameQualification,
      '資格の名称',
      50,
      record.OtherQualification__c,
      'その他の資格を有する',
      errors
    );

    record.AbilityAppeal__c = normalizeText(
      request.abilityAppeal,
      '活用したい能力・経験等',
      600,
      false,
      errors
    );

    if (!errors.isEmpty()) {
      throwHandled(String.join(errors, '\n'));
    }

    try {
      insert record;
      Human__c insertedRecord = [
        SELECT Id, Name, Status__c
        FROM Human__c
        WHERE Id = :record.Id
        LIMIT 1
      ];

      HumanPublicRegistrationController.SubmissionResponse response = new HumanPublicRegistrationController.SubmissionResponse();
      response.recordId = insertedRecord.Id;
      response.recordName = insertedRecord.Name;
      response.status = insertedRecord.Status__c;
      return response;
    } catch (DmlException dmlEx) {
      throwHandled(buildDmlErrorMessage(dmlEx));
      return null;
    }
  }

  private static List<HumanPublicRegistrationController.FieldOption> buildOptions(
    Schema.SObjectField field
  ) {
    List<HumanPublicRegistrationController.FieldOption> options = new List<HumanPublicRegistrationController.FieldOption>();
    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
      if (!entry.isActive()) {
        continue;
      }

      HumanPublicRegistrationController.FieldOption option = new HumanPublicRegistrationController.FieldOption();
      option.label = entry.getLabel();
      option.value = entry.getValue();
      options.add(option);
    }
    return options;
  }

  private static String normalizeText(
    String value,
    String label,
    Integer maxLength,
    Boolean required,
    List<String> errors
  ) {
    String normalizedValue = normalizeWhitespace(value);
    if (String.isBlank(normalizedValue)) {
      if (required) {
        errors.add(label + 'を入力してください。');
      }
      return null;
    }

    if (normalizedValue.length() > maxLength) {
      errors.add(label + 'は' + maxLength + '文字以内で入力してください。');
    }
    return normalizedValue;
  }

  private static String normalizeKatakana(
    String value,
    String label,
    Integer maxLength,
    List<String> errors
  ) {
    String normalizedValue = normalizeText(
      value,
      label,
      maxLength,
      true,
      errors
    );
    if (
      !String.isBlank(normalizedValue) &&
      !Pattern.matches(KATAKANA_PATTERN, normalizedValue)
    ) {
      errors.add(label + 'は全角カタカナで入力してください。');
    }
    return normalizedValue;
  }

  private static String normalizeEmail(
    String value,
    String label,
    List<String> errors
  ) {
    String normalizedValue = normalizeText(value, label, 255, true, errors);
    if (
      !String.isBlank(normalizedValue) &&
      !Pattern.matches(EMAIL_PATTERN, normalizedValue)
    ) {
      errors.add(label + 'の形式が正しくありません。');
    }
    return normalizedValue;
  }

  private static Date parseDate(
    String value,
    String label,
    Boolean required,
    List<String> errors
  ) {
    String normalizedValue = normalizeWhitespace(value);
    if (String.isBlank(normalizedValue)) {
      if (required) {
        errors.add(label + 'を入力してください。');
      }
      return null;
    }

    try {
      return Date.valueOf(normalizedValue);
    } catch (Exception parseEx) {
      errors.add(label + 'の形式が正しくありません。');
      return null;
    }
  }

  private static String validatePicklist(
    String value,
    Schema.SObjectField field,
    String label,
    Boolean required,
    List<String> errors
  ) {
    String normalizedValue = normalizeWhitespace(value);
    if (String.isBlank(normalizedValue)) {
      if (required) {
        errors.add(label + 'を選択してください。');
      }
      return null;
    }

    if (!allowedValues(field).contains(normalizedValue)) {
      errors.add(label + 'に不正な値が指定されています。');
    }
    return normalizedValue;
  }

  private static List<String> validateMultiSelect(
    List<String> values,
    Schema.SObjectField field,
    String label,
    Boolean required,
    List<String> errors
  ) {
    List<String> normalizedValues = new List<String>();
    Set<String> seenValues = new Set<String>();
    Set<String> allowedValueSet = allowedValues(field);

    if (values != null) {
      for (String value : values) {
        String normalizedValue = normalizeWhitespace(value);
        if (
          String.isBlank(normalizedValue) ||
          seenValues.contains(normalizedValue)
        ) {
          continue;
        }
        seenValues.add(normalizedValue);
        normalizedValues.add(normalizedValue);
        if (!allowedValueSet.contains(normalizedValue)) {
          errors.add(label + 'に不正な値が指定されています。');
        }
      }
    }

    if (required && normalizedValues.isEmpty()) {
      errors.add(label + 'を選択してください。');
    }

    return normalizedValues;
  }

  private static String validateDependentText(
    String value,
    String label,
    Integer maxLength,
    Boolean enabled,
    String controllerLabel,
    List<String> errors
  ) {
    String normalizedValue = normalizeText(
      value,
      label,
      maxLength,
      false,
      errors
    );
    if (enabled) {
      if (String.isBlank(normalizedValue)) {
        errors.add(label + 'を入力してください。');
      }
      return normalizedValue;
    }

    if (!String.isBlank(normalizedValue)) {
      errors.add(
        controllerLabel + 'を選択した場合のみ、' + label + 'を入力できます。'
      );
    }
    return null;
  }

  private static void validatePair(
    String leftValue,
    String rightValue,
    String label,
    List<String> errors
  ) {
    if (String.isBlank(leftValue) == String.isBlank(rightValue)) {
      return;
    }
    errors.add(label + 'は駅・バス停と所要時間をセットで入力してください。');
  }

  private static String joinMultiSelect(List<String> values) {
    return values == null || values.isEmpty() ? null : String.join(values, ';');
  }

  private static String digitsOnly(String value) {
    return String.isBlank(value) ? null : value.replaceAll('[^0-9]', '');
  }

  private static String normalizeWhitespace(String value) {
    return value == null ? null : value.trim();
  }

  private static Boolean containsSportsActivity(List<String> activities) {
    if (activities == null || activities.isEmpty()) {
      return false;
    }
    for (String activity : activities) {
      if (SPORTS_ACTIVITY_VALUES.contains(activity)) {
        return true;
      }
    }
    return false;
  }

  private static Set<String> allowedValues(Schema.SObjectField field) {
    Set<String> values = new Set<String>();
    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
      if (entry.isActive()) {
        values.add(entry.getValue());
      }
    }
    return values;
  }

  private static Id getIndividualRecordTypeId() {
    Schema.RecordTypeInfo recordTypeInfo = Human__c.SObjectType.getDescribe()
      .getRecordTypeInfosByDeveloperName()
      .get(INDIVIDUAL_RECORD_TYPE);
    if (recordTypeInfo == null) {
      throwHandled('Human__c の個人レコードタイプが見つかりません。');
    }
    return recordTypeInfo.getRecordTypeId();
  }

  private static String buildDmlErrorMessage(DmlException dmlEx) {
    List<String> messages = new List<String>();
    for (Integer index = 0; index < dmlEx.getNumDml(); index++) {
      messages.add(dmlEx.getDmlMessage(index));
    }
    return messages.isEmpty()
      ? '登録処理に失敗しました。'
      : String.join(messages, '\n');
  }

  private static void throwHandled(String message) {
    AuraHandledException handledEx = new AuraHandledException(message);
    handledEx.setMessage(message);
    throw handledEx;
  }
}
