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
  private static final Map<ReturnReasonCategory, Set<String>> CATEGORY_KEYWORDS = buildReasonCategoryKeywords();
  private static final Map<String, Set<ReturnReasonCategory>> POLICY_REASON_MAP = buildPolicyReasonMap();

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
      result.secondaryMessage = '自由入力で返品理由をご記入ください。';
      if (result.availableReasonCategories != null) {
        result.availableReasonCategories.clear();
      }
      return result;
    }

    ReturnReasonCategory category = resolveReasonCategory(normalizedReason);
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
      return ReturnReasonCategory.OTHER;
    }

    ReturnReasonCategory directMatch = matchDirectCategory(reasonValue);
    if (directMatch != null) {
      return directMatch;
    }

    ReturnReasonCategory keywordMatch = inferCategoryFromKeywords(reasonValue);
    if (keywordMatch != null) {
      return keywordMatch;
    }

    return ReturnReasonCategory.OTHER;
  }

  private static ReturnReasonCategory matchDirectCategory(String rawValue) {
    String candidate = extractCategoryToken(rawValue);
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
      String lowerCandidate = candidate.toLowerCase();
      if (LABEL_TO_CATEGORY.containsKey(lowerCandidate)) {
        return LABEL_TO_CATEGORY.get(lowerCandidate);
      }
      return null;
    }
  }

  private static ReturnReasonCategory inferCategoryFromKeywords(String reasonValue) {
    if (String.isBlank(reasonValue)) {
      return null;
    }

    String normalized = reasonValue.toLowerCase();
    for (ReturnReasonCategory category : CATEGORY_KEYWORDS.keySet()) {
      Set<String> keywords = CATEGORY_KEYWORDS.get(category);
      if (keywords == null || keywords.isEmpty()) {
        continue;
      }
      for (String keyword : keywords) {
        if (String.isBlank(keyword)) {
          continue;
        }
        if (normalized.contains(keyword)) {
          return category;
        }
      }
    }

    return null;
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
        mapping.put(label.toLowerCase(), category);
      }
    }
    return mapping;
  }

  private static Map<ReturnReasonCategory, Set<String>> buildReasonCategoryKeywords() {
    Map<ReturnReasonCategory, Set<String>> keywords = new Map<ReturnReasonCategory, Set<String>>();

    keywords.put(
      ReturnReasonCategory.DEFECTIVE,
      new Set<String>{
        '不良',
        '初期不良',
        '破損',
        '壊れ',
        '欠陥',
        '不具合',
        '故障',
        '汚れ',
        'キズ',
        '傷',
        '破れ',
        '動作しない',
        '作動しない',
        'damage',
        'defect',
        'broken',
        'dirty'
      }
    );

    keywords.put(
      ReturnReasonCategory.SIZE_FIT,
      new Set<String>{
        'サイズ',
        '大きい',
        '小さい',
        'きつい',
        'ゆるい',
        'フィット',
        'fit',
        'tight',
        'loose',
        '長さ',
        '寸法',
        '着丈',
        'ウエスト',
        '幅'
      }
    );

    keywords.put(
      ReturnReasonCategory.APPEARANCE,
      new Set<String>{
        'イメージ',
        '色',
        'カラー',
        '色味',
        '見た目',
        '写真',
        'デザイン',
        '思っていた',
        '違う',
        '質感',
        'image',
        'color',
        'design',
        'look'
      }
    );

    keywords.put(
      ReturnReasonCategory.UNWANTED,
      new Set<String>{
        '不要',
        '不要になった',
        '使わない',
        '必要なく',
        'いらない',
        'キャンセル',
        '間違えて注文',
        '誤って購入',
        '要らなく',
        '気が変わ',
        'changed my mind',
        'no longer need',
        'ordered wrong'
      }
    );

    keywords.put(
      ReturnReasonCategory.OTHER,
      new Set<String>{
        'その他',
        'other'
      }
    );

    Map<ReturnReasonCategory, Set<String>> normalized = new Map<ReturnReasonCategory, Set<String>>();
    for (ReturnReasonCategory category : keywords.keySet()) {
      Set<String> lowered = new Set<String>();
      for (String keyword : keywords.get(category)) {
        if (String.isBlank(keyword)) {
          continue;
        }
        lowered.add(keyword.toLowerCase());
      }
      normalized.put(category, lowered);
    }

    return normalized;
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