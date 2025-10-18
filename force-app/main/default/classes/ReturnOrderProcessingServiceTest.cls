@IsTest
private class ReturnOrderProcessingServiceTest {
    @IsTest
    static void testProcessReturnSuccess() {
        TestData data = TestData.setup();
        Test.setMock(Flow.Interview.Mock.class, new SuccessfulReturnOrderFlowMock());

        ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
        request.orderNumber = 'ORD-10001';
        request.productCode = data.returnableProductCode;
        request.quantity = 1;
        request.returnReason = '糸のほつれがありました';

        Test.startTest();
        ReturnOrderProcessingService.Response response = ReturnOrderProcessingService.processReturn(request);
        Test.stopTest();

        System.assertEquals(true, response.success, 'Response should indicate success.');
        System.assertEquals('RETURN_ORDER_CREATED', response.status, 'Status should indicate creation.');
        System.assertEquals('RO-000123', response.returnOrderNumber, 'Return order number should come from flow.');
        System.assertEquals(
            '返品手続きが完了しました。返品注文番号は『RO-000123』です。この番号をお控えください。担当者が確認次第、メールにてご連絡いたします。',
            response.primaryMessage
        );
        System.assertEquals(null, response.secondaryMessage, 'Secondary message should be cleared.');
        System.assertNotEquals(null, response.evaluation, 'Evaluation result should be returned.');
        System.assertEquals(true, response.evaluation.reasonAccepted, 'Reason should have been accepted.');
    }

    @IsTest
    static void testProcessReturnFlowFailure() {
        TestData data = TestData.setup();
        Test.setMock(Flow.Interview.Mock.class, new FailingReturnOrderFlowMock());

        ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
        request.orderNumber = 'ORD-20001';
        request.productCode = data.returnableProductCode;
        request.quantity = 1;
        request.returnReason = '糸のほつれがあります';

        Test.startTest();
        ReturnOrderProcessingService.Response response = ReturnOrderProcessingService.processReturn(request);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Failure should be reported.');
        System.assertEquals('RETURN_ORDER_FAILED', response.status, 'Status should indicate flow failure.');
        System.assertEquals(null, response.returnOrderNumber, 'Return order number should be empty.');
        System.assertEquals(
            'システムエラーにより返品手続きが完了しませんでした。お手数ですが、再度お試しください。',
            response.primaryMessage
        );
        System.assertEquals('Flow execution failed', response.secondaryMessage, 'Error detail should surface flow error.');
        System.assertEquals(true, response.evaluation.reasonAccepted, 'Evaluation should still indicate accepted reason.');
    }

    @IsTest
    static void testDoesNotInvokeFlowWhenEvaluationRejects() {
        TestData data = TestData.setup();
        FlowInvocationTracker.wasInvoked = false;
        Test.setMock(Flow.Interview.Mock.class, new TrackingFlowMock());

        ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
        request.orderNumber = 'ORD-30001';
        request.productCode = data.returnableProductCode;
        request.quantity = 1;
        request.returnReason = '不要になりました';

        Test.startTest();
        ReturnOrderProcessingService.Response response = ReturnOrderProcessingService.processReturn(request);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Response should be unsuccessful.');
        System.assertEquals('RETURN_REJECTED_REASON', response.status, 'Status should come from evaluation.');
        System.assertEquals('申し訳ございませんが、この商品の返品はポリシーによりお受けできません。', response.primaryMessage);
        System.assertEquals(false, FlowInvocationTracker.wasInvoked, 'Flow should not run when evaluation rejects the request.');
    }

    @IsTest
    static void testValidatesInputs() {
        TestData data = TestData.setup();

        ReturnOrderProcessingService.Request missingOrder = new ReturnOrderProcessingService.Request();
        missingOrder.productCode = data.returnableProductCode;
        missingOrder.quantity = 1;
        missingOrder.returnReason = '糸のほつれがあります';

        try {
            ReturnOrderProcessingService.processReturn(missingOrder);
            System.assert(false, 'Missing order number should throw an exception.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('注文番号'), 'Message should mention order number.');
        }

        ReturnOrderProcessingService.Request missingProduct = new ReturnOrderProcessingService.Request();
        missingProduct.orderNumber = 'ORD-40001';
        missingProduct.quantity = 1;
        missingProduct.returnReason = '糸のほつれがあります';

        try {
            ReturnOrderProcessingService.processReturn(missingProduct);
            System.assert(false, 'Missing product code should throw an exception.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('商品コード'), 'Message should mention product code.');
        }

        ReturnOrderProcessingService.Request invalidQuantity = new ReturnOrderProcessingService.Request();
        invalidQuantity.orderNumber = 'ORD-40002';
        invalidQuantity.productCode = data.returnableProductCode;
        invalidQuantity.quantity = 0;
        invalidQuantity.returnReason = '糸のほつれがあります';

        try {
            ReturnOrderProcessingService.processReturn(invalidQuantity);
            System.assert(false, 'Invalid quantity should throw an exception.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('返品数量'), 'Message should mention quantity.');
        }
    }

    private class TestData {
        Id policyId;
        String returnableProductCode;

        static TestData setup() {
            TestData data = new TestData();
            data.initialize();
            return data;
        }

        private void initialize() {
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

    private class SuccessfulReturnOrderFlowMock implements Flow.Interview.Mock {
        public Map<String, Object> start(Map<String, Object> inputs) {
            System.assertEquals('ORD-10001', (String) inputs.get('OrderNumber'));
            System.assertEquals('NKC-001', (String) inputs.get('ProductCode'));
            System.assertEquals(Decimal.valueOf('1'), (Decimal) inputs.get('Quantity'));
            System.assertEquals('糸のほつれがありました', (String) inputs.get('ReturnReason'));

            return new Map<String, Object>{
                'varReturnOrderNumber' => 'RO-000123'
            };
        }

        public Map<String, Object> resume(Map<String, Object> inputs) {
            return null;
        }
    }

    private class FailingReturnOrderFlowMock implements Flow.Interview.Mock {
        public Map<String, Object> start(Map<String, Object> inputs) {
            throw new AuraHandledException('Flow execution failed');
        }

        public Map<String, Object> resume(Map<String, Object> inputs) {
            return null;
        }
    }

    private class TrackingFlowMock implements Flow.Interview.Mock {
        public Map<String, Object> start(Map<String, Object> inputs) {
            FlowInvocationTracker.wasInvoked = true;
            return new Map<String, Object>();
        }

        public Map<String, Object> resume(Map<String, Object> inputs) {
            return null;
        }
    }

    private class FlowInvocationTracker {
        static Boolean wasInvoked = false;
    }
}
