@IsTest
private class PurchaseHistoryControllerTest {
  @IsTest
  static void testGetPurchaseHistory() {
    Account account = new Account(Name = 'Test Account');
    insert account;

    Contact contact = new Contact(
      FirstName = 'Test',
      LastName = 'Buyer',
      AccountId = account.Id,
      Email = 'test-buyer@example.com'
    );
    insert contact;

    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];

    User buyer = new User(
      Alias = 'tbuyer',
      Email = 'test-buyer@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Buyer',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'test-buyer' + DateTime.now().getTime() + '@example.com',
      ProfileId = standardProfile.Id,
      ContactId = contact.Id
    );
    insert buyer;

    Pricebook2 standardPricebook = [
      SELECT Id
      FROM Pricebook2
      WHERE IsStandard = TRUE
      LIMIT 1
    ];

    Product2 product = new Product2(
      Name = 'Test Product',
      ProductCode = 'TP-001',
      isActive = true
    );
    insert product;

    PricebookEntry pricebookEntry = new PricebookEntry(
      Pricebook2Id = standardPricebook.Id,
      Product2Id = product.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert pricebookEntry;

    System.runAs(buyer) {
      Order orderRecord = new Order(
        AccountId = account.Id,
        BillToContactId = contact.Id,
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
      List<PurchaseHistoryController.PurchaseHistoryOrder> history = PurchaseHistoryController.getPurchaseHistory();
      Test.stopTest();

      System.assertEquals(
        1,
        history.size(),
        'A single order should be returned.'
      );

      PurchaseHistoryController.PurchaseHistoryOrder order = history[0];
      System.assertEquals(
        orderRecord.Id,
        order.orderId,
        'Order Id should match.'
      );
      System.assertEquals(
        orderRecord.OrderNumber,
        order.orderNumber,
        'Order number should match.'
      );
      System.assertEquals(
        orderRecord.EffectiveDate,
        order.purchaseDate,
        'Purchase date should match.'
      );
      System.assertEquals(
        orderRecord.Status,
        order.status,
        'Status should match.'
      );
      System.assertEquals(
        order.totalPrice,
        orderItem.TotalPrice,
        'Total price should match order item total.'
      );
      System.assertEquals(
        1,
        order.items.size(),
        'Single order item should be grouped under the order.'
      );

      PurchaseHistoryController.PurchaseHistoryItem item = order.items[0];
      System.assertEquals(
        orderRecord.Id,
        item.orderId,
        'Order Id on item should match.'
      );
      System.assertEquals(
        orderItem.Id,
        item.orderItemId,
        'Order item Id should match.'
      );
      System.assertEquals(
        product.Name,
        item.productName,
        'Product name should match.'
      );
      System.assertEquals(
        product.ProductCode,
        item.productCode,
        'Product code should match.'
      );
      System.assertEquals(
        orderItem.Quantity,
        item.quantity,
        'Quantity should match.'
      );
      System.assertEquals(
        orderItem.UnitPrice,
        item.unitPrice,
        'Unit price should match.'
      );
      System.assertEquals(
        orderItem.TotalPrice,
        item.totalPrice,
        'Total price should match.'
      );
    }
  }

  @IsTest
  static void testGetPurchaseHistoryWithoutContact() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];

    User buyerWithoutContact = new User(
      Alias = 'ncnuser',
      Email = 'no-contact@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'User',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'no-contact' + DateTime.now().getTime() + '@example.com',
      ProfileId = standardProfile.Id
    );
    insert buyerWithoutContact;

    System.runAs(buyerWithoutContact) {
      Test.startTest();
      List<PurchaseHistoryController.PurchaseHistoryOrder> history = PurchaseHistoryController.getPurchaseHistory();
      Test.stopTest();

      System.assertEquals(
        0,
        history.size(),
        'No orders should be returned for users without a contact.'
      );
    }
  }
}