public with sharing class ReturnReasonEvaluationService {
  public enum ReturnReasonCategory {
    DEFECTIVE,
    SIZE_FIT,
    APPEARANCE,
    UNWANTED,
    OTHER
  }

  private static final Set<ReturnReasonCategory> ALL_REASON_CATEGORIES = new Set<ReturnReasonCategory>(
    ReturnReasonCategory.values()
  );
  private static final Map<ReturnReasonCategory, String> CATEGORY_LABELS = buildReasonCategoryLabels();
  private static final Map<String, ReturnReasonCategory> LABEL_TO_CATEGORY = buildLabelToReasonCategoryMap();
  private static final Map<String, Set<ReturnReasonCategory>> POLICY_REASON_MAP = buildPolicyReasonMap();

  public class ReasonEvaluationInput {
    @InvocableVariable(required=true)
    public String returnReason;

    @InvocableVariable
    public Id policyId;

    @InvocableVariable
    public Id policyProductId;

    @InvocableVariable
    public String policyName;

    @InvocableVariable
    public String policyType;

    @InvocableVariable
    public String policyDescription;

    @InvocableVariable
    public Id productId;

    @InvocableVariable
    public String productName;

    @InvocableVariable
    public String productCode;

    @InvocableVariable
    public String productFamily;

    @InvocableVariable
    public String productDescription;

    @InvocableVariable
    public Decimal productUnitPrice;
  }

  @InvocableMethod(label='返品理由の判定', description='入力された返品理由をカテゴリ判定し、ポリシー適合を確認して最終的な可否を返します。')
  public static List<ReturnEligibilityService.EvaluationResult> evaluateForFlow(
    List<ReasonEvaluationInput> inputs
  ) {
    List<ReturnEligibilityService.EvaluationResult> results = new List<ReturnEligibilityService.EvaluationResult>();
    if (inputs == null) {
      return results;
    }

    Set<Id> productIds = new Set<Id>();
    Set<Id> policyIds = new Set<Id>();
    for (ReasonEvaluationInput input : inputs) {
      if (input == null) {
        continue;
      }
      if (input.productId != null) {
        productIds.add(input.productId);
      }
      if (input.policyId != null) {
        policyIds.add(input.policyId);
      }
    }

    Map<Id, Product2> productsById = productIds.isEmpty()
      ? new Map<Id, Product2>()
      : new Map<Id, Product2>([
          SELECT Id, Name, ProductCode, Family, Description
          FROM Product2
          WHERE Id IN :productIds
        ]);

    Map<Id, StorePolicy__c> policiesById = policyIds.isEmpty()
      ? new Map<Id, StorePolicy__c>()
      : new Map<Id, StorePolicy__c>([
          SELECT Id, Name, PolicyType__c, Description__c, IsActive__c, ValidFrom__c, ValidTo__c
          FROM StorePolicy__c
          WHERE Id IN :policyIds
        ]);

    for (ReasonEvaluationInput input : inputs) {
      ReturnEligibilityService.EvaluationResult baseResult = new ReturnEligibilityService.EvaluationResult();
      if (input == null) {
        results.add(baseResult);
        continue;
      }

      baseResult.productId = input.productId;
      baseResult.productName = input.productName;
      baseResult.productCode = input.productCode;
      baseResult.productFamily = input.productFamily;
      baseResult.productDescription = input.productDescription;
      baseResult.productUnitPrice = input.productUnitPrice;
      baseResult.productFound = input.productId != null;
      baseResult.policyId = input.policyId;
      baseResult.policyProductId = input.policyProductId;
      baseResult.policyName = input.policyName;
      baseResult.policyType = input.policyType;
      baseResult.policyDescription = input.policyDescription;
      baseResult.isReturnable = true;
      baseResult.requiresReason = true;
      baseResult.reasonAccepted = false;
      baseResult.status = 'AWAITING_REASON';
      baseResult.primaryMessage = '返品理由をお聞かせください。';
      baseResult.secondaryMessage = '該当する理由カテゴリを選択してください。';
      baseResult.availableReasonCategories = getAvailableReasonLabels();

      Product2 product = input.productId != null
        ? productsById.get(input.productId)
        : null;
      if (product != null) {
        baseResult.productFound = true;
        baseResult.productId = product.Id;
        baseResult.productName = product.Name;
        baseResult.productCode = product.ProductCode;
        baseResult.productFamily = product.Family;
        baseResult.productDescription = product.Description;
        if (baseResult.productUnitPrice == null) {
          baseResult.productUnitPrice = ReturnProductEligibilityService.getProductUnitPrice(
            product
          );
        }
      }

      if (
        product == null &&
        (input.productId != null ||
        !String.isBlank(input.productName) ||
        !String.isBlank(input.productCode))
      ) {
        product = new Product2(
          Id = input.productId,
          Name = input.productName,
          ProductCode = input.productCode,
          Family = input.productFamily,
          Description = input.productDescription
        );
      }

      StorePolicy__c policy = input.policyId != null
        ? policiesById.get(input.policyId)
        : null;
      if (policy != null) {
        baseResult.policyId = policy.Id;
        baseResult.policyName = policy.Name;
        baseResult.policyType = policy.PolicyType__c;
        baseResult.policyDescription = policy.Description__c;
      }

      if (
        policy == null &&
        (input.policyId != null ||
        !String.isBlank(input.policyType) ||
        !String.isBlank(input.policyName) ||
        !String.isBlank(input.policyDescription))
      ) {
        policy = new StorePolicy__c(
          Id = input.policyId,
          Name = input.policyName,
          PolicyType__c = input.policyType,
          Description__c = input.policyDescription
        );
      }

      results.add(
        evaluate(
          input.returnReason,
          policy,
          baseResult,
          product
        )
      );
    }

    return results;
  }

  public static List<String> getAvailableReasonLabels() {
    return new List<String>(CATEGORY_LABELS.values());
  }

  public static ReturnEligibilityService.EvaluationResult evaluate(
    String returnReason,
    StorePolicy__c policy,
    ReturnEligibilityService.EvaluationResult result,
    Product2 product
  ) {
    if (result == null) {
      result = new ReturnEligibilityService.EvaluationResult();
    }

    String normalizedReason = returnReason != null ? returnReason.trim() : null;
    if (String.isBlank(normalizedReason)) {
      result.isReturnable = true;
      result.requiresReason = true;
      result.status = 'ASK_REASON';
      result.primaryMessage = '返品理由をお聞かせください。';
      result.availableReasonCategories = getAvailableReasonLabels();
      return result;
    }

    ReturnReasonCategory category = resolveReasonCategory(normalizedReason);
    if (category == null) {
      result.requiresReason = true;
      result.status = 'INVALID_REASON_CATEGORY';
      result.primaryMessage = '入力された返品理由を認識できません。もう一度ご入力ください。';
      result.reasonCategory = normalizedReason;
      result.availableReasonCategories = getAvailableReasonLabels();
      return result;
    }

    result.reasonCategory = CATEGORY_LABELS.get(category);

    if (
      !isReasonAllowedByPolicy(
        policy != null ? policy.PolicyType__c : null,
        category
      )
    ) {
      ReturnProductEligibilityService.applyReturnDenied(result, product);
      result.status = 'RETURN_REJECTED_REASON';
      result.reasonAccepted = false;
      return result;
    }

    markReturnApproved(result);
    return result;
  }

  private static Boolean isReasonAllowedByPolicy(
    String policyType,
    ReturnReasonCategory category
  ) {
    if (category == null) {
      return false;
    }

    if (String.isBlank(policyType)) {
      return category != ReturnReasonCategory.OTHER;
    }

    String key = policyType.trim().toUpperCase();
    if (POLICY_REASON_MAP.containsKey(key)) {
      Set<ReturnReasonCategory> allowed = POLICY_REASON_MAP.get(key);
      return allowed != null && allowed.contains(category);
    }

    return false;
  }

  private static ReturnReasonCategory resolveReasonCategory(
    String reasonValue
  ) {
    if (String.isBlank(reasonValue)) {
      return null;
    }

    String candidate = extractCategoryToken(reasonValue);
    if (String.isBlank(candidate)) {
      return null;
    }

    String normalized = candidate.replace('-', '_')
      .replace(' ', '_')
      .toUpperCase();
    try {
      return ReturnReasonCategory.valueOf(normalized);
    } catch (Exception ex) {
      if (LABEL_TO_CATEGORY.containsKey(candidate)) {
        return LABEL_TO_CATEGORY.get(candidate);
      }
      return null;
    }
  }

  private static String extractCategoryToken(String rawValue) {
    if (String.isBlank(rawValue)) {
      return null;
    }

    String trimmed = rawValue.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
          trimmed
        );
        if (payload != null) {
          Object categoryValue = payload.get('category');
          if (categoryValue instanceof String) {
            String categoryString = ((String) categoryValue).trim();
            if (!String.isBlank(categoryString)) {
              return categoryString;
            }
          }
        }
      } catch (Exception ex) {
        // Ignore malformed JSON and continue with fallback handling.
      }
    }

    return trimmed;
  }

  private static Map<ReturnReasonCategory, String> buildReasonCategoryLabels() {
    Map<ReturnReasonCategory, String> labels = new Map<ReturnReasonCategory, String>();
    labels.put(ReturnReasonCategory.DEFECTIVE, '不良・破損');
    labels.put(ReturnReasonCategory.SIZE_FIT, 'サイズが合わない');
    labels.put(ReturnReasonCategory.APPEARANCE, 'イメージと違う');
    labels.put(ReturnReasonCategory.UNWANTED, '不要になった');
    labels.put(ReturnReasonCategory.OTHER, 'その他');
    return labels;
  }

  private static Map<String, ReturnReasonCategory> buildLabelToReasonCategoryMap() {
    Map<String, ReturnReasonCategory> mapping = new Map<String, ReturnReasonCategory>();
    for (ReturnReasonCategory category : ReturnReasonCategory.values()) {
      String label = CATEGORY_LABELS.get(category);
      if (!String.isBlank(label)) {
        mapping.put(label, category);
      }
    }
    return mapping;
  }

  private static Map<String, Set<ReturnReasonCategory>> buildPolicyReasonMap() {
    Map<String, Set<ReturnReasonCategory>> mapping = new Map<String, Set<ReturnReasonCategory>>();
    mapping.put(
      'RETURN_ALL',
      new Set<ReturnReasonCategory>(ALL_REASON_CATEGORIES)
    );
    mapping.put(
      'RETURN_DEFECTIVE_ONLY',
      new Set<ReturnReasonCategory>{ ReturnReasonCategory.DEFECTIVE }
    );
    mapping.put(
      'RETURN_DEFECTIVE_SIZE',
      new Set<ReturnReasonCategory>{
        ReturnReasonCategory.DEFECTIVE,
        ReturnReasonCategory.SIZE_FIT
      }
    );
    mapping.put(
      'RETURN_SIZE_ONLY',
      new Set<ReturnReasonCategory>{ ReturnReasonCategory.SIZE_FIT }
    );
    mapping.put(
      'RETURN_APPEARANCE',
      new Set<ReturnReasonCategory>{ ReturnReasonCategory.APPEARANCE }
    );
    mapping.put(
      'RETURN_SATISFACTION',
      new Set<ReturnReasonCategory>{
        ReturnReasonCategory.APPEARANCE,
        ReturnReasonCategory.UNWANTED
      }
    );
    mapping.put(
      'RETURN_UNWANTED',
      new Set<ReturnReasonCategory>{ ReturnReasonCategory.UNWANTED }
    );
    mapping.put(
      'RETURN_OTHER',
      new Set<ReturnReasonCategory>{ ReturnReasonCategory.OTHER }
    );
    mapping.put(
      'RETURN_DEFECTIVE_APPEARANCE',
      new Set<ReturnReasonCategory>{
        ReturnReasonCategory.DEFECTIVE,
        ReturnReasonCategory.APPEARANCE
      }
    );
    mapping.put(
      'RETURN_DEFECTIVE_SATISFACTION',
      new Set<ReturnReasonCategory>{
        ReturnReasonCategory.DEFECTIVE,
        ReturnReasonCategory.APPEARANCE,
        ReturnReasonCategory.UNWANTED
      }
    );
    return mapping;
  }

  private static void markReturnApproved(
    ReturnEligibilityService.EvaluationResult result
  ) {
    result.isReturnable = true;
    result.reasonAccepted = true;
    result.requiresReason = false;
    result.primaryMessage = 'ご迷惑をおかけし、誠に申し訳ございません。すぐに新しい商品をお送りいたしますが、よろしいでしょうか？';
    result.status = 'RETURN_APPROVED';
  }
}
