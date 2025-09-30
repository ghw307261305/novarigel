@IsTest
private class PurchaseHistoryControllerTest {
    @IsTest
    static void testGetPurchaseHistory() {
        Account account = new Account(Name = 'Test Account');
        insert account;

        Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

        Product2 product = new Product2(Name = 'Test Product', ProductCode = 'TP-001', isActive = true);
        insert product;

        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = product.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pricebookEntry;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebook.Id
        );
        insert orderRecord;

        OrderItem orderItem = new OrderItem(
            OrderId = orderRecord.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert orderItem;

        Test.startTest();
        List<PurchaseHistoryController.PurchaseHistoryItem> history = PurchaseHistoryController.getPurchaseHistory(account.Id);
        Test.stopTest();

        System.assertEquals(1, history.size(), 'A single order item should be returned.');
        PurchaseHistoryController.PurchaseHistoryItem item = history[0];
        System.assertEquals(orderRecord.Id, item.orderId, 'Order Id should match.');
        System.assertEquals(orderItem.Id, item.orderItemId, 'Order item Id should match.');
        System.assertEquals(product.Name, item.productName, 'Product name should match.');
        System.assertEquals(product.ProductCode, item.productCode, 'Product code should match.');
        System.assertEquals(orderItem.Quantity, item.quantity, 'Quantity should match.');
        System.assertEquals(orderItem.UnitPrice, item.unitPrice, 'Unit price should match.');
        System.assertEquals(orderItem.TotalPrice, item.totalPrice, 'Total price should match.');
    }

    @IsTest
    static void testGetPurchaseHistoryRequiresAccountId() {
        Test.startTest();
        try {
            PurchaseHistoryController.getPurchaseHistory(null);
            System.assert(false, 'Method should throw an error when account Id is not provided.');
        } catch (AuraHandledException e) {
            System.assertEquals('An account Id is required to view purchase history.', e.getMessage());
        }
        Test.stopTest();
    }
}
