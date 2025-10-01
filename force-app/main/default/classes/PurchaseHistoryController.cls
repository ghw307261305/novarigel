/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-01-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class PurchaseHistoryController {
    public class PurchaseHistoryItem {
        @AuraEnabled public Id orderId { get; set; }
        @AuraEnabled public String orderNumber { get; set; }
        @AuraEnabled public Date purchaseDate { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Id orderItemId { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public String productDescription { get; set; }
        // @AuraEnabled public String currencyIsoCode { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<PurchaseHistoryItem> getPurchaseHistory(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('An account Id is required to view purchase history.');
        }

        List<OrderItem> orderItems = [
            SELECT Id,
                   OrderId,
                   Order.OrderNumber,
                   Order.EffectiveDate,
                   Order.Status,
                //    Order.CurrencyIsoCode,
                   Quantity,
                   UnitPrice,
                   TotalPrice,
                   Product2.Name,
                   Product2.ProductCode,
                   Product2.Description
            FROM OrderItem
            WHERE Order.AccountId = :accountId
            ORDER BY Order.EffectiveDate DESC, Order.OrderNumber DESC
        ];

        List<PurchaseHistoryItem> results = new List<PurchaseHistoryItem>();
        for (OrderItem item : orderItems) {
            PurchaseHistoryItem historyItem = new PurchaseHistoryItem();
            historyItem.orderId = item.OrderId;
            historyItem.orderNumber = item.Order.OrderNumber;
            historyItem.purchaseDate = item.Order.EffectiveDate;
            historyItem.status = item.Order.Status;
            historyItem.orderItemId = item.Id;
            historyItem.quantity = item.Quantity;
            historyItem.unitPrice = item.UnitPrice;
            historyItem.totalPrice = item.TotalPrice;
            historyItem.productName = item.Product2 != null ? item.Product2.Name : null;
            historyItem.productCode = item.Product2 != null ? item.Product2.ProductCode : null;
            historyItem.productDescription = item.Product2 != null ? item.Product2.Description : null;
            // historyItem.currencyIsoCode = item.Order.CurrencyIsoCode;
            results.add(historyItem);
        }

        return results;
    }
}
