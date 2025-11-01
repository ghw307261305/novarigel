@IsTest
private class ReturnOrderProcessingServiceTest {
  @IsTest
  static void testProcessReturnSuccess() {
    TestData data = TestData.setup();

    ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
    request.orderNumber = data.orderNumber;
    request.productIdentifier = data.returnableProductCode;
    request.quantity = 1;
    request.returnReason = '  糸のほつれがありました  ';

    Test.startTest();
    ReturnOrderProcessingService.Response response = ReturnOrderProcessingService.processReturn(
      request
    );
    Test.stopTest();

    System.assertEquals(
      true,
      response.success,
      'Response should indicate success.'
    );
    System.assertEquals(
      'RETURN_ORDER_CREATED',
      response.status,
      'Status should indicate creation.'
    );
    System.assertNotEquals(
      null,
      response.returnOrderNumber,
      'Return order number should be returned.'
    );
    System.assertEquals(
      null,
      response.caseNumber,
      'Case number should be empty when not created.'
    );
    System.assertNotEquals(
      null,
      response.primaryMessage,
      'Success message should be present.'
    );
    System.assertEquals(
      null,
      response.secondaryMessage,
      'Secondary message should be cleared.'
    );
    System.assertEquals(
      true,
      response.evaluation.reasonAccepted,
      'Reason should have been accepted.'
    );

    ReturnOrder createdReturnOrder = [
      SELECT Id, ReturnOrderNumber
      FROM ReturnOrder
      WHERE OrderId = :data.orderId
      LIMIT 1
    ];

    System.assertEquals(
      response.returnOrderNumber,
      createdReturnOrder.ReturnOrderNumber,
      'Return order number should match created record.'
    );

    List<ReturnOrderLineItem> lineItems = [
      SELECT Id, Quantity
      FROM ReturnOrderLineItem
      WHERE ReturnOrderId = :createdReturnOrder.Id
    ];

    System.assertEquals(
      1,
      lineItems.size(),
      'A single return order line item should be created.'
    );
    System.assertEquals(
      request.quantity,
      lineItems[0].Quantity,
      'Line item quantity should match request.'
    );

    List<ReturnOrderLineItemAdjustment> adjustments = [
      SELECT Id
      FROM ReturnOrderLineItemAdjustment
      WHERE ReturnOrderLineItemId = :lineItems[0].Id
    ];

    System.assertEquals(
      1,
      adjustments.size(),
      'An adjustment record should be created.'
    );

    List<ReturnOrderLineItemTax> taxes = [
      SELECT Id, TaxAmount
      FROM ReturnOrderLineItemTax
      WHERE ReturnOrderLineItemId = :lineItems[0].Id
    ];

    System.assertEquals(1, taxes.size(), 'A tax record should be created.');
    System.assertNotEquals(
      null,
      taxes[0].TaxAmount,
      'Tax amount should be populated.'
    );
  }

  @IsTest
  static void testProcessReturnSuccessWithProductName() {
    TestData data = TestData.setup();

    ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
    request.orderNumber = data.orderNumber;
    request.productIdentifier = data.returnableProductName;
    request.quantity = 1;
    request.returnReason = '  糸のほつれがありました  ';

    Test.startTest();
    ReturnOrderProcessingService.Response response = ReturnOrderProcessingService.processReturn(
      request
    );
    Test.stopTest();

    System.assertEquals(true, response.success, 'Response should indicate success.');
    System.assertEquals(
      'RETURN_ORDER_CREATED',
      response.status,
      'Status should indicate creation.'
    );

    ReturnOrder createdReturnOrder = [
      SELECT Id
      FROM ReturnOrder
      WHERE OrderId = :data.orderId
      LIMIT 1
    ];

    System.assertNotEquals(null, createdReturnOrder, 'Return order should be created.');

    List<ReturnOrderLineItem> lineItems = [
      SELECT Id, Quantity
      FROM ReturnOrderLineItem
      WHERE ReturnOrderId = :createdReturnOrder.Id
    ];

    System.assertEquals(1, lineItems.size(), 'A line item should be created.');
    System.assertEquals(1, lineItems[0].Quantity, 'Line item quantity should match.');
  }

