public with sharing class ReturnOrderProcessingService {
  public class Request {
    @AuraEnabled
    public String orderNumber;

    @AuraEnabled
    public String productCode;

    @AuraEnabled
    public Decimal quantity;

    @AuraEnabled
    public String returnReason;
  }

  public class Response {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String status;

    @AuraEnabled
    public String primaryMessage;

    @AuraEnabled
    public String secondaryMessage;

    @AuraEnabled
    public String returnOrderNumber;

    @AuraEnabled
    public String caseNumber;

    @AuraEnabled
    public ReturnEligibilityService.EvaluationResult evaluation;
  }

  private class ReturnOrderOutcome {
    Boolean success = false;
    String returnOrderNumber;
    String caseNumber;
    String errorMessage;
  }

  @AuraEnabled
  public static Response processReturn(Request request) {
    if (request == null) {
      throw new AuraHandledException(
        '返品手続きを進めるには注文情報が必要です。'
      );
    }

    String normalizedOrderNumber = request.orderNumber != null
      ? request.orderNumber.trim()
      : null;
    String normalizedProductCode = request.productCode != null
      ? request.productCode.trim()
      : null;
    String normalizedReturnReason = request.returnReason != null
      ? request.returnReason.trim()
      : null;
    Decimal quantity = request.quantity;

    validateInputs(normalizedOrderNumber, normalizedProductCode, quantity);

    ReturnEligibilityService.EvaluationResult evaluation = ReturnEligibilityService.evaluateProductReturn(
      normalizedProductCode,
      normalizedReturnReason
    );

    Response response = new Response();
    response.evaluation = evaluation;

    if (evaluation == null) {
      response.success = false;
      response.status = 'EVALUATION_FAILED';
      response.primaryMessage = '返品手続きを進めることができませんでした。お手数ですが、再度お試しください。';
      return response;
    }

    if (
      !(Boolean.TRUE.equals(evaluation.productFound) &&
      Boolean.TRUE.equals(evaluation.isReturnable) &&
      Boolean.TRUE.equals(evaluation.reasonAccepted))
    ) {
      response.success = false;
      response.status = evaluation.status;
      response.primaryMessage = evaluation.primaryMessage;
      response.secondaryMessage = evaluation.secondaryMessage;
      return response;
    }

    ReturnOrderOutcome outcome = createReturnOrder(
      normalizedOrderNumber,
      normalizedProductCode,
      quantity,
      normalizedReturnReason
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

  private static void validateInputs(
    String orderNumber,
    String productCode,
    Decimal quantity
  ) {
    if (String.isBlank(orderNumber)) {
      throw new AuraHandledException(
        '返品手続きを進めるには注文番号が必要です。'
      );
    }

    if (String.isBlank(productCode)) {
      throw new AuraHandledException(
        '返品手続きを進めるには商品コードが必要です。'
      );
    }

    if (quantity == null || quantity <= 0) {
      throw new AuraHandledException(
        '返品数量は1以上の数値を指定してください。'
      );
    }
  }

  private static String buildSuccessMessage(String returnOrderNumber) {
    String number = String.isBlank(returnOrderNumber)
      ? '不明'
      : returnOrderNumber;
    return '返品手続きが完了しました。返品注文番号は『' +
      number +
      '』です。この番号をお控えください。担当者が確認次第、メールにてご連絡いたします。';
  }

  private static ReturnOrderOutcome createReturnOrder(
    String orderNumber,
    String productCode,
    Decimal quantity,
    String returnReason
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

    OrderItem orderItemRecord = findOrderItem(orderRecord.Id, productCode);
    if (orderItemRecord == null) {
      outcome.errorMessage = '指定された商品はこの注文に含まれていません。';
      return outcome;
    }

    try {
      SObject returnOrder = buildReturnOrderRecord(orderRecord, returnReason);
      insert returnOrder;

      SObject returnOrderLineItem = buildReturnOrderLineItem(
        returnOrder,
        orderItemRecord,
        quantity,
        returnReason
      );
      insert returnOrderLineItem;

      SObject adjustment = buildReturnOrderLineItemAdjustment(
        returnOrderLineItem
      );
      if (adjustment != null) {
        insert adjustment;
      }

      SObject tax = buildReturnOrderLineItemTax(
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

  private static OrderItem findOrderItem(Id orderId, String productCode) {
    if (orderId == null || String.isBlank(productCode)) {
      return null;
    }

    List<OrderItem> items = [
      SELECT
        Id,
        Quantity,
        UnitPrice,
        PricebookEntryId,
        Product2Id,
        Product2.ProductCode
      FROM OrderItem
      WHERE OrderId = :orderId AND Product2.ProductCode = :productCode
      LIMIT 1
    ];

    return items.isEmpty() ? null : items[0];
  }

  private static SObject buildReturnOrderRecord(
    Order orderRecord,
    String returnReason
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe().get('ReturnOrder');
    if (typeInfo == null) {
      throw new AuraHandledException(
        'Return Order オブジェクトが組織で利用できません。'
      );
    }

    Schema.DescribeSObjectResult describe = typeInfo.getDescribe();
    if (!describe.isCreateable()) {
      throw new AuraHandledException('Return Order の作成権限がありません。');
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
    String returnReason
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe()
      .get('ReturnOrderLineItem');
    if (typeInfo == null) {
      throw new AuraHandledException(
        'Return Order Line Item オブジェクトが組織で利用できません。'
      );
    }

    Schema.DescribeSObjectResult describe = typeInfo.getDescribe();
    if (!describe.isCreateable()) {
      throw new AuraHandledException(
        'Return Order Line Item の作成権限がありません。'
      );
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
    setTextField(record, fields, 'ReturnReason', returnReason);

    populateRequiredDefaults(record, describe);
    return record;
  }

  private static SObject buildReturnOrderLineItemAdjustment(
    SObject returnOrderLineItem
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe()
      .get('ReturnOrderLineItemAdjustment');
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
    setReferenceField(record, fields, 'OwnerId', UserInfo.getUserId());
    setDecimalField(record, fields, 'Amount', 0);

    populateRequiredDefaults(record, describe);
    return record;
  }

  private static SObject buildReturnOrderLineItemTax(
    SObject returnOrderLineItem,
    OrderItem orderItem,
    Decimal quantity
  ) {
    Schema.SObjectType typeInfo = Schema.getGlobalDescribe()
      .get('ReturnOrderLineItemTax');
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
      String number = (String) returnOrder.get('ReturnOrderNumber');
      if (!String.isBlank(number)) {
        return number;
      }
    }

    if (
      returnOrder.getSObjectType()
        .getDescribe()
        .fields.getMap()
        .containsKey('Name')
    ) {
      String name = (String) returnOrder.get('Name');
      if (!String.isBlank(name)) {
        return name;
      }
    }

    return (String) returnOrder.get('Id');
  }
}
