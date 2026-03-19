import { LightningElement, api } from "lwc";
import getFormConfig from "@salesforce/apex/HumanPublicRegistrationController.getFormConfig";
import submitRegistration from "@salesforce/apex/HumanPublicRegistrationController.submitRegistration";

const DEFAULT_SPORTS_ACTIVITY_VALUES = [
  "部活動指導(運動系)",
  "部活動指導(文化系)"
];
const CUSTOM_MULTI_SELECT_FIELDS = [
  "requestActivity",
  "school",
  "activityForm",
  "activityWeekTime",
  "teachingSex",
  "teachingLevel"
];
const DEFAULT_FORM_PREFILL = {
  kanjiSei: "山田",
  kanjiMei: "太郎",
  kanaSei: "ヤマダ",
  kanaMei: "タロウ",
  sex: "男",
  birthday: "1990-04-15",
  emailAdress: "sample.worker@example.com",
  emailAdressCheck: "sample.worker@example.com",
  tel: "090-1234-5678",
  postalCode: "1600023",
  prefectures: "東京都",
  localAddress: "新宿区西新宿1-1-1",
  station1: "新宿駅",
  commute1: "15分",
  station2: "",
  commute2: "",
  station3: "",
  commute3: "",
  occupation: "会社員",
  experience: "活動したことがある",
  kensyuKibou: "受講する",
  requestActivity: ["教科指導", "ICTの支援"],
  school: ["小学校", "中学校"],
  activityForm: ["有期労働・パートタイム"],
  activityWeekTime: ["月曜午前", "水曜午後"],
  area: [],
  teachingSex: [],
  teachingLevel: [],
  teacherLicense: false,
  licenseType: "",
  medicalCare: false,
  medicalCareName: "",
  welfare: false,
  welfareName: "",
  telecommunications: false,
  telecommunicationsName: "",
  sportsCulture: false,
  sportsCultureName: "",
  otherQualification: false,
  nameQualification: "",
  abilityAppeal: "学習支援とICT支援の経験があります。",
  acceptedTerms: false
};
const DEFAULT_TERMS_RICH_TEXT = `
  <h3>利用規約</h3>
  <ul>
    <li>本フォームは、求職者登録のお申し込みを受け付けるために使用します。</li>
    <li>ご入力いただいた情報は、登録審査、事務局からの連絡、登録前研修・面談の案内、および関連する運営のために利用します。</li>
    <li>入力内容は、最新かつ正確な情報をご記入ください。虚偽の申告や第三者情報の無断登録は禁止します。</li>
    <li>お申し込み後に登録内容に変更が生じた場合は、速やかに事務局までご連絡ください。</li>
    <li>本フォームの送信をもって、上記内容および必要な範囲での情報管理に同意いただいたものとみなします。</li>
  </ul>
`;
const DEFAULT_COMPLETION_MESSAGE =
  "お申し込みありがとうございました。内容を確認後、事務局より必要に応じてご連絡いたします。";

function createDefaultForm() {
  return {
    ...DEFAULT_FORM_PREFILL,
    requestActivity: [...DEFAULT_FORM_PREFILL.requestActivity],
    school: [...DEFAULT_FORM_PREFILL.school],
    activityForm: [...DEFAULT_FORM_PREFILL.activityForm],
    activityWeekTime: [...DEFAULT_FORM_PREFILL.activityWeekTime],
    area: [...DEFAULT_FORM_PREFILL.area],
    teachingSex: [...DEFAULT_FORM_PREFILL.teachingSex],
    teachingLevel: [...DEFAULT_FORM_PREFILL.teachingLevel]
  };
}

function createEmptyConfig() {
  return {
    prefectureOptions: [],
    sexOptions: [],
    occupationOptions: [],
    experienceOptions: [],
    kensyuKibouOptions: [],
    requestActivityOptions: [],
    schoolOptions: [],
    activityFormOptions: [],
    activityWeekTimeOptions: [],
    areaOptions: [],
    teachingSexOptions: [],
    teachingLevelOptions: [],
    sportsActivityValues: DEFAULT_SPORTS_ACTIVITY_VALUES
  };
}

export default class HumanPublicRegistration extends LightningElement {
  @api pageTitle = "求職者登録のお申し込み";
  @api introText =
    "学校活動人材へのご登録を希望される方向けの公開申込フォームです。必要事項をご入力のうえ、内容確認と利用規約への同意後に送信してください。";
  @api termsRichText = DEFAULT_TERMS_RICH_TEXT;
  @api completionMessage = DEFAULT_COMPLETION_MESSAGE;

  config = createEmptyConfig();
  form = createDefaultForm();
  currentStep = "input";
  isLoading = true;
  isSubmitting = false;
  loadError;
  submissionError;
  completedRecordName;
  completedStatus;
  groupErrors = {};
  hasInitializedConfiguredDefaults = false;
  today = new Date().toISOString().slice(0, 10);

  connectedCallback() {
    this.loadOptions();
  }

  get isInputStep() {
    return this.currentStep === "input";
  }

  get isConfirmStep() {
    return this.currentStep === "confirm";
  }

  get isTermsStep() {
    return this.currentStep === "terms";
  }

  get isCompleteStep() {
    return this.currentStep === "complete";
  }

  get prefectureOptions() {
    return this.config.prefectureOptions || [];
  }

  get sexOptions() {
    return this.config.sexOptions || [];
  }

  get occupationOptions() {
    return this.config.occupationOptions || [];
  }

  get experienceOptions() {
    return this.config.experienceOptions || [];
  }

  get kensyuKibouOptions() {
    return this.config.kensyuKibouOptions || [];
  }

  get requestActivityOptions() {
    return this.config.requestActivityOptions || [];
  }

  get schoolOptions() {
    return this.config.schoolOptions || [];
  }

  get activityFormOptions() {
    return this.config.activityFormOptions || [];
  }

  get activityWeekTimeOptions() {
    return this.config.activityWeekTimeOptions || [];
  }

  get areaOptions() {
    return this.config.areaOptions || [];
  }

  get teachingSexOptions() {
    return this.config.teachingSexOptions || [];
  }

  get teachingLevelOptions() {
    return this.config.teachingLevelOptions || [];
  }

  get requestActivityItems() {
    return this.buildSelectableOptions(
      "requestActivity",
      this.requestActivityOptions
    );
  }

  get schoolItems() {
    return this.buildSelectableOptions("school", this.schoolOptions);
  }

  get activityFormItems() {
    return this.buildSelectableOptions(
      "activityForm",
      this.activityFormOptions
    );
  }

  get activityWeekTimeItems() {
    return this.buildSelectableOptions(
      "activityWeekTime",
      this.activityWeekTimeOptions
    );
  }

  get teachingSexItems() {
    return this.buildSelectableOptions("teachingSex", this.teachingSexOptions);
  }

  get teachingLevelItems() {
    return this.buildSelectableOptions(
      "teachingLevel",
      this.teachingLevelOptions
    );
  }

  get sportsActivityValues() {
    return this.config.sportsActivityValues || DEFAULT_SPORTS_ACTIVITY_VALUES;
  }

  get requiresTeachingSelections() {
    const selectedValues = new Set(this.form.requestActivity || []);
    return this.sportsActivityValues.some((value) => selectedValues.has(value));
  }

  get showTeacherLicenseType() {
    return this.form.teacherLicense;
  }

  get showMedicalCareName() {
    return this.form.medicalCare;
  }

  get showWelfareName() {
    return this.form.welfare;
  }

  get showTelecommunicationsName() {
    return this.form.telecommunications;
  }

  get showSportsCultureName() {
    return this.form.sportsCulture;
  }

  get showOtherQualificationName() {
    return this.form.otherQualification;
  }

  get submitDisabled() {
    return this.isSubmitting || !this.form.acceptedTerms;
  }

  get resolvedTermsRichText() {
    return this.termsRichText || DEFAULT_TERMS_RICH_TEXT;
  }

  get resolvedCompletionMessage() {
    return this.completionMessage || DEFAULT_COMPLETION_MESSAGE;
  }

