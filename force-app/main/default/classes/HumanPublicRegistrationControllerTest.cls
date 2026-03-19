@IsTest
private class HumanPublicRegistrationControllerTest {
  @IsTest
  static void getFormConfig_returnsExpectedOptions() {
    Test.startTest();
    HumanPublicRegistrationController.FormConfig config = HumanPublicRegistrationController.getFormConfig();
    Test.stopTest();

    System.assertNotEquals(null, config);
    System.assert(
      config.prefectureOptions.size() > 0,
      '都道府県の選択肢が必要です。'
    );
    System.assert(
      config.requestActivityOptions.size() > 0,
      '希望内容の選択肢が必要です。'
    );
    System.assert(
      config.sportsActivityValues.contains('部活動指導(運動系)'),
      '部活動指導(運動系)が必要です。'
    );
  }

  @IsTest
  static void submitRegistration_insertsHumanRecord() {
    HumanPublicRegistrationController.RegistrationRequest request = buildValidRequest();

    Test.startTest();
    HumanPublicRegistrationController.SubmissionResponse response = HumanPublicRegistrationController.submitRegistration(
      request
    );
    Test.stopTest();

    System.assertNotEquals(null, response);
    System.assertNotEquals(null, response.recordId);
    System.assertNotEquals(null, response.recordName);
    System.assertEquals('受付', response.status);

    Human__c createdRecord = [
      SELECT
        RecordTypeId,
        Status__c,
        ApplicationDate__c,
        KanjiSei__c,
        KanjiMei__c,
        KanaSei__c,
        KanaMei__c,
        EmailAdress__c,
        EmailAdressCheck__c,
        Tel__c,
        Birthday__c,
        PostalCode__c,
        Prefectures__c,
        LocalAddress__c,
        Station1__c,
        Commute1__c,
        Occupation__c,
        Experience__c,
        KensyuKibou__c,
        RequestActivity__c,
        School__c,
        ActivityForm__c,
        ActivityWeekTime__c,
        TeacherLicense__c,
        LicenseType__c,
        MedicalCare__c,
        Welfare__c,
        Telecommunications__c,
        SportsCulture__c,
        OtherQualification__c
      FROM Human__c
      WHERE Id = :response.recordId
    ];

    System.assertEquals('受付', createdRecord.Status__c);
    System.assertEquals(Date.today(), createdRecord.ApplicationDate__c);
    System.assertEquals('山田', createdRecord.KanjiSei__c);
    System.assertEquals('花子', createdRecord.KanjiMei__c);
    System.assertEquals('ヤマダ', createdRecord.KanaSei__c);
    System.assertEquals('ハナコ', createdRecord.KanaMei__c);
    System.assertEquals('hanako@example.com', createdRecord.EmailAdress__c);
    System.assertEquals(
      'hanako@example.com',
      createdRecord.EmailAdressCheck__c
    );
    System.assertEquals('09012345678', createdRecord.Tel__c);
    System.assertEquals(
      Date.newInstance(1990, 5, 20),
      createdRecord.Birthday__c
    );
    System.assertEquals('1234567', createdRecord.PostalCode__c);
    System.assertEquals('東京都', createdRecord.Prefectures__c);
    System.assertEquals('新宿区西新宿1-1-1', createdRecord.LocalAddress__c);
    System.assertEquals('新宿駅', createdRecord.Station1__c);
    System.assertEquals('45分', createdRecord.Commute1__c);
    System.assertEquals('会社員', createdRecord.Occupation__c);
    System.assertEquals('活動したことがある', createdRecord.Experience__c);
    System.assertEquals('受講する', createdRecord.KensyuKibou__c);
    System.assertEquals('教科指導;ICTの支援', createdRecord.RequestActivity__c);
    System.assertEquals('小学校;中学校', createdRecord.School__c);
    System.assertEquals(
      '有期労働・パートタイム',
      createdRecord.ActivityForm__c
    );
    System.assertEquals('月曜午前;水曜午後', createdRecord.ActivityWeekTime__c);
    System.assertEquals(false, createdRecord.TeacherLicense__c);
    System.assertEquals(null, createdRecord.LicenseType__c);
    System.assertEquals(false, createdRecord.MedicalCare__c);
    System.assertEquals(false, createdRecord.Welfare__c);
    System.assertEquals(false, createdRecord.Telecommunications__c);
    System.assertEquals(false, createdRecord.SportsCulture__c);
    System.assertEquals(false, createdRecord.OtherQualification__c);
  }

  @IsTest
  static void submitRegistration_requiresConditionalSportsFields() {
    HumanPublicRegistrationController.RegistrationRequest request = buildValidRequest();
    request.requestActivity = new List<String>{ '部活動指導(運動系)' };
    request.teachingSex = new List<String>();
    request.teachingLevel = new List<String>();

    Test.startTest();
    try {
      HumanPublicRegistrationController.submitRegistration(request);
      System.assert(false, '例外が発生する必要があります。');
    } catch (AuraHandledException handledEx) {
      System.assert(
        handledEx.getMessage().contains('指導可能対象（性別）'),
        '部活動向けの条件必須エラーが必要です。'
      );
    }
    Test.stopTest();
  }

  private static HumanPublicRegistrationController.RegistrationRequest buildValidRequest() {
    HumanPublicRegistrationController.RegistrationRequest request = new HumanPublicRegistrationController.RegistrationRequest();
    request.kanjiSei = '山田';
    request.kanjiMei = '花子';
    request.kanaSei = 'ヤマダ';
    request.kanaMei = 'ハナコ';
    request.sex = '女';
    request.birthday = '1990-05-20';
    request.emailAdress = 'hanako@example.com';
    request.emailAdressCheck = 'hanako@example.com';
    request.tel = '090-1234-5678';
    request.postalCode = '123-4567';
    request.prefectures = '東京都';
    request.localAddress = '新宿区西新宿1-1-1';
    request.station1 = '新宿駅';
    request.commute1 = '45分';
    request.occupation = '会社員';
    request.experience = '活動したことがある';
    request.kensyuKibou = '受講する';
    request.requestActivity = new List<String>{ '教科指導', 'ICTの支援' };
    request.school = new List<String>{ '小学校', '中学校' };
    request.activityForm = new List<String>{ '有期労働・パートタイム' };
    request.activityWeekTime = new List<String>{ '月曜午前', '水曜午後' };
    request.area = new List<String>{ '新宿区' };
    request.teachingSex = new List<String>();
    request.teachingLevel = new List<String>();
    request.teacherLicense = false;
    request.medicalCare = false;
    request.welfare = false;
    request.telecommunications = false;
    request.sportsCulture = false;
    request.otherQualification = false;
    request.abilityAppeal = 'ICT支援と学習支援の経験があります。';
    request.acceptedTerms = true;
    return request;
  }
}
