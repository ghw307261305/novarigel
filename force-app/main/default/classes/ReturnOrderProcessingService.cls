/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-11-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ReturnOrderProcessingService {

  public class ReturnOrderRequest {
    @InvocableVariable(required=true)
    public String orderNumber;

    @InvocableVariable(required=true)
    public String productIdentifier;

    @InvocableVariable
    public String quantity;

    @InvocableVariable
    public String returnReason;

    @InvocableVariable
    public String returnDetailReason;
  }

  public class ReturnOrderResponse {
    @AuraEnabled
    @InvocableVariable
    public Boolean success;

    @AuraEnabled
    @InvocableVariable
    public String status;

    @AuraEnabled
    @InvocableVariable
    public String primaryMessage;

    @AuraEnabled
    @InvocableVariable
    public String secondaryMessage;

    @AuraEnabled
    @InvocableVariable
    public String returnOrderNumber;

    @AuraEnabled
    @InvocableVariable
    public String caseNumber;

    @AuraEnabled
    @InvocableVariable
    public ReturnEligibilityService.EvaluationResult evaluation;
  }

  private class ReturnOrderOutcome {
    Boolean success = false;
    String returnOrderNumber;
    String caseNumber;
    String errorMessage;
  }

  private static ReturnOrderResponse buildErrorResponse(
    String status,
    String primaryMessage,
    String secondaryMessage
  ) {
    ReturnOrderResponse response = new ReturnOrderResponse();
    response.success = false;
    response.status = status;
    response.primaryMessage = primaryMessage;
    response.secondaryMessage = secondaryMessage;
    response.returnOrderNumber = null;
    response.caseNumber = null;
    response.evaluation = null;
    return response;
  }

  @AuraEnabled
  public static ReturnOrderResponse processReturn(ReturnOrderRequest request) {
    if (request == null) {
      return buildErrorResponse(
        'INVALID_REQUEST',
        '返品手続きを進めるには注文情報が必要です。',
        null
      );
    }

    String normalizedOrderNumber = request.orderNumber != null
      ? request.orderNumber.trim()
      : null;
    String normalizedProductIdentifier = normalizeProductIdentifier(
      request.productIdentifier
    );
    Product2 resolvedProduct = findProductRecord(normalizedProductIdentifier);
    String resolvedProductIdentifier = resolveProductIdentifier(
      normalizedProductIdentifier,
      resolvedProduct
    );
    String normalizedReturnReason = request.returnReason != null
      ? request.returnReason.trim()
      : null;

    String normalizedReturnDetailReason = request.returnDetailReason != null
      ? request.returnDetailReason.trim()
      : null;

    if (String.isBlank(normalizedReturnReason)) {
      normalizedReturnReason = null;
    }

    if (String.isBlank(normalizedReturnDetailReason)) {
      normalizedReturnDetailReason = null;
    }

    // Decimal quantity = Decimal.valueOf(request.quantity);
    Decimal quantity = 1;

    String validationError = validateInputs(
      normalizedOrderNumber,
      resolvedProductIdentifier,
      quantity
    );

    if (validationError != null) {
      return buildErrorResponse('INVALID_INPUT', validationError, null);
    }

    // ReturnEligibilityService.EvaluationResult evaluation = ReturnEligibilityService.evaluateProductReturn(
    //   resolvedProductIdentifier,
    //   normalizedReturnReason
    // );

    ReturnOrderResponse response = new ReturnOrderResponse();
    // response.evaluation = evaluation;

    // if (evaluation == null) {
    //   response.success = false;
    //   response.status = 'EVALUATION_FAILED';
    //   response.primaryMessage = '返品手続きを進めることができませんでした。お手数ですが、再度お試しください。';
    //   return response;
    // }

    // if (
    //   !(evaluation.productFound && evaluation.isReturnable && evaluation.reasonAccepted)
    // ) {
    //   response.success = false;
    //   response.status = evaluation.status;
    //   response.primaryMessage = evaluation.primaryMessage;
    //   response.secondaryMessage = evaluation.secondaryMessage;
    //   return response;
    // }

    ReturnOrderOutcome outcome = createReturnOrder(
      normalizedOrderNumber,
      resolvedProductIdentifier,
      resolvedProduct != null ? resolvedProduct.Id : null,
      quantity,
      normalizedReturnReason,
      normalizedReturnDetailReason
    );

    if (outcome.success) {
      response.success = true;
      response.status = 'RETURN_ORDER_CREATED';
      response.returnOrderNumber = outcome.returnOrderNumber;
      response.caseNumber = outcome.caseNumber;
      response.primaryMessage = buildSuccessMessage(outcome.returnOrderNumber);
      response.secondaryMessage = null;
    } else {
      response.success = false;
      response.status = 'RETURN_ORDER_FAILED';
      response.returnOrderNumber = null;
      response.caseNumber = null;
      response.primaryMessage = 'システムエラーにより返品手続きが完了しませんでした。お手数ですが、再度お試しください。';
      response.secondaryMessage = String.isBlank(outcome.errorMessage)
        ? null
        : outcome.errorMessage;
    }

    return response;
  }

  @InvocableMethod(
    label = '返品注文処理' description = 'Flow から返品注文を作成します。'
  )
  public static List<ReturnOrderResponse> processReturnFromFlow(List<ReturnOrderRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return new List<ReturnOrderResponse>{
        buildErrorResponse(
          'INVALID_REQUEST',
          '返品手続きを進めるには注文情報が必要です。',
          null
        )
      };
    }

    List<ReturnOrderResponse> responses = new List<ReturnOrderResponse>();
    for (ReturnOrderRequest request : requests) {
      responses.add(processReturn(request));
    }

    return responses;
  }

  private static String validateInputs(
    String orderNumber,
    String productIdentifier,
    Decimal quantity
  ) {
    if (String.isBlank(orderNumber)) {
      return '返品手続きを進めるには注文番号が必要です。';
    }

    if (String.isBlank(productIdentifier)) {
      return '返品手続きを進めるには商品情報が必要です。';
    }

    if (quantity == null || quantity <= 0) {
      return '返品数量は1以上の数値を指定してください。';
    }

    return null;
  }

  private static String normalizeProductIdentifier(String input) {
    return String.isBlank(input) ? null : input.trim();
  }

  private static Product2 findProductRecord(String identifier) {
    if (String.isBlank(identifier)) {
      return null;
    }

    List<Product2> products = [
      SELECT Id, Name, ProductCode
      FROM Product2
      WHERE IsActive = TRUE AND (ProductCode = :identifier OR Name = :identifier)
      LIMIT 1
    ];

    return products.isEmpty() ? null : products[0];
  }

  private static String resolveProductIdentifier(
    String identifier,
    Product2 productRecord
  ) {
    if (productRecord != null) {
      if (!String.isBlank(productRecord.ProductCode)) {
        return productRecord.ProductCode;
      }
      if (!String.isBlank(productRecord.Name)) {
        return productRecord.Name;
      }
    }

    return identifier;
  }

  private static String buildSuccessMessage(String returnOrderNumber) {
    String orderNumber = String.isBlank(returnOrderNumber)
      ? '不明'
      : returnOrderNumber;
    return '返品手続きが完了しました。返品注文番号は『' +
      orderNumber +
      '』です。この番号をお控えください。担当者が確認次第、メールにてご連絡いたします。';
  }

  private static ReturnOrderOutcome createReturnOrder(
    String orderNumber,
    String productIdentifier,
    Id productId,
    Decimal quantity,
    String returnReason,
    String returnDetailReason
  ) {
    ReturnOrderOutcome outcome = new ReturnOrderOutcome();

    if (quantity == null || quantity <= 0) {
      outcome.errorMessage = '返品数量が正しくありません。';
      return outcome;
    }

    Order orderRecord = findOrder(orderNumber);
    if (orderRecord == null) {
      outcome.errorMessage = '指定された注文が見つかりません。正しい注文番号を入力してください。';
      return outcome;
    }

    OrderItem orderItemRecord = findOrderItem(
      orderRecord.Id,
      productIdentifier,
      productId
    );
    if (orderItemRecord == null) {
      outcome.errorMessage = '指定された商品はこの注文に含まれていません。';
      return outcome;
    }

    try {
      SObject returnOrder = buildReturnOrderRecord(
        orderRecord,
        returnReason,
        outcome
      );
      if (returnOrder == null) {
        return outcome;
      }
      insert returnOrder;

      SObject returnOrderLineItem = buildReturnOrderLineItem(
        returnOrder,
        orderItemRecord,
        quantity,
        returnReason,
        returnDetailReason,
        outcome
      );
      if (returnOrderLineItem == null) {
        return outcome;
      }
      insert returnOrderLineItem;

      SObject adjustment = buildReturnOrderLineItemAdjustment(
        returnOrder,
        returnOrderLineItem
      );
      if (adjustment != null) {
        insert adjustment;
      }

      SObject tax = buildReturnOrderLineItemTax(
        returnOrder,
        returnOrderLineItem,
        orderItemRecord,
        quantity
      );
      if (tax != null) {
        insert tax;
      }

      outcome.success = true;
      outcome.returnOrderNumber = extractReturnOrderNumber(returnOrder);
      outcome.caseNumber = null;
    } catch (Exception e) {
      outcome.success = false;
      outcome.errorMessage = e != null ? e.getMessage() : null;
    }

    return outcome;
  }

  private static void setOutcomeError(
    ReturnOrderOutcome outcome,
    String message
  ) {
    if (outcome == null || !String.isBlank(outcome.errorMessage)) {
      return;
    }
    outcome.errorMessage = message;
  }

  private static Order findOrder(String orderNumber) {
    if (String.isBlank(orderNumber)) {
      return null;
    }

    List<Order> orders = [
      SELECT Id, AccountId, Pricebook2Id
      FROM Order
      WHERE OrderNumber = :orderNumber
      LIMIT 1
    ];

    return orders.isEmpty() ? null : orders[0];
  }

  private static OrderItem findOrderItem(
    Id orderId,
    String productIdentifier,
    Id productId
  ) {
    if (orderId == null) {
      return null;
    }

    if (productId != null) {
      List<OrderItem> itemsByProduct = [
        SELECT
          Id,
          Quantity,
          UnitPrice,
          PricebookEntryId,
          Product2Id,
          Product2.ProductCode,
          Product2.Name
        FROM OrderItem
        WHERE OrderId = :orderId AND Product2Id = :productId
        LIMIT 1
      ];

      if (!itemsByProduct.isEmpty()) {
        return itemsByProduct[0];
      }
    }

    if (String.isBlank(productIdentifier)) {
      return null;
    }

    List<OrderItem> items = [
      SELECT
        Id,
        Quantity,
        UnitPrice,
        PricebookEntryId,
        Product2Id,
        Product2.ProductCode,
        Product2.Name
      FROM OrderItem
      WHERE
        OrderId = :orderId AND
        (Product2.ProductCode = :productIdentifier OR
        Product2.Name = :productIdentifier)
      LIMIT 1
    ];

    return items.isEmpty() ? null : items[0];
  }

  private static SObject buildReturnOrderRecord(
    Order orderRecord,
    String returnReason,
    ReturnOrderOutcome outcome
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe().get('ReturnOrder');
    if (typeInfo == null) {
      setOutcomeError(
        outcome,
        'Return Order オブジェクトが組織で利用できません。'
      );
      return null;
    }

    Schema.DescribeSObjectResult describe = typeInfo.getDescribe();
    if (!describe.isCreateable()) {
      setOutcomeError(outcome, 'Return Order の作成権限がありません。');
      return null;
    }

    SObject record = typeInfo.newSObject();
    Map<String, Schema.SObjectField> fields = describe.fields.getMap();

    setReferenceField(record, fields, 'OrderId', orderRecord.Id);
    setReferenceField(record, fields, 'AccountId', orderRecord.AccountId);
    setReferenceField(record, fields, 'OwnerId', UserInfo.getUserId());
    setTextField(record, fields, 'ReturnReason', returnReason);

    populateRequiredDefaults(record, describe);
    return record;
  }

  private static SObject buildReturnOrderLineItem(
    SObject returnOrder,
    OrderItem orderItem,
    Decimal quantity,
    String returnReason,
    String returnDetailReason,
    ReturnOrderOutcome outcome
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe()
      .get('ReturnOrderLineItem');
    if (typeInfo == null) {
      setOutcomeError(
        outcome,
        'Return Order Line Item オブジェクトが組織で利用できません。'
      );
      return null;
    }

    Schema.DescribeSObjectResult describe = typeInfo.getDescribe();
    if (!describe.isCreateable()) {
      setOutcomeError(
        outcome,
        'Return Order Line Item の作成権限がありません。'
      );
      return null;
    }

    SObject record = typeInfo.newSObject();
    Map<String, Schema.SObjectField> fields = describe.fields.getMap();

    setReferenceField(
      record,
      fields,
      'ReturnOrderId',
      (Id) returnOrder.get('Id')
    );
    setReferenceField(record, fields, 'OrderItemId', orderItem.Id);
    setReferenceField(record, fields, 'OwnerId', UserInfo.getUserId());
    setReferenceField(record, fields, 'Product2Id', orderItem.Product2Id);
    setReferenceField(
      record,
      fields,
      'PricebookEntryId',
      orderItem.PricebookEntryId
    );

    setDecimalField(record, fields, 'Quantity', quantity);
    setDecimalField(record, fields, 'UnitPrice', orderItem.UnitPrice);
    setTextField(record, fields, 'ReasonForReturn', returnReason);
    setTextField(record, fields, 'ReturnDetailReason__c', returnDetailReason);
    setTextField(record, fields, 'ReturnStatus__c', '受付待ち');

    populateRequiredDefaults(record, describe);
    return record;
  }

  private static SObject buildReturnOrderLineItemAdjustment(
    SObject returnOrder,
    SObject returnOrderLineItem
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe()
      .get('ReturnOrderItemAdjustment');
    if (typeInfo == null) {
      return null;
    }

    Schema.DescribeSObjectResult describe = typeInfo.getDescribe();
    if (!describe.isCreateable()) {
      return null;
    }

    SObject record = typeInfo.newSObject();
    Map<String, Schema.SObjectField> fields = describe.fields.getMap();

    setReferenceField(
      record,
      fields,
      'ReturnOrderLineItemId',
      (Id) returnOrderLineItem.get('Id')
    );

    setReferenceField(
      record,
      fields,
      'ReturnOrderId',
      (Id) returnOrder.get('Id')
    );

    setReferenceField(record, fields, 'OwnerId', UserInfo.getUserId());
    setDecimalField(record, fields, 'Amount', 0);

    populateRequiredDefaults(record, describe);
    return record;
  }

  private static SObject buildReturnOrderLineItemTax(
    SObject returnOrder,
    SObject returnOrderLineItem,
    OrderItem orderItem,
    Decimal quantity
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe()
      .get('ReturnOrderItemTax');
    if (typeInfo == null) {
      return null;
    }

    Schema.DescribeSObjectResult describe = typeInfo.getDescribe();
    if (!describe.isCreateable()) {
      return null;
    }

    Decimal unitPrice = orderItem.UnitPrice != null ? orderItem.UnitPrice : 0;
    Decimal totalAmount = quantity != null ? quantity * unitPrice : 0;
    Decimal taxRate = 0.1;
    Decimal taxAmount = totalAmount * taxRate;

    SObject record = typeInfo.newSObject();
    Map<String, Schema.SObjectField> fields = describe.fields.getMap();

    setReferenceField(
      record,
      fields,
      'ReturnOrderLineItemId',
      (Id) returnOrderLineItem.get('Id')
    );

    setReferenceField(
      record,
      fields,
      'ReturnOrderId',
      (Id) returnOrder.get('Id')
    );

    setReferenceField(record, fields, 'OwnerId', UserInfo.getUserId());
    setDecimalField(record, fields, 'TaxAmount', taxAmount);
    setDecimalField(record, fields, 'TaxRate', taxRate);

    populateRequiredDefaults(record, describe);
    return record;
  }

  private static void setReferenceField(
    SObject record,
    Map<String, Schema.SObjectField> fields,
    String fieldName,
    Id value
  ) {
    if (value == null) {
      return;
    }

    if (fields != null && fields.containsKey(fieldName)) {
      Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
      if (describe.isCreateable()) {
        record.put(fieldName, value);
      }
    }
  }

  private static void setTextField(
    SObject record,
    Map<String, Schema.SObjectField> fields,
    String fieldName,
    String value
  ) {
    if (String.isBlank(value)) {
      return;
    }

    if (fields != null && fields.containsKey(fieldName)) {
      Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
      if (describe.isCreateable()) {
        record.put(fieldName, value);
      }
    }
  }

  private static void setDecimalField(
    SObject record,
    Map<String, Schema.SObjectField> fields,
    String fieldName,
    Decimal value
  ) {
    if (value == null) {
      return;
    }

    if (fields != null && fields.containsKey(fieldName)) {
      Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
      if (describe.isCreateable()) {
        record.put(fieldName, value);
      }
    }
  }

  private static void populateRequiredDefaults(
    SObject record,
    Schema.DescribeSObjectResult describe
  ) {
    if (record == null || describe == null) {
      return;
    }

    Map<String, Schema.SObjectField> fields = describe.fields.getMap();
    for (String fieldName : fields.keySet()) {
      Schema.DescribeFieldResult fieldDescribe = fields.get(fieldName)
        .getDescribe();

      if (!fieldDescribe.isCreateable()) {
        continue;
      }

      if (record.get(fieldName) != null) {
        continue;
      }

      if (fieldDescribe.isDefaultedOnCreate() || fieldDescribe.isAutoNumber()) {
        continue;
      }

      if (!fieldDescribe.isNillable()) {
        Schema.DisplayType type = fieldDescribe.getType();
        if (type == Schema.DisplayType.Picklist) {
          String value = getFirstPicklistValue(fieldDescribe);
          if (value != null) {
            record.put(fieldName, value);
          }
        } else if (type == Schema.DisplayType.Boolean) {
          record.put(fieldName, false);
        } else if (type == Schema.DisplayType.Date) {
          record.put(fieldName, Date.today());
        } else if (type == Schema.DisplayType.Datetime) {
          record.put(fieldName, Datetime.now());
        } else if (
          type == Schema.DisplayType.Double ||
          type == Schema.DisplayType.Currency ||
          type == Schema.DisplayType.Integer ||
          type == Schema.DisplayType.Long ||
          type == Schema.DisplayType.Percent
        ) {
          record.put(fieldName, 0);
        } else if (
          type == Schema.DisplayType.String ||
          type == Schema.DisplayType.TextArea ||
          type == Schema.DisplayType.EncryptedString
        ) {
          record.put(fieldName, 'N/A');
        } else if (
          type == Schema.DisplayType.Reference && 'OwnerId'.equals(fieldName)
        ) {
          record.put(fieldName, UserInfo.getUserId());
        }
      }
    }
  }

  private static String getFirstPicklistValue(
    Schema.DescribeFieldResult fieldDescribe
  ) {
    if (fieldDescribe == null) {
      return null;
    }

    for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
      if (entry.isActive()) {
        return entry.getValue();
      }
    }

    List<Schema.PicklistEntry> values = fieldDescribe.getPicklistValues();
    return values.isEmpty() ? null : values[0].getValue();
  }

  private static String extractReturnOrderNumber(SObject returnOrder) {
    if (returnOrder == null) {
      return null;
    }

    if (
      returnOrder.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .containsKey('ReturnOrderNumber')
    ) {
      String orderNumber = (String) returnOrder.get('ReturnOrderNumber');
      if (!String.isBlank(orderNumber)) {
        return orderNumber;
      }
    }

    Id returnOrderId = (Id) returnOrder.get('Id');
    if (returnOrderId != null) {
      List<ReturnOrder> queriedReturnOrders = [
        SELECT ReturnOrderNumber 
        FROM ReturnOrder
        WHERE Id = :returnOrderId
        LIMIT 1
      ];

      if (!queriedReturnOrders.isEmpty()) {
        ReturnOrder queriedReturnOrder = queriedReturnOrders[0];
        if (!String.isBlank(queriedReturnOrder.ReturnOrderNumber)) {
          return queriedReturnOrder.ReturnOrderNumber;
        }
      }
    }

    return returnOrderId != null ? (String) returnOrderId : null;
  }
}