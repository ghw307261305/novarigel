@IsTest
private class ReturnEligibilityServiceTest {
    @IsTest
    static void testAskForReasonWhenReturnable() {
        Test.startTest();
        TestData data = TestData.setup();
        ReturnEligibilityService.EvaluationResult result = ReturnEligibilityService.evaluateProductReturn(data.returnableProductCode, null);
        Test.stopTest();

        System.assertEquals(true, result.productFound, 'Product should be found.');
        System.assertEquals(true, result.isReturnable, 'Policy should allow return.');
        System.assertEquals(true, result.requiresReason, 'Should request reason when not provided.');
        System.assertEquals('ASK_REASON', result.status);
        System.assertEquals('返品理由をお聞かせください。', result.primaryMessage);
    }

    @IsTest
    static void testApproveReturnWhenReasonMatchesPolicy() {
        TestData data = TestData.setup();

        Test.startTest();
        ReturnEligibilityService.EvaluationResult result = ReturnEligibilityService.evaluateProductReturn(
            data.returnableProductCode,
            '糸のほつれがありました'
        );
        Test.stopTest();

        System.assertEquals(true, result.productFound);
        System.assertEquals(true, result.isReturnable);
        System.assertEquals(true, result.reasonAccepted);
        System.assertEquals('RETURN_APPROVED', result.status);
        System.assertEquals('ご迷惑をおかけし、誠に申し訳ございません。すぐに新しい商品をお送りいたしますが、よろしいでしょうか？', result.primaryMessage);
    }

    @IsTest
    static void testRejectReturnWhenReasonNotAllowed() {
        TestData data = TestData.setup();

        Test.startTest();
        ReturnEligibilityService.EvaluationResult result = ReturnEligibilityService.evaluateProductReturn(
            data.returnableProductCode,
            '不要になったので返品したいです'
        );
        Test.stopTest();

        System.assertEquals(true, result.productFound);
        System.assertEquals(false, result.isReturnable);
        System.assertEquals('RETURN_REJECTED_REASON', result.status);
        System.assertEquals('申し訳ございませんが、この商品の返品はポリシーによりお受けできません。', result.primaryMessage);
        System.assertEquals('代わりに交換はいかがでしょうか？', result.secondaryMessage);
        System.assertEquals(true, result.exchangeOptions.size() > 0, 'Exchange options should be suggested.');
    }

    @IsTest
    static void testRejectReturnWhenPolicyInactive() {
        TestData data = TestData.setup();
        deactivatePolicy(data.policyId);

        Test.startTest();
        ReturnEligibilityService.EvaluationResult result = ReturnEligibilityService.evaluateProductReturn(
            data.returnableProductCode,
            '糸のほつれがあります'
        );
        Test.stopTest();

        System.assertEquals(false, result.isReturnable);
        System.assertEquals('RETURN_NOT_ALLOWED', result.status);
        System.assertEquals('申し訳ございませんが、この商品の返品はポリシーによりお受けできません。', result.primaryMessage);
    }

    @IsTest
    static void testSuggestAlternativesWhenNoExchange() {
        TestData data = TestData.setupNoExchange();

        Test.startTest();
        ReturnEligibilityService.EvaluationResult result = ReturnEligibilityService.evaluateProductReturn(
            data.returnableProductCode,
            '不要になりました'
        );
        Test.stopTest();

        System.assertEquals(false, result.isReturnable);
        System.assertEquals('RETURN_REJECTED_REASON', result.status);
        System.assertEquals('申し訳ございません。現在交換用の在庫がございませんが、似たタイプの別商品をおすすめできます。', result.exchangeMessage);
        System.assert(result.alternativeProducts.size() > 0, 'Alternative suggestions should be returned.');
        System.assert(!String.isBlank(result.alternativeMessage), 'Alternative message should be populated.');
    }

    @IsTest
    static void testProductNotFound() {
        Test.startTest();
        ReturnEligibilityService.EvaluationResult result = ReturnEligibilityService.evaluateProductReturn('UNKNOWN_CODE', null);
        Test.stopTest();

        System.assertEquals(false, result.productFound);
        System.assertEquals('PRODUCT_NOT_FOUND', result.status);
        System.assertEquals('該当する商品が見つかりませんでした。商品名または商品コードをご確認ください。', result.primaryMessage);
    }

    private static void deactivatePolicy(Id policyId) {
        StorePolicy__c policy = [SELECT Id, IsActive__c FROM StorePolicy__c WHERE Id = :policyId];
        policy.IsActive__c = false;
        update policy;
    }

    private class TestData {
        Id policyId;
        String returnableProductCode;

        static TestData setup() {
            TestData data = new TestData();
            data.initialize(true);
            return data;
        }

        static TestData setupNoExchange() {
            TestData data = new TestData();
            data.initialize(false);
            return data;
        }

        private void initialize(Boolean includeExchangeVariation) {
            Id standardPricebookId = Test.getStandardPricebookId();

            Product2 baseProduct = new Product2(
                Name = 'Nova Knit Cardigan',
                ProductCode = 'NKC-001',
                Family = 'Apparel',
                IsActive = true
            );
            insert baseProduct;

            PricebookEntry baseEntry = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = baseProduct.Id,
                UnitPrice = 9800,
                IsActive = true,
                UseStandardPrice = false
            );
            insert baseEntry;

            StorePolicy__c policy = new StorePolicy__c(
                Name = 'Defective Only Return',
                PolicyType__c = 'RETURN_DEFECTIVE_ONLY',
                IsActive__c = true,
                ValidFrom__c = Date.today().addDays(-30),
                ValidTo__c = Date.today().addDays(30),
                Description__c = '不良品のみ返品可能です。'
            );
            insert policy;
            this.policyId = policy.Id;

            StorePolicyProduct__c mapping = new StorePolicyProduct__c(
                Product__c = baseProduct.Id,
                StorePolicy__c = policy.Id,
                IsActive__c = true
            );
            insert mapping;

            if (includeExchangeVariation) {
                Product2 variation = new Product2(
                    Name = 'Nova Knit Cardigan - Blue',
                    ProductCode = 'NKC-001-BL',
                    Family = 'Apparel',
                    IsActive = true
                );
                insert variation;

                PricebookEntry variationEntry = new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = variation.Id,
                    UnitPrice = 9800,
                    IsActive = true,
                    UseStandardPrice = false
                );
                insert variationEntry;
            }

            Product2 alternative1 = new Product2(
                Name = 'Nova Knit Sweater',
                ProductCode = 'NKS-100',
                Family = 'Apparel',
                IsActive = true
            );
            insert alternative1;

            PricebookEntry alternativeEntry1 = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = alternative1.Id,
                UnitPrice = 9500,
                IsActive = true,
                UseStandardPrice = false
            );
            insert alternativeEntry1;

            Product2 alternative2 = new Product2(
                Name = 'Nova Knit Hoodie',
                ProductCode = 'NKH-200',
                Family = 'Apparel',
                IsActive = true
            );
            insert alternative2;

            PricebookEntry alternativeEntry2 = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = alternative2.Id,
                UnitPrice = 9900,
                IsActive = true,
                UseStandardPrice = false
            );
            insert alternativeEntry2;

            this.returnableProductCode = baseProduct.ProductCode;
        }
    }
}
