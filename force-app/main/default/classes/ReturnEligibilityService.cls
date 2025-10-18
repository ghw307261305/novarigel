public with sharing class ReturnEligibilityService {
    public class EvaluationInput {
        @InvocableVariable(required=true)
        public String productIdentifier;

        @InvocableVariable
        public String returnReason;
    }

    public class EvaluationResult {
        @AuraEnabled
        @InvocableVariable
        public Boolean productFound;

        @AuraEnabled
        @InvocableVariable
        public Boolean requiresReason;

        @AuraEnabled
        @InvocableVariable
        public Boolean isReturnable;

        @AuraEnabled
        @InvocableVariable
        public Boolean reasonAccepted;

        @AuraEnabled
        @InvocableVariable
        public String reasonCategory;

        @AuraEnabled
        @InvocableVariable
        public String policyName;

        @AuraEnabled
        @InvocableVariable
        public String policyType;

        @AuraEnabled
        @InvocableVariable
        public String policyDescription;

        @AuraEnabled
        @InvocableVariable
        public String primaryMessage;

        @AuraEnabled
        @InvocableVariable
        public String secondaryMessage;

        @AuraEnabled
        @InvocableVariable
        public String exchangeMessage;

        @AuraEnabled
        public List<ProductSuggestion> exchangeOptions;

        @AuraEnabled
        public List<ProductSuggestion> alternativeProducts;

        @AuraEnabled
        @InvocableVariable
        public String alternativeMessage;

        @AuraEnabled
        @InvocableVariable
        public String status;

        public EvaluationResult() {
            this.exchangeOptions = new List<ProductSuggestion>();
            this.alternativeProducts = new List<ProductSuggestion>();
        }
    }

    public class ProductSuggestion {
        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String productCode;

        @AuraEnabled
        public Decimal unitPrice;

        @AuraEnabled
        public String family;

        @AuraEnabled
        public String description;
    }

    private enum ReturnReasonCategory {
        DEFECTIVE,
        SIZE_FIT,
        APPEARANCE,
        UNWANTED,
        OTHER
    }

    private static final Set<ReturnReasonCategory> ALL_REASON_CATEGORIES = new Set<ReturnReasonCategory>(ReturnReasonCategory.values());

    private static final Map<String, Set<ReturnReasonCategory>> POLICY_REASON_MAP = buildPolicyReasonMap();

    @AuraEnabled
    public static EvaluationResult evaluateProductReturn(String productIdentifier, String returnReason) {
        return handleEvaluation(productIdentifier, returnReason);
    }

    @InvocableMethod(label='返品ポリシー判定' description='商品名または商品コードと返品理由に基づいて返品可否を判定し、適切なガイダンスを返します。')
    public static List<EvaluationResult> evaluate(List<EvaluationInput> inputs) {
        List<EvaluationResult> results = new List<EvaluationResult>();
        for (EvaluationInput input : inputs) {
            results.add(handleEvaluation(input != null ? input.productIdentifier : null,
                                         input != null ? input.returnReason : null));
        }
        return results;
    }

    private static EvaluationResult handleEvaluation(String productIdentifier, String returnReason) {
        EvaluationResult result = new EvaluationResult();
        result.productFound = false;
        result.isReturnable = false;
        result.reasonAccepted = false;
        result.requiresReason = false;
        result.status = 'UNRESOLVED';

        String trimmedIdentifier = productIdentifier != null ? productIdentifier.trim() : null;
        if (String.isBlank(trimmedIdentifier)) {
            result.primaryMessage = '商品名または商品コードを入力してください。';
            result.status = 'MISSING_IDENTIFIER';
            return result;
        }

        Product2 product = findProduct(trimmedIdentifier);
        if (product == null) {
            result.primaryMessage = '該当する商品が見つかりませんでした。商品名または商品コードをご確認ください。';
            result.status = 'PRODUCT_NOT_FOUND';
            return result;
        }

        result.productFound = true;

        StorePolicyProduct__c policyProduct = findPolicyForProduct(product.Id);
        if (policyProduct == null || policyProduct.StorePolicy__r == null) {
            result.primaryMessage = '申し訳ございません。この商品の返品ポリシー情報が見つかりませんでした。';
            result.secondaryMessage = '代わりに交換はいかがでしょうか？';
            result.exchangeOptions = findExchangeOptions(product);
            if (!result.exchangeOptions.isEmpty()) {
                result.exchangeMessage = '在庫がございます。サイズ／色違いの商品をお送りできますが、よろしいでしょうか？';
            } else {
                result.exchangeMessage = '申し訳ございません。現在交換用の在庫がございませんが、似たタイプの別商品をおすすめできます。';
                result.alternativeProducts = findAlternativeProducts(product, null);
                if (!result.alternativeProducts.isEmpty()) {
                    result.alternativeMessage = buildAlternativesMessage(result.alternativeProducts);
                }
            }
            result.status = 'POLICY_NOT_FOUND';
            return result;
        }

        StorePolicy__c policy = policyProduct.StorePolicy__r;
        result.policyName = policy.Name;
        result.policyType = policy.PolicyType__c;
        result.policyDescription = policy.Description__c;

        Boolean policyAllowsReturn = isPolicyCurrentlyAllowingReturn(policyProduct, policy);
        if (!policyAllowsReturn) {
            result.primaryMessage = '申し訳ございませんが、この商品の返品はポリシーによりお受けできません。';
            result.secondaryMessage = '代わりに交換はいかがでしょうか？';
            result.exchangeOptions = findExchangeOptions(product);
            if (!result.exchangeOptions.isEmpty()) {
                result.exchangeMessage = '在庫がございます。サイズ／色違いの商品をお送りできますが、よろしいでしょうか？';
            } else {
                result.exchangeMessage = '申し訳ございません。現在交換用の在庫がございませんが、似たタイプの別商品をおすすめできます。';
                result.alternativeProducts = findAlternativeProducts(product, getProductUnitPrice(product));
                if (!result.alternativeProducts.isEmpty()) {
                    result.alternativeMessage = buildAlternativesMessage(result.alternativeProducts);
                }
            }
            result.status = 'RETURN_NOT_ALLOWED';
            return result;
        }

        if (String.isBlank(returnReason)) {
            result.primaryMessage = '返品理由をお聞かせください。';
            result.isReturnable = true;
            result.requiresReason = true;
            result.status = 'ASK_REASON';
            return result;
        }

        ReturnReasonCategory category = categorizeReason(returnReason);
        result.reasonCategory = category != null ? category.name() : null;

        Boolean reasonMatchesPolicy = category != null && isReasonAllowedByPolicy(policy.PolicyType__c, category);
        if (reasonMatchesPolicy) {
            result.isReturnable = true;
            result.reasonAccepted = true;
            result.primaryMessage = 'ご迷惑をおかけし、誠に申し訳ございません。すぐに新しい商品をお送りいたしますが、よろしいでしょうか？';
            result.status = 'RETURN_APPROVED';
            return result;
        }

        result.primaryMessage = '申し訳ございませんが、この商品の返品はポリシーによりお受けできません。';
        result.secondaryMessage = '代わりに交換はいかがでしょうか？';
        result.exchangeOptions = findExchangeOptions(product);
        if (!result.exchangeOptions.isEmpty()) {
            result.exchangeMessage = '在庫がございます。サイズ／色違いの商品をお送りできますが、よろしいでしょうか？';
        } else {
            result.exchangeMessage = '申し訳ございません。現在交換用の在庫がございませんが、似たタイプの別商品をおすすめできます。';
            result.alternativeProducts = findAlternativeProducts(product, getProductUnitPrice(product));
            if (!result.alternativeProducts.isEmpty()) {
                result.alternativeMessage = buildAlternativesMessage(result.alternativeProducts);
            }
        }
        result.status = 'RETURN_REJECTED_REASON';
        return result;
    }

    private static Product2 findProduct(String productIdentifier) {
        List<Product2> matches = [
            SELECT Id, Name, ProductCode, Family, Description, IsActive
            FROM Product2
            WHERE (ProductCode = :productIdentifier OR Name = :productIdentifier)
            AND IsActive = true
            LIMIT 1
        ];

        if (!matches.isEmpty()) {
            return matches[0];
        }

        matches = [
            SELECT Id, Name, ProductCode, Family, Description, IsActive
            FROM Product2
            WHERE (ProductCode LIKE :('%' + productIdentifier + '%') OR Name LIKE :('%' + productIdentifier + '%'))
            AND IsActive = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return matches.isEmpty() ? null : matches[0];
    }

    private static StorePolicyProduct__c findPolicyForProduct(Id productId) {
        List<StorePolicyProduct__c> policies = [
            SELECT Id, Product__c, StorePolicy__c, IsActive__c, Remarks__c,
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

    private static Boolean isPolicyCurrentlyAllowingReturn(StorePolicyProduct__c policyProduct, StorePolicy__c policy) {
        if (policyProduct == null || policy == null) {
            return false;
        }

        if (!(policyProduct.IsActive__c == true && policy.IsActive__c == true)) {
            return false;
        }

        Date today = System.today();
        if ((policy.ValidFrom__c != null && policy.ValidFrom__c > today) ||
            (policy.ValidTo__c != null && policy.ValidTo__c < today)) {
            return false;
        }

        return true;
    }

    private static ReturnReasonCategory categorizeReason(String reason) {
        if (String.isBlank(reason)) {
            return null;
        }

        String normalized = reason.toLowerCase();
        if (normalized.contains('ほつれ') || normalized.contains('破れ') || normalized.contains('壊れ') ||
            normalized.contains('不良') || normalized.contains('欠陥') || normalized.contains('fault') ||
            normalized.contains('damage') || normalized.contains('damaged') || normalized.contains('defect')) {
            return ReturnReasonCategory.DEFECTIVE;
        }

        if (normalized.contains('サイズ') || normalized.contains('大き') || normalized.contains('小さ') ||
            normalized.contains('fit') || normalized.contains('きつ') || normalized.contains('ゆる') ||
            normalized.contains('丈が') || normalized.contains('幅が')) {
            return ReturnReasonCategory.SIZE_FIT;
        }

        if (normalized.contains('イメージ') || normalized.contains('色が') || normalized.contains('色違い') ||
            normalized.contains('デザイン') || normalized.contains('思っていた') || normalized.contains('見た目') ||
            normalized.contains('color')) {
            return ReturnReasonCategory.APPEARANCE;
        }

        if (normalized.contains('不要') || normalized.contains('使わない') || normalized.contains('要らなく') ||
            normalized.contains('間違って') || normalized.contains('キャンセル') || normalized.contains('気が変わった') ||
            normalized.contains('不要になった') || normalized.contains('不要になりまし') || normalized.contains('不要です')) {
            return ReturnReasonCategory.UNWANTED;
        }

        return ReturnReasonCategory.OTHER;
    }

    private static Boolean isReasonAllowedByPolicy(String policyType, ReturnReasonCategory category) {
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

    private static Map<String, Set<ReturnReasonCategory>> buildPolicyReasonMap() {
        Map<String, Set<ReturnReasonCategory>> mapping = new Map<String, Set<ReturnReasonCategory>>();
        mapping.put('RETURN_ALL', new Set<ReturnReasonCategory>(ALL_REASON_CATEGORIES));
        mapping.put('RETURN_DEFECTIVE_ONLY', new Set<ReturnReasonCategory>{ReturnReasonCategory.DEFECTIVE});
        mapping.put('RETURN_DEFECTIVE_SIZE', new Set<ReturnReasonCategory>{ReturnReasonCategory.DEFECTIVE, ReturnReasonCategory.SIZE_FIT});
        mapping.put('RETURN_SIZE_ONLY', new Set<ReturnReasonCategory>{ReturnReasonCategory.SIZE_FIT});
        mapping.put('RETURN_APPEARANCE', new Set<ReturnReasonCategory>{ReturnReasonCategory.APPEARANCE});
        mapping.put('RETURN_SATISFACTION', new Set<ReturnReasonCategory>{ReturnReasonCategory.APPEARANCE, ReturnReasonCategory.UNWANTED});
        mapping.put('RETURN_UNWANTED', new Set<ReturnReasonCategory>{ReturnReasonCategory.UNWANTED});
        mapping.put('RETURN_OTHER', new Set<ReturnReasonCategory>{ReturnReasonCategory.OTHER});
        mapping.put('RETURN_DEFECTIVE_APPEARANCE', new Set<ReturnReasonCategory>{ReturnReasonCategory.DEFECTIVE, ReturnReasonCategory.APPEARANCE});
        mapping.put('RETURN_DEFECTIVE_SATISFACTION', new Set<ReturnReasonCategory>{ReturnReasonCategory.DEFECTIVE, ReturnReasonCategory.APPEARANCE, ReturnReasonCategory.UNWANTED});
        return mapping;
    }

    private static List<ProductSuggestion> findExchangeOptions(Product2 product) {
        if (product == null) {
            return new List<ProductSuggestion>();
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
        String namePattern = normalizedName != null ? '%' + normalizedName + '%' : null;
        String normalizedLower = normalizedName != null ? normalizedName.toLowerCase() : null;
        String baseCodeLower = !String.isBlank(baseCode) ? baseCode.toLowerCase() : null;

        List<Product2> rawVariations = new List<Product2>();
        if (!String.isBlank(family)) {
            rawVariations = [
                SELECT Id, Name, ProductCode, Family, Description
                FROM Product2
                WHERE IsActive = true
                  AND Id != :product.Id
                  AND Family = :family
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
                if (normalizedLower != null && candidate.Name != null && candidate.Name.toLowerCase().contains(normalizedLower)) {
                    matches = true;
                }
                if (!matches && baseCodeLower != null && candidate.ProductCode != null && candidate.ProductCode.toLowerCase().startsWith(baseCodeLower)) {
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
                WHERE IsActive = true
                  AND Id != :product.Id
                  AND Name LIKE :namePattern
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            variationCandidates.addAll(rawVariations);
        }

        List<ProductSuggestion> suggestions = new List<ProductSuggestion>();
        for (Product2 variation : variationCandidates) {
            ProductSuggestion suggestion = new ProductSuggestion();
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

    private static List<ProductSuggestion> findAlternativeProducts(Product2 product, Decimal basePrice) {
        if (product == null) {
            return new List<ProductSuggestion>();
        }

        Id standardPricebookId = getStandardPricebookIdSafe();
        Decimal comparisonPrice = basePrice != null ? basePrice : getProductUnitPrice(product);

        String family = product.Family;
        List<ProductSuggestion> alternatives = new List<ProductSuggestion>();
        if (String.isBlank(family)) {
            return alternatives;
        }

        if (comparisonPrice != null && standardPricebookId != null) {
            Decimal tolerance = comparisonPrice * 0.2;
            Decimal minPrice = comparisonPrice - tolerance;
            Decimal maxPrice = comparisonPrice + tolerance;
            List<PricebookEntry> entries = [
                SELECT Id, Product2.Id, Product2.Name, Product2.ProductCode, Product2.Family, Product2.Description, UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id = :standardPricebookId
                  AND Product2.IsActive = true
                  AND Product2Id != :product.Id
                  AND Product2.Family = :family
                  AND UnitPrice >= :minPrice
                  AND UnitPrice <= :maxPrice
                ORDER BY UnitPrice ASC
                LIMIT 5
            ];
            for (PricebookEntry entry : entries) {
                ProductSuggestion suggestion = new ProductSuggestion();
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
                WHERE IsActive = true
                  AND Family = :family
                  AND Id != :product.Id
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            for (Product2 familyProduct : familyProducts) {
                ProductSuggestion suggestion = new ProductSuggestion();
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

    private static String buildAlternativesMessage(List<ProductSuggestion> suggestions) {
        if (suggestions == null || suggestions.isEmpty()) {
            return null;
        }
        List<String> parts = new List<String>();
        for (ProductSuggestion suggestion : suggestions) {
            List<String> fragments = new List<String>();
            if (!String.isBlank(suggestion.name)) {
                fragments.add(suggestion.name);
            }
            if (!String.isBlank(suggestion.productCode)) {
                fragments.add('商品コード: ' + suggestion.productCode);
            }
            if (suggestion.unitPrice != null) {
                fragments.add('価格: ¥' + String.valueOf(Math.round(suggestion.unitPrice)));
            }
            parts.add(String.join(fragments, ' / '));
        }
        return '代替候補: ' + String.join(parts, '、 ');
    }

    private static Decimal getProductUnitPrice(Product2 product) {
        Id standardPricebookId = getStandardPricebookIdSafe();
        if (product == null || standardPricebookId == null) {
            return null;
        }

        List<PricebookEntry> entries = [
            SELECT UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId
              AND Product2Id = :product.Id
              AND IsActive = true
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
                WHERE IsStandard = true
                LIMIT 1
            ];
            return standard.isEmpty() ? null : standard[0].Id;
        } catch (Exception ex) {
            return null;
        }
    }
}
