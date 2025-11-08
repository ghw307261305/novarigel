/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 11-08-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class PurchaseHistoryController {
  public class PurchaseHistoryItem {
    @AuraEnabled
    public Id orderId { get; set; }
    @AuraEnabled
    public String orderNumber { get; set; }
    @AuraEnabled
    public Date purchaseDate { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Id orderItemId { get; set; }
    @AuraEnabled
    public Decimal quantity { get; set; }
    @AuraEnabled
    public Decimal unitPrice { get; set; }
    @AuraEnabled
    public Decimal totalPrice { get; set; }
    @AuraEnabled
    public String productName { get; set; }
    @AuraEnabled
    public String productCode { get; set; }
    @AuraEnabled
    public String productDescription { get; set; }
  }

  public class PurchaseHistoryOrder {
    @AuraEnabled
    public Id orderId { get; set; }
    @AuraEnabled
    public String orderNumber { get; set; }
    @AuraEnabled
    public Date purchaseDate { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public String currencyIsoCode { get; set; }
    @AuraEnabled
    public Decimal totalPrice { get; set; }
    @AuraEnabled
    public List<PurchaseHistoryItem> items { get; set; }

    public PurchaseHistoryOrder() {
      items = new List<PurchaseHistoryItem>();
      totalPrice = 0;
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<PurchaseHistoryOrder> getPurchaseHistory() {
    List<User> users = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    if (users.isEmpty() || users[0].ContactId == null) {
      return new List<PurchaseHistoryOrder>();
    }

    Id contactId = users[0].ContactId;

    List<OrderItem> orderItems = [
      SELECT
        Id,
        OrderId,
        Order.OrderNumber,
        Order.EffectiveDate,
        Order.Status,
        Order.CurrencyIsoCode,
        Quantity,
        UnitPrice,
        TotalPrice,
        Product2.Name,
        Product2.ProductCode,
        Product2.Description
      FROM OrderItem
      WHERE Order.BillToContactId = :contactId AND Order.Status = 'Activated'
      ORDER BY
        Order.EffectiveDate DESC,
        Order.OrderNumber DESC,
        CreatedDate DESC
    ];

    Map<Id, PurchaseHistoryOrder> ordersById = new Map<Id, PurchaseHistoryOrder>();
    List<Id> orderSequence = new List<Id>();

    for (OrderItem item : orderItems) {
      if (item.OrderId == null) {
        continue;
      }

      if (!ordersById.containsKey(item.OrderId)) {
        PurchaseHistoryOrder order = new PurchaseHistoryOrder();
        order.orderId = item.OrderId;
        order.orderNumber = item.Order != null ? item.Order.OrderNumber : null;
        order.purchaseDate = item.Order != null
          ? item.Order.EffectiveDate
          : null;
        order.status = item.Order != null ? item.Order.Status : null;
        order.currencyIsoCode = item.Order != null
          ? item.Order.CurrencyIsoCode
          : null;
        ordersById.put(order.orderId, order);
        orderSequence.add(order.orderId);
      }

      PurchaseHistoryOrder existingOrder = ordersById.get(item.OrderId);

      PurchaseHistoryItem historyItem = new PurchaseHistoryItem();
      historyItem.orderId = item.OrderId;
      historyItem.orderNumber = item.Order != null
        ? item.Order.OrderNumber
        : null;
      historyItem.purchaseDate = item.Order != null
        ? item.Order.EffectiveDate
        : null;
      historyItem.status = item.Order != null ? item.Order.Status : null;
      historyItem.orderItemId = item.Id;
      historyItem.quantity = item.Quantity;
      historyItem.unitPrice = item.UnitPrice;
      historyItem.totalPrice = item.TotalPrice;
      historyItem.productName = item.Product2 != null
        ? item.Product2.Name
        : null;
      historyItem.productCode = item.Product2 != null
        ? item.Product2.ProductCode
        : null;
      historyItem.productDescription = item.Product2 != null
        ? item.Product2.Description
        : null;

      existingOrder.items.add(historyItem);
      if (item.TotalPrice != null) {
        existingOrder.totalPrice += item.TotalPrice;
      }
    }

    List<PurchaseHistoryOrder> results = new List<PurchaseHistoryOrder>();
    for (Id orderId : orderSequence) {
      if (ordersById.containsKey(orderId)) {
        results.add(ordersById.get(orderId));
      }
    }

    return results;
  }
}