  get summarySections() {
    const sections = [
      {
        key: "basic",
        title: "基本情報",
        rows: [
          this.buildRow("basic-1", "姓（漢字）", this.form.kanjiSei),
          this.buildRow("basic-2", "名（漢字）", this.form.kanjiMei),
          this.buildRow("basic-3", "姓（カナ）", this.form.kanaSei),
          this.buildRow("basic-4", "名（カナ）", this.form.kanaMei),
          this.buildRow(
            "basic-5",
            "性別",
            this.resolveLabel(this.form.sex, this.sexOptions)
          ),
          this.buildRow(
            "basic-6",
            "生年月日",
            this.formatDate(this.form.birthday)
          )
        ]
      },
      {
        key: "contact",
        title: "連絡先",
        rows: [
          this.buildRow("contact-1", "メールアドレス", this.form.emailAdress),
          this.buildRow("contact-2", "電話番号", this.form.tel),
          this.buildRow("contact-3", "郵便番号", this.form.postalCode),
          this.buildRow(
            "contact-4",
            "都道府県",
            this.resolveLabel(this.form.prefectures, this.prefectureOptions)
          ),
          this.buildRow(
            "contact-5",
            "都道府県以下の住所",
            this.form.localAddress
          ),
          this.buildRow(
            "contact-6",
            "自宅最寄り駅・バス停(1)",
            this.form.station1
          ),
          this.buildRow("contact-7", "所要時間(1)", this.form.commute1),
          this.optionalRow(
            "contact-8",
            "自宅最寄り駅・バス停(2)",
            this.form.station2
          ),
          this.optionalRow("contact-9", "所要時間(2)", this.form.commute2),
          this.optionalRow(
            "contact-10",
            "自宅最寄り駅・バス停(3)",
            this.form.station3
          ),
          this.optionalRow("contact-11", "所要時間(3)", this.form.commute3)
        ]
      },
      {
        key: "activity",
        title: "活動希望",
        rows: [
          this.buildRow(
            "activity-1",
            "現在の職業",
            this.resolveLabel(this.form.occupation, this.occupationOptions)
          ),
          this.buildRow(
            "activity-2",
            "学校活動経験",
            this.resolveLabel(this.form.experience, this.experienceOptions)
          ),
          this.buildRow(
            "activity-3",
            "登録前研修",
            this.resolveLabel(this.form.kensyuKibou, this.kensyuKibouOptions)
          ),
          this.buildRow(
            "activity-4",
            "希望内容",
            this.resolveLabels(
              this.form.requestActivity,
              this.requestActivityOptions
            )
          ),
          this.buildRow(
            "activity-5",
            "希望校種",
            this.resolveLabels(this.form.school, this.schoolOptions)
          ),
          this.buildRow(
            "activity-6",
            "希望活動形態",
            this.resolveLabels(this.form.activityForm, this.activityFormOptions)
          ),
          this.buildRow(
            "activity-7",
            "活動可能な曜日・時間帯",
            this.resolveLabels(
              this.form.activityWeekTime,
              this.activityWeekTimeOptions
            )
          ),
          this.optionalRow(
            "activity-8",
            "希望する地域",
            this.resolveLabels(this.form.area, this.areaOptions)
          ),
          this.optionalRow(
            "activity-9",
            "指導可能対象（性別）",
            this.resolveLabels(this.form.teachingSex, this.teachingSexOptions)
          ),
          this.optionalRow(
            "activity-10",
            "指導可能対象（レベル）",
            this.resolveLabels(
              this.form.teachingLevel,
              this.teachingLevelOptions
            )
          )
        ]
      },
      {
        key: "qualification",
        title: "資格・経験",
        rows: [
          this.buildRow(
            "qualification-1",
            "教員免許状を有する",
            this.formatBoolean(this.form.teacherLicense)
          ),
          this.optionalRow(
            "qualification-2",
            "教員免許状の種類",
            this.form.licenseType
          ),
          this.buildRow(
            "qualification-3",
            "医療・看護の資格を有する",
            this.formatBoolean(this.form.medicalCare)
          ),
          this.optionalRow(
            "qualification-4",
            "医療・看護の資格の名称",
            this.form.medicalCareName
          ),
          this.buildRow(
            "qualification-5",
            "心理・福祉の資格を有する",
            this.formatBoolean(this.form.welfare)
          ),
          this.optionalRow(
            "qualification-6",
            "心理・福祉の資格の名称",
            this.form.welfareName
          ),
          this.buildRow(
            "qualification-7",
            "情報通信の資格を有する",
            this.formatBoolean(this.form.telecommunications)
          ),
          this.optionalRow(
            "qualification-8",
            "情報通信の資格の名称",
            this.form.telecommunicationsName
          ),
          this.buildRow(
            "qualification-9",
            "運動・文化の資格を有する",
            this.formatBoolean(this.form.sportsCulture)
          ),
          this.optionalRow(
            "qualification-10",
            "運動・文化の資格の名称",
            this.form.sportsCultureName
          ),
          this.buildRow(
            "qualification-11",
            "その他の資格を有する",
            this.formatBoolean(this.form.otherQualification)
          ),
          this.optionalRow(
            "qualification-12",
            "資格の名称",
            this.form.nameQualification
          ),
          this.optionalRow(
            "qualification-13",
            "活用したい能力・経験等",
            this.form.abilityAppeal
          )
        ].filter((row) => row)
      }
    ];

    return sections
      .map((section) => ({
        ...section,
        rows: section.rows.filter((row) => row)
      }))
      .filter((section) => section.rows.length > 0);
  }

