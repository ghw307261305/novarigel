import { LightningElement, api, track } from 'lwc';
import getPurchaseHistory from '@salesforce/apex/PurchaseHistoryController.getPurchaseHistory';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const columns = [
    { label: 'Order Number', fieldName: 'orderNumber', type: 'text', sortable: true },
    { label: 'Purchase Date', fieldName: 'purchaseDate', type: 'date-local', sortable: true },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Product Name', fieldName: 'productName', type: 'text' },
    { label: 'Product Code', fieldName: 'productCode', type: 'text' },
    { label: 'Quantity', fieldName: 'quantity', type: 'number' },
    { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency', typeAttributes: { currencyCode: { fieldName: 'currencyIsoCode' } } },
    { label: 'Total Price', fieldName: 'totalPrice', type: 'currency', typeAttributes: { currencyCode: { fieldName: 'currencyIsoCode' } } }
];

export default class PurchaseHistory extends LightningElement {
    @api recordId;
    @track purchaseHistory = [];
    @track error;
    isLoading = false;

    columns = columns;

    connectedCallback() {
        this.loadPurchaseHistory();
    }

    get hasData() {
        return this.purchaseHistory && this.purchaseHistory.length > 0;
    }

    get errorMessage() {
        return this.error?.body?.message || this.error?.message || 'An unexpected error occurred.';
    }

    async loadPurchaseHistory() {
        if (!this.recordId) {
            this.error = { message: 'The component requires an Account record Id to display purchase history.' };
            return;
        }

        this.isLoading = true;
        this.error = undefined;

        try {
            const history = await getPurchaseHistory({ accountId: this.recordId });
            this.purchaseHistory = history?.map((item) => ({
                ...item,
                purchaseDate: item.purchaseDate,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice
            })) || [];
        } catch (error) {
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading purchase history',
                    message: this.errorMessage,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}
