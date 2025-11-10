/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-08-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ReturnProductEligibilityService {
  public class ProductEvaluation {
    public ReturnEligibilityService.EvaluationResult result;
    public Boolean canProceed;
    public Product2 product;
    public StorePolicyProduct__c policyProduct;
    public StorePolicy__c policy;
  }

  public class ProductEvaluationInput {
    @InvocableVariable(required=true)
    public String productIdentifier;
  }

  @InvocableMethod(label='返品対象商品の判定' description='商品情報に基づき返品ポリシーを確認し、理由判定フローへ渡すための情報を返します。')
  public static List<ReturnEligibilityService.EvaluationResult> evaluateForFlow(
    List<ProductEvaluationInput> inputs
  ) {
    List<ReturnEligibilityService.EvaluationResult> results = new List<ReturnEligibilityService.EvaluationResult>();
    if (inputs == null) {
      return results;
    }

    for (ProductEvaluationInput input : inputs) {
      ProductEvaluation evaluation = evaluate(
        input != null ? input.productIdentifier : null
      );
      ReturnEligibilityService.EvaluationResult result = evaluation != null &&
        evaluation.result != null
        ? evaluation.result
        : new ReturnEligibilityService.EvaluationResult();
      results.add(result);
    }

    return results;
  }

  public static ProductEvaluation evaluate(String productIdentifier) {
    ProductEvaluation evaluation = new ProductEvaluation();
    evaluation.result = initializeResult();
    evaluation.canProceed = false;

    String normalizedIdentifier = productIdentifier != null
      ? productIdentifier.trim()
      : null;
    if (!validateIdentifier(normalizedIdentifier, evaluation.result)) {
      return evaluation;
    }

    evaluation.product = findProduct(normalizedIdentifier);
    if (evaluation.product == null) {
      evaluation.result.primaryMessage = '該当する商品が見つかりませんでした。商品名または商品コードをご確認ください。';
      evaluation.result.status = 'PRODUCT_NOT_FOUND';
      return evaluation;
    }

    evaluation.result.productFound = true;
    evaluation.result.productId = evaluation.product.Id;
    evaluation.result.productName = evaluation.product.Name;
    evaluation.result.productCode = evaluation.product.ProductCode;
    evaluation.result.productFamily = evaluation.product.Family;
    evaluation.result.productDescription = evaluation.product.Description;
    evaluation.result.productUnitPrice = getProductUnitPrice(
      evaluation.product
    );

    evaluation.policyProduct = findPolicyForProduct(evaluation.product.Id);
    if (
      evaluation.policyProduct == null ||
      evaluation.policyProduct.StorePolicy__r == null
    ) {
      applyPolicyNotFoundState(evaluation.result, evaluation.product);
      evaluation.result.status = 'POLICY_NOT_FOUND';
      return evaluation;
    }

    evaluation.policy = evaluation.policyProduct.StorePolicy__r;
    evaluation.result.policyProductId = evaluation.policyProduct.Id;
    evaluation.result.policyId = evaluation.policy.Id;
    evaluation.result.policyName = evaluation.policy.Name;
    evaluation.result.policyType = evaluation.policy.PolicyType__c;
    evaluation.result.policyDescription = evaluation.policy.Description__c;

    if (
      !isPolicyCurrentlyAllowingReturn(
        evaluation.policyProduct,
        evaluation.policy
      )
    ) {
      applyReturnDenied(evaluation.result, evaluation.product);
      evaluation.result.status = 'RETURN_NOT_ALLOWED';
      return evaluation;
    }

    evaluation.canProceed = true;
    evaluation.result.isReturnable = true;
    evaluation.result.requiresReason = true;
    evaluation.result.reasonAccepted = false;
    evaluation.result.status = 'AWAITING_REASON';
    evaluation.result.primaryMessage = '返品理由をお聞かせください。';
    evaluation.result.secondaryMessage = '返品理由をご記入ください。';
    if (evaluation.result.availableReasonCategories != null) {
      evaluation.result.availableReasonCategories.clear();
    }
    return evaluation;
  }

  public static void applyReturnDenied(
    ReturnEligibilityService.EvaluationResult result,
    Product2 product
  ) {
    applyReturnNotAllowedState(result, product, getProductUnitPrice(product));
  }

  private static ReturnEligibilityService.EvaluationResult initializeResult() {
    ReturnEligibilityService.EvaluationResult result = new ReturnEligibilityService.EvaluationResult();
    result.productFound = false;
    result.isReturnable = false;
    result.reasonAccepted = false;
    result.requiresReason = false;
    result.status = 'UNRESOLVED';
    return result;
  }

  private static Boolean validateIdentifier(
    String productIdentifier,
    ReturnEligibilityService.EvaluationResult result
  ) {
    if (String.isBlank(productIdentifier)) {
      result.primaryMessage = '商品名または商品コードを入力してください。';
      result.status = 'MISSING_IDENTIFIER';
      return false;
    }
    return true;
  }

  private static Product2 findProduct(String productIdentifier) {
    List<Product2> matches = [
      SELECT Id, Name, ProductCode, Family, Description, IsActive
      FROM Product2
      WHERE
        (ProductCode = :productIdentifier
        OR Name = :productIdentifier)
        AND IsActive = TRUE
      LIMIT 1
    ];

    if (!matches.isEmpty()) {
      return matches[0];
    }

    matches = [
      SELECT Id, Name, ProductCode, Family, Description, IsActive
      FROM Product2
      WHERE
        (ProductCode LIKE :('%' + productIdentifier + '%')
        OR Name LIKE :('%' + productIdentifier + '%'))
        AND IsActive = TRUE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    return matches.isEmpty() ? null : matches[0];
  }

  private static StorePolicyProduct__c findPolicyForProduct(Id productId) {
    List<StorePolicyProduct__c> policies = [
      SELECT
        Id,
        Product__c,
        StorePolicy__c,
        IsActive__c,
        Remarks__c,
        StorePolicy__r.Id,
        StorePolicy__r.Name,
        StorePolicy__r.PolicyType__c,
        StorePolicy__r.IsActive__c,
        StorePolicy__r.ValidFrom__c,
        StorePolicy__r.ValidTo__c,
        StorePolicy__r.Description__c
      FROM StorePolicyProduct__c
      WHERE Product__c = :productId
      LIMIT 1
    ];
    return policies.isEmpty() ? null : policies[0];
  }

  private static Boolean isPolicyCurrentlyAllowingReturn(
    StorePolicyProduct__c policyProduct,
    StorePolicy__c policy
  ) {
    if (policyProduct == null || policy == null) {
      return false;
    }

    if (!(policyProduct.IsActive__c == true && policy.IsActive__c == true)) {
      return false;
    }

    Date today = System.today();
    if (
      (policy.ValidFrom__c != null && policy.ValidFrom__c > today) ||
      (policy.ValidTo__c != null &&
      policy.ValidTo__c < today)
    ) {
      return false;
    }

    return true;
  }

  private static void applyPolicyNotFoundState(
    ReturnEligibilityService.EvaluationResult result,
    Product2 product
  ) {
    result.primaryMessage = '申し訳ございません。この商品の返品ポリシー情報が見つかりませんでした。';
    result.secondaryMessage = '代わりに交換はいかがでしょうか？';
    populateExchangeOptions(result, product, null);
  }

  private static void applyReturnNotAllowedState(
    ReturnEligibilityService.EvaluationResult result,
    Product2 product,
    Decimal basePrice
  ) {
    result.primaryMessage = '申し訳ございませんが、この商品の返品はポリシーによりお受けできません。';
    result.secondaryMessage = '代わりに交換はいかがでしょうか？';
    populateExchangeOptions(result, product, basePrice);
  }

  private static void populateExchangeOptions(
    ReturnEligibilityService.EvaluationResult result,
    Product2 product,
    Decimal basePrice
  ) {
    result.exchangeOptions = findExchangeOptions(product);
    if (!result.exchangeOptions.isEmpty()) {
      result.exchangeMessage = '在庫がございます。サイズ／色違いの商品をお送りできますが、よろしいでしょうか？';
      if (result.alternativeProducts == null) {
        result.alternativeProducts = new List<ReturnEligibilityService.ProductSuggestion>();
      } else {
        result.alternativeProducts.clear();
      }
      result.alternativeMessage = null;
      return;
    }

    result.exchangeMessage = '申し訳ございません。現在交換用の在庫がございませんが、似たタイプの別商品をおすすめできます。';
    result.alternativeProducts = findAlternativeProducts(product, basePrice);
    if (!result.alternativeProducts.isEmpty()) {
      result.alternativeMessage = buildAlternativesMessage(
        result.alternativeProducts
      );
    } else {
      result.alternativeMessage = null;
    }
  }

  private static List<ReturnEligibilityService.ProductSuggestion> findExchangeOptions(
    Product2 product
  ) {
    if (product == null) {
      return new List<ReturnEligibilityService.ProductSuggestion>();
    }

    String family = product.Family;
    String baseName = product.Name;
    String baseCode = product.ProductCode;

    String normalizedName = null;
    if (!String.isBlank(baseName)) {
      Integer hyphenIndex = baseName.indexOf('-');
      if (hyphenIndex > 0) {
        normalizedName = baseName.substring(0, hyphenIndex).trim();
      } else {
        normalizedName = baseName.trim();
      }
    }
    String namePattern = normalizedName != null
      ? '%' + normalizedName + '%'
      : null;
    String normalizedLower = normalizedName != null
      ? normalizedName.toLowerCase()
      : null;
    String baseCodeLower = !String.isBlank(baseCode)
      ? baseCode.toLowerCase()
      : null;

    List<Product2> rawVariations = new List<Product2>();
    if (!String.isBlank(family)) {
      rawVariations = [
        SELECT Id, Name, ProductCode, Family, Description
        FROM Product2
        WHERE IsActive = TRUE AND Id != :product.Id AND Family = :family
        ORDER BY CreatedDate DESC
        LIMIT 25
      ];
    }

    List<Product2> variationCandidates = new List<Product2>();
    if (!rawVariations.isEmpty()) {
      for (Product2 candidate : rawVariations) {
        if (variationCandidates.size() >= 5) {
          break;
        }
        Boolean matches = false;
        if (
          normalizedLower != null &&
          candidate.Name != null &&
          candidate.Name.toLowerCase().contains(normalizedLower)
        ) {
          matches = true;
        }
        if (
          !matches &&
          baseCodeLower != null &&
          candidate.ProductCode != null &&
          candidate.ProductCode.toLowerCase().startsWith(baseCodeLower)
        ) {
          matches = true;
        }
        if (!matches && normalizedLower == null && baseCodeLower == null) {
          matches = true;
        }
        if (matches) {
          variationCandidates.add(candidate);
        }
      }
    }

    if (variationCandidates.isEmpty() && !String.isBlank(normalizedName)) {
      rawVariations = [
        SELECT Id, Name, ProductCode, Family, Description
        FROM Product2
        WHERE IsActive = TRUE AND Id != :product.Id AND Name LIKE :namePattern
        ORDER BY CreatedDate DESC
        LIMIT 5
      ];
      variationCandidates.addAll(rawVariations);
    }

    List<ReturnEligibilityService.ProductSuggestion> suggestions = new List<ReturnEligibilityService.ProductSuggestion>();
    for (Product2 variation : variationCandidates) {
      ReturnEligibilityService.ProductSuggestion suggestion = new ReturnEligibilityService.ProductSuggestion();
      suggestion.productId = variation.Id;
      suggestion.name = variation.Name;
      suggestion.productCode = variation.ProductCode;
      suggestion.family = variation.Family;
      suggestion.description = variation.Description;
      suggestion.unitPrice = getProductUnitPrice(variation);
      suggestions.add(suggestion);
    }

    return suggestions;
  }

  private static List<ReturnEligibilityService.ProductSuggestion> findAlternativeProducts(
    Product2 product,
    Decimal basePrice
  ) {
    if (product == null) {
      return new List<ReturnEligibilityService.ProductSuggestion>();
    }

    Id standardPricebookId = getStandardPricebookIdSafe();
    Decimal comparisonPrice = basePrice != null
      ? basePrice
      : getProductUnitPrice(product);

    String family = product.Family;
    List<ReturnEligibilityService.ProductSuggestion> alternatives = new List<ReturnEligibilityService.ProductSuggestion>();
    if (String.isBlank(family)) {
      return alternatives;
    }

    if (comparisonPrice != null && standardPricebookId != null) {
      Decimal tolerance = comparisonPrice * 0.2;
      Decimal minPrice = comparisonPrice - tolerance;
      Decimal maxPrice = comparisonPrice + tolerance;
      List<PricebookEntry> entries = [
        SELECT
          Id,
          Product2.Id,
          Product2.Name,
          Product2.ProductCode,
          Product2.Family,
          Product2.Description,
          UnitPrice
        FROM PricebookEntry
        WHERE
          Pricebook2Id = :standardPricebookId
          AND Product2.IsActive = TRUE
          AND Product2Id != :product.Id
          AND Product2.Family = :family
          AND UnitPrice >= :minPrice
          AND UnitPrice <= :maxPrice
        ORDER BY UnitPrice ASC
        LIMIT 5
      ];
      for (PricebookEntry entry : entries) {
        ReturnEligibilityService.ProductSuggestion suggestion = new ReturnEligibilityService.ProductSuggestion();
        suggestion.productId = entry.Product2Id;
        suggestion.name = entry.Product2.Name;
        suggestion.productCode = entry.Product2.ProductCode;
        suggestion.family = entry.Product2.Family;
        suggestion.description = entry.Product2.Description;
        suggestion.unitPrice = entry.UnitPrice;
        alternatives.add(suggestion);
      }
    }

    if (alternatives.isEmpty()) {
      List<Product2> familyProducts = [
        SELECT Id, Name, ProductCode, Family, Description
        FROM Product2
        WHERE IsActive = TRUE AND Family = :family AND Id != :product.Id
        ORDER BY CreatedDate DESC
        LIMIT 5
      ];
      for (Product2 familyProduct : familyProducts) {
        ReturnEligibilityService.ProductSuggestion suggestion = new ReturnEligibilityService.ProductSuggestion();
        suggestion.productId = familyProduct.Id;
        suggestion.name = familyProduct.Name;
        suggestion.productCode = familyProduct.ProductCode;
        suggestion.family = familyProduct.Family;
        suggestion.description = familyProduct.Description;
        suggestion.unitPrice = getProductUnitPrice(familyProduct);
        alternatives.add(suggestion);
      }
    }

    return alternatives;
  }

  private static String buildAlternativesMessage(
    List<ReturnEligibilityService.ProductSuggestion> suggestions
  ) {
    if (suggestions == null || suggestions.isEmpty()) {
      return null;
    }
    List<String> parts = new List<String>();
    for (ReturnEligibilityService.ProductSuggestion suggestion : suggestions) {
      List<String> fragments = new List<String>();
      if (!String.isBlank(suggestion.name)) {
        fragments.add(suggestion.name);
      }
      if (!String.isBlank(suggestion.productCode)) {
        fragments.add('商品コード: ' + suggestion.productCode);
      }
      if (suggestion.unitPrice != null) {
        fragments.add(
          '価格: ¥' + String.valueOf(Math.round(suggestion.unitPrice))
        );
      }
      parts.add(String.join(fragments, ' / '));
    }
    return '代替候補: ' + String.join(parts, '、 ');
  }

  public static Decimal getProductUnitPrice(Product2 product) {
    Id standardPricebookId = getStandardPricebookIdSafe();
    if (product == null || standardPricebookId == null) {
      return null;
    }

    List<PricebookEntry> entries = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :standardPricebookId
        AND Product2Id = :product.Id
        AND IsActive = TRUE
      LIMIT 1
    ];
    return entries.isEmpty() ? null : entries[0].UnitPrice;
  }

  private static Id getStandardPricebookIdSafe() {
    try {
      if (Test.isRunningTest()) {
        return Test.getStandardPricebookId();
      }

      List<Pricebook2> standard = [
        SELECT Id
        FROM Pricebook2
        WHERE IsStandard = TRUE
        LIMIT 1
      ];
      return standard.isEmpty() ? null : standard[0].Id;
    } catch (Exception ex) {
      return null;
    }
  }
}
