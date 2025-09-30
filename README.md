# Purchase History LWC Sample

This project contains a Salesforce Lightning Web Component (LWC) and Apex classes that expose a purchase history view for Account records. The component surfaces order line item details, including product data, and can be added to Account record pages, app pages, or the home page.

## Contents

- `force-app/main/default/classes/PurchaseHistoryController.cls`: Apex controller that aggregates purchase history information from related Order and OrderItem records.
- `force-app/main/default/classes/PurchaseHistoryControllerTest.cls`: Apex unit tests covering the purchase history controller.
- `force-app/main/default/lwc/purchaseHistory/`: Lightning Web Component that renders the purchase history data in a data table.

## Deployment

Use Salesforce CLI to deploy the metadata to your org:

```bash
sfdx force:source:deploy -p force-app/main/default
```

## Usage

1. Deploy the metadata to your Salesforce org.
2. Add the **Purchase History** component to an Account record page using the Lightning App Builder.
3. Save and activate the page.
4. Navigate to an Account record with related Orders and Order Items to see the purchase history.
