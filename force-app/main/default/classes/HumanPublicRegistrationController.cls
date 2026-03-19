public without sharing class HumanPublicRegistrationController {
  public class FieldOption {
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String value { get; set; }
  }

  public class FormConfig {
    @AuraEnabled
    public List<FieldOption> prefectureOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> sexOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> occupationOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> experienceOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> kensyuKibouOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> requestActivityOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> schoolOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> activityFormOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> activityWeekTimeOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> areaOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> teachingSexOptions { get; set; }
    @AuraEnabled
    public List<FieldOption> teachingLevelOptions { get; set; }
    @AuraEnabled
    public List<String> sportsActivityValues { get; set; }
  }

  public class RegistrationRequest {
    @AuraEnabled
    public String kanjiSei { get; set; }
    @AuraEnabled
    public String kanjiMei { get; set; }
    @AuraEnabled
    public String kanaSei { get; set; }
    @AuraEnabled
    public String kanaMei { get; set; }
    @AuraEnabled
    public String sex { get; set; }
    @AuraEnabled
    public String birthday { get; set; }
    @AuraEnabled
    public String emailAdress { get; set; }
    @AuraEnabled
    public String emailAdressCheck { get; set; }
    @AuraEnabled
    public String tel { get; set; }
    @AuraEnabled
    public String postalCode { get; set; }
    @AuraEnabled
    public String prefectures { get; set; }
    @AuraEnabled
    public String localAddress { get; set; }
    @AuraEnabled
    public String station1 { get; set; }
    @AuraEnabled
    public String commute1 { get; set; }
    @AuraEnabled
    public String station2 { get; set; }
    @AuraEnabled
    public String commute2 { get; set; }
    @AuraEnabled
    public String station3 { get; set; }
    @AuraEnabled
    public String commute3 { get; set; }
    @AuraEnabled
    public String occupation { get; set; }
    @AuraEnabled
    public String experience { get; set; }
    @AuraEnabled
    public String kensyuKibou { get; set; }
    @AuraEnabled
    public List<String> requestActivity { get; set; }
    @AuraEnabled
    public List<String> school { get; set; }
    @AuraEnabled
    public List<String> activityForm { get; set; }
    @AuraEnabled
    public List<String> activityWeekTime { get; set; }
    @AuraEnabled
    public List<String> area { get; set; }
    @AuraEnabled
    public List<String> teachingSex { get; set; }
    @AuraEnabled
    public List<String> teachingLevel { get; set; }
    @AuraEnabled
    public Boolean teacherLicense { get; set; }
    @AuraEnabled
    public String licenseType { get; set; }
    @AuraEnabled
    public Boolean medicalCare { get; set; }
    @AuraEnabled
    public String medicalCareName { get; set; }
    @AuraEnabled
    public Boolean welfare { get; set; }
    @AuraEnabled
    public String welfareName { get; set; }
    @AuraEnabled
    public Boolean telecommunications { get; set; }
    @AuraEnabled
    public String telecommunicationsName { get; set; }
    @AuraEnabled
    public Boolean sportsCulture { get; set; }
    @AuraEnabled
    public String sportsCultureName { get; set; }
    @AuraEnabled
    public Boolean otherQualification { get; set; }
    @AuraEnabled
    public String nameQualification { get; set; }
    @AuraEnabled
    public String abilityAppeal { get; set; }
    @AuraEnabled
    public Boolean acceptedTerms { get; set; }
  }

  public class SubmissionResponse {
    @AuraEnabled
    public Id recordId { get; set; }
    @AuraEnabled
    public String recordName { get; set; }
    @AuraEnabled
    public String status { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static FormConfig getFormConfig() {
    return HumanPublicRegistrationService.getFormConfig();
  }

  @AuraEnabled
  public static SubmissionResponse submitRegistration(
    RegistrationRequest request
  ) {
    return HumanPublicRegistrationService.submitRegistration(request);
  }
}