  async loadOptions() {
    this.isLoading = true;
    this.loadError = undefined;

    try {
      const config = await getFormConfig();
      this.config = { ...createEmptyConfig(), ...config };
      if (!this.hasInitializedConfiguredDefaults) {
        this.form = this.applyConfiguredDefaults(this.form);
        this.hasInitializedConfiguredDefaults = true;
      }
    } catch (error) {
      this.loadError = this.normalizeError(error);
    } finally {
      this.isLoading = false;
    }
  }

  handleFieldChange(event) {
    const fieldName = event.target.dataset.field;
    let value;

    if (event.target.type === "checkbox") {
      value = event.target.checked;
    } else {
      value = event.detail.value;
    }

    if (fieldName === "postalCode" && typeof value === "string") {
      value = value.replace(/\D/g, "").slice(0, 7);
    }

    if (fieldName === "tel" && typeof value === "string") {
      value = value.replace(/[^\d-]/g, "");
    }

    const nextForm = { ...this.form, [fieldName]: value };
    this.applyDerivedState(nextForm, fieldName);
    this.form = nextForm;
    this.submissionError = undefined;
    this.clearFieldError(fieldName);
  }

  handleMultiSelectToggle(event) {
    const fieldName = event.target.dataset.field;
    const optionValue = event.target.dataset.value;
    const currentValues = [...(this.form[fieldName] || [])];
    let nextValues;

    if (event.target.checked) {
      nextValues = currentValues.includes(optionValue)
        ? currentValues
        : [...currentValues, optionValue];
    } else {
      nextValues = currentValues.filter((value) => value !== optionValue);
    }

    const nextForm = { ...this.form, [fieldName]: nextValues };
    this.applyDerivedState(nextForm, fieldName);
    this.form = nextForm;
    this.submissionError = undefined;
    this.clearGroupError(fieldName);

    if (
      fieldName === "requestActivity" &&
      !this.includesSportsActivity(nextForm.requestActivity)
    ) {
      this.clearGroupError("teachingSex");
      this.clearGroupError("teachingLevel");
    }
  }

  handleReload() {
    this.loadOptions();
  }

  handleReview() {
    if (!this.validateInputStep()) {
      return;
    }
    this.currentStep = "confirm";
    this.scrollToTop();
  }

  handleBackToInput() {
    this.currentStep = "input";
    this.scrollToTop();
  }

  handleProceedToTerms() {
    this.currentStep = "terms";
    this.scrollToTop();
  }

  handleBackToConfirm() {
    this.currentStep = "confirm";
    this.scrollToTop();
  }