  @IsTest
  static void testProcessReturnFromFlow() {
    TestData data = TestData.setup();

    ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
    request.orderNumber = data.orderNumber;
    request.productIdentifier = data.returnableProductCode;
    request.quantity = 1;
    request.returnReason = '糸のほつれがありました';

    Test.startTest();
    List<ReturnOrderProcessingService.Response> responses = ReturnOrderProcessingService.processReturnFromFlow(
      new List<ReturnOrderProcessingService.Request>{ request }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Flow response should contain a single entry.');
    System.assertEquals(true, responses[0].success, 'Flow should surface a successful result.');
    System.assertEquals(
      'RETURN_ORDER_CREATED',
      responses[0].status,
      'Flow response should indicate order creation.'
    );
  }

  @IsTest
  static void testProcessReturnFailureWhenOrderMissing() {
    TestData data = TestData.setup();

    ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
    request.orderNumber = 'ORD-NOT-FOUND';
    request.productIdentifier = data.returnableProductCode;
    request.quantity = 1;
    request.returnReason = '糸のほつれがあります';

    Test.startTest();
    ReturnOrderProcessingService.Response response = ReturnOrderProcessingService.processReturn(
      request
    );
    Test.stopTest();

    System.assertEquals(false, response.success, 'Failure should be reported.');
    System.assertEquals(
      'RETURN_ORDER_FAILED',
      response.status,
      'Status should indicate failure.'
    );
    System.assertEquals(
      null,
      response.returnOrderNumber,
      'Return order number should be empty.'
    );
    System.assertEquals(
      null,
      response.caseNumber,
      'Case number should be empty when the return order fails.'
    );
    System.assertEquals(
      'システムエラーにより返品手続きが完了しませんでした。お手数ですが、再度お試しください。',
      response.primaryMessage
    );
    System.assertEquals(
      '指定された注文が見つかりません。正しい注文番号を入力してください。',
      response.secondaryMessage,
      'Error detail should surface cause.'
    );
    System.assertEquals(
      true,
      response.evaluation.reasonAccepted,
      'Evaluation should still indicate accepted reason.'
    );

    System.assertEquals(
      0,
      [SELECT COUNT() FROM ReturnOrder],
      'No return order should be created when the order is missing.'
    );
  }

  @IsTest
  static void testDoesNotCreateReturnOrderWhenEvaluationRejects() {
    TestData data = TestData.setup();

    ReturnOrderProcessingService.Request request = new ReturnOrderProcessingService.Request();
    request.orderNumber = data.orderNumber;
    request.productIdentifier = data.returnableProductCode;
    request.quantity = 1;
    request.returnReason = '不要になりました';

    Test.startTest();
    ReturnOrderProcessingService.Response response = ReturnOrderProcessingService.processReturn(
      request
    );
    Test.stopTest();

    System.assertEquals(
      false,
      response.success,
      'Response should be unsuccessful.'
    );
    System.assertEquals(
      'RETURN_REJECTED_REASON',
      response.status,
      'Status should come from evaluation.'
    );
    System.assertEquals(
      '申し訳ございませんが、この商品の返品はポリシーによりお受けできません。',
      response.primaryMessage
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM ReturnOrder],
      'Return orders should not be created when evaluation rejects the request.'
    );
  }

  @IsTest
  static void testValidatesInputs() {
    TestData data = TestData.setup();

    ReturnOrderProcessingService.Request missingOrder = new ReturnOrderProcessingService.Request();
    missingOrder.productIdentifier = data.returnableProductCode;
    missingOrder.quantity = 1;
    missingOrder.returnReason = '糸のほつれがあります';

    try {
      ReturnOrderProcessingService.processReturn(missingOrder);
      System.assert(false, 'Missing order number should throw an exception.');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('注文番号'),
        'Message should mention order number.'
      );
    }

    ReturnOrderProcessingService.Request missingProduct = new ReturnOrderProcessingService.Request();
    missingProduct.orderNumber = data.orderNumber;
    missingProduct.quantity = 1;
    missingProduct.returnReason = '糸のほつれがあります';

    try {
      ReturnOrderProcessingService.processReturn(missingProduct);
      System.assert(false, 'Missing product code should throw an exception.');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('商品情報'),
        'Message should mention product identifier.'
      );
    }

    ReturnOrderProcessingService.Request invalidQuantity = new ReturnOrderProcessingService.Request();
    invalidQuantity.orderNumber = data.orderNumber;
    invalidQuantity.productIdentifier = data.returnableProductCode;
    invalidQuantity.quantity = 0;
    invalidQuantity.returnReason = '糸のほつれがあります';

    try {
      ReturnOrderProcessingService.processReturn(invalidQuantity);
      System.assert(false, 'Invalid quantity should throw an exception.');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('返品数量'),
        'Message should mention quantity.'
      );
    }
  }

  private class TestData {
    Id policyId;
    String returnableProductCode;
    String returnableProductName;
    Id orderId;
    String orderNumber;

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

      Account customer = new Account(Name = 'Test Customer');
      insert customer;

      Order orderRecord = new Order(
        AccountId = customer.Id,
        Pricebook2Id = standardPricebookId,
        Status = getDefaultOrderStatus(),
        EffectiveDate = Date.today()
      );
      insert orderRecord;

      OrderItem orderItemRecord = new OrderItem(
        OrderId = orderRecord.Id,
        Quantity = 2,
        UnitPrice = 9800,
        PricebookEntryId = baseEntry.Id
      );
      insert orderItemRecord;

      this.orderId = orderRecord.Id;
      this.orderNumber = orderRecord.OrderNumber;
      this.returnableProductCode = baseProduct.ProductCode;
      this.returnableProductName = baseProduct.Name;

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

    }

    private String getDefaultOrderStatus() {
      Schema.DescribeFieldResult statusField = Schema.sObjectType.Order.fields.Status.getDescribe();
      for (Schema.PicklistEntry entry : statusField.getPicklistValues()) {
        if (entry.isDefaultValue() && entry.isActive()) {
          return entry.getValue();
        }
      }

      for (Schema.PicklistEntry entry : statusField.getPicklistValues()) {
        if (entry.isActive()) {
          return entry.getValue();
        }
      }

      return 'Draft';
    }
  }
}