  async handleSubmit() {
    this.submissionError = undefined;

    if (!this.validateTermsStep()) {
      return;
    }

    this.isSubmitting = true;

    try {
      const response = await submitRegistration({
        request: this.buildRequestPayload()
      });
      this.completedRecordName = response.recordName;
      this.completedStatus = response.status;
      this.currentStep = "complete";
      this.scrollToTop();
    } catch (error) {
      this.submissionError = this.normalizeError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  buildRequestPayload() {
    return {
      ...this.form,
      tel: this.form.tel ? this.form.tel.trim() : "",
      postalCode: this.form.postalCode ? this.form.postalCode.trim() : "",
      birthday: this.form.birthday || null
    };
  }

  applyDerivedState(form, fieldName) {
    if (
      fieldName === "requestActivity" &&
      !this.includesSportsActivity(form.requestActivity)
    ) {
      form.teachingSex = [];
      form.teachingLevel = [];
    }

    if (fieldName === "teacherLicense" && !form.teacherLicense) {
      form.licenseType = "";
    }

    if (fieldName === "medicalCare" && !form.medicalCare) {
      form.medicalCareName = "";
    }

    if (fieldName === "welfare" && !form.welfare) {
      form.welfareName = "";
    }

    if (fieldName === "telecommunications" && !form.telecommunications) {
      form.telecommunicationsName = "";
    }

    if (fieldName === "sportsCulture" && !form.sportsCulture) {
      form.sportsCultureName = "";
    }

    if (fieldName === "otherQualification" && !form.otherQualification) {
      form.nameQualification = "";
    }
  }

  validateInputStep() {
    this.clearStepErrors("input");

    this.validateRequiredSelection("requestActivity", "希望内容");
    this.validateRequiredSelection("school", "希望校種");
    this.validateRequiredSelection("activityForm", "希望活動形態");
    this.validateRequiredSelection(
      "activityWeekTime",
      "活動可能な曜日・時間帯"
    );

    if (
      this.form.emailAdress &&
      this.form.emailAdressCheck &&
      this.form.emailAdress.trim() !== this.form.emailAdressCheck.trim()
    ) {
      this.setFieldError("emailAdressCheck", "メールアドレスが一致しません。");
    }

    if (this.requiresTeachingSelections) {
      if (!this.form.teachingSex.length) {
        this.setFieldError("teachingSex", "少なくとも1つ選択してください。");
      }
      if (!this.form.teachingLevel.length) {
        this.setFieldError("teachingLevel", "少なくとも1つ選択してください。");
      }
    }

    this.validatePairedField(
      "station2",
      "commute2",
      "経路(2)は駅・バス停と所要時間をセットで入力してください。"
    );
    this.validatePairedField(
      "station3",
      "commute3",
      "経路(3)は駅・バス停と所要時間をセットで入力してください。"
    );

    if (this.form.teacherLicense && !this.form.licenseType) {
      this.setFieldError("licenseType", "教員免許状の種類を入力してください。");
    }
    if (this.form.medicalCare && !this.form.medicalCareName) {
      this.setFieldError("medicalCareName", "資格の名称を入力してください。");
    }
    if (this.form.welfare && !this.form.welfareName) {
      this.setFieldError("welfareName", "資格の名称を入力してください。");
    }
    if (this.form.telecommunications && !this.form.telecommunicationsName) {
      this.setFieldError(
        "telecommunicationsName",
        "資格の名称を入力してください。"
      );
    }
    if (this.form.sportsCulture && !this.form.sportsCultureName) {
      this.setFieldError("sportsCultureName", "資格の名称を入力してください。");
    }
    if (this.form.otherQualification && !this.form.nameQualification) {
      this.setFieldError("nameQualification", "資格の名称を入力してください。");
    }

    return this.reportValidityForStep("input") && !this.hasGroupErrors();
  }

  validateTermsStep() {
    const termsCheckbox = this.template.querySelector(
      '[data-field="acceptedTerms"]'
    );
    if (!termsCheckbox) {
      return true;
    }

    termsCheckbox.setCustomValidity(
      this.form.acceptedTerms ? "" : "利用規約への同意が必要です。"
    );
    return termsCheckbox.reportValidity();
  }

  validatePairedField(leftField, rightField, message) {
    const leftValue = this.form[leftField];
    const rightValue = this.form[rightField];
    const hasLeft = !!leftValue;
    const hasRight = !!rightValue;

    if (hasLeft === hasRight) {
      return;
    }

    this.setFieldError(leftField, message);
    this.setFieldError(rightField, message);
  }

  validateRequiredSelection(fieldName, label) {
    const values = this.form[fieldName] || [];
    if (!values.length) {
      this.setGroupError(
        fieldName,
        `${label}を少なくとも1つ選択してください。`
      );
    }
  }

  clearStepErrors(stepName) {
    const fields = this.template.querySelectorAll(`[data-step="${stepName}"]`);
    fields.forEach((field) => field.setCustomValidity(""));
    if (stepName === "input") {
      this.groupErrors = {};
    }
  }

  setFieldError(fieldName, message) {
    if (this.isCustomMultiSelectField(fieldName)) {
      this.setGroupError(fieldName, message);
      return;
    }
    const field = this.template.querySelector(`[data-field="${fieldName}"]`);
    if (field) {
      field.setCustomValidity(message);
    }
  }

  clearFieldError(fieldName) {
    if (this.isCustomMultiSelectField(fieldName)) {
      this.clearGroupError(fieldName);
      return;
    }
    const field = this.template.querySelector(`[data-field="${fieldName}"]`);
    if (field) {
      field.setCustomValidity("");
    }
  }

  reportValidityForStep(stepName) {
    const fields = [
      ...this.template.querySelectorAll(`[data-step="${stepName}"]`)
    ];
    return fields.reduce(
      (isValid, field) => field.reportValidity() && isValid,
      true
    );
  }

  isCustomMultiSelectField(fieldName) {
    return CUSTOM_MULTI_SELECT_FIELDS.includes(fieldName);
  }

  setGroupError(fieldName, message) {
    this.groupErrors = { ...this.groupErrors, [fieldName]: message };
  }

  clearGroupError(fieldName) {
    if (!this.groupErrors[fieldName]) {
      return;
    }

    const nextErrors = { ...this.groupErrors };
    delete nextErrors[fieldName];
    this.groupErrors = nextErrors;
  }

  hasGroupErrors() {
    return Object.keys(this.groupErrors).length > 0;
  }

  includesSportsActivity(values) {
    const selectedValues = new Set(values || []);
    return this.sportsActivityValues.some((value) => selectedValues.has(value));
  }

  buildSelectableOptions(fieldName, options) {
    const selectedValues = new Set(this.form[fieldName] || []);
    return (options || []).map((option) => ({
      key: `${fieldName}-${option.value}`,
      label: option.label,
      value: option.value,
      checked: selectedValues.has(option.value)
    }));
  }

  applyConfiguredDefaults(form) {
    const nextForm = { ...form };

    nextForm.sex = this.ensureSingleSelect(nextForm.sex, this.sexOptions);
    nextForm.prefectures = this.ensureSingleSelect(
      nextForm.prefectures,
      this.prefectureOptions
    );
    nextForm.occupation = this.ensureSingleSelect(
      nextForm.occupation,
      this.occupationOptions
    );
    nextForm.experience = this.ensureSingleSelect(
      nextForm.experience,
      this.experienceOptions
    );
    nextForm.kensyuKibou = this.ensureSingleSelect(
      nextForm.kensyuKibou,
      this.kensyuKibouOptions
    );

    nextForm.requestActivity = this.ensureMultiSelect(
      nextForm.requestActivity,
      this.requestActivityOptions,
      2
    );
    nextForm.school = this.ensureMultiSelect(
      nextForm.school,
      this.schoolOptions,
      2
    );
    nextForm.activityForm = this.ensureMultiSelect(
      nextForm.activityForm,
      this.activityFormOptions,
      1
    );
    nextForm.activityWeekTime = this.ensureMultiSelect(
      nextForm.activityWeekTime,
      this.activityWeekTimeOptions,
      2
    );
    nextForm.area = this.ensureMultiSelect(nextForm.area, this.areaOptions, 0);

    if (!this.includesSportsActivity(nextForm.requestActivity)) {
      nextForm.teachingSex = [];
      nextForm.teachingLevel = [];
    }

    return nextForm;
  }

  ensureSingleSelect(value, options) {
    const availableValues = new Set(
      (options || []).map((option) => option.value)
    );
    if (value && availableValues.has(value)) {
      return value;
    }
    return options && options.length ? options[0].value : "";
  }

  ensureMultiSelect(values, options, fallbackCount) {
    const availableValues = new Set(
      (options || []).map((option) => option.value)
    );
    const normalizedValues = (values || []).filter((value) =>
      availableValues.has(value)
    );

    if (normalizedValues.length) {
      return normalizedValues;
    }

    if (!fallbackCount || !options || !options.length) {
      return [];
    }

    return options.slice(0, fallbackCount).map((option) => option.value);
  }

  buildRow(key, label, value) {
    return {
      key,
      label,
      value: value || "未入力"
    };
  }

  optionalRow(key, label, value) {
    if (!value) {
      return null;
    }
    return {
      key,
      label,
      value
    };
  }

  resolveLabel(value, options) {
    const option = (options || []).find((item) => item.value === value);
    return option ? option.label : value;
  }

  resolveLabels(values, options) {
    if (!values || !values.length) {
      return "";
    }

    return values
      .map((value) => this.resolveLabel(value, options))
      .filter((value) => !!value)
      .join("、");
  }

  formatBoolean(value) {
    return value ? "あり" : "なし";
  }

  formatDate(value) {
    if (!value) {
      return "";
    }

    const [year, month, day] = value.split("-");
    if (!year || !month || !day) {
      return value;
    }
    return `${year}年${Number(month)}月${Number(day)}日`;
  }

  normalizeError(error) {
    if (!error) {
      return "不明なエラーが発生しました。";
    }

    if (Array.isArray(error.body)) {
      return error.body.map((item) => item.message).join(" / ");
    }

    if (error.body && typeof error.body.message === "string") {
      return error.body.message;
    }

    if (typeof error.message === "string") {
      return error.message;
    }

    return "不明なエラーが発生しました。";
  }

  scrollToTop() {
    if (typeof window !== "undefined") {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }
}
