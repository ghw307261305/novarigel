import { LightningElement, api, track } from 'lwc';
import getPurchaseHistory from '@salesforce/apex/PurchaseHistoryController.getPurchaseHistory';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PurchaseHistory extends LightningElement {
    @api recordId;
    @track purchaseHistory = [];
    @track error;
    isLoading = false;

    connectedCallback() {
        this.loadPurchaseHistory();
    }

    get hasData() {
        return this.purchaseHistory && this.purchaseHistory.length > 0;
    }

    get errorMessage() {
        return (
            this.error?.body?.message ||
            this.error?.message ||
            '予期せぬエラーが発生しました。'
        );
    }

    async loadPurchaseHistory() {
        if (!this.recordId) {
            this.error = {
                message: '購入履歴を表示するには取引先のレコードIDが必要です。'
            };
            return;
        }

        this.isLoading = true;
        this.error = undefined;

        try {
            const history = await getPurchaseHistory({ accountId: this.recordId });
            this.purchaseHistory =
                history?.map((item) => this.formatHistoryItem(item)) || [];
        } catch (error) {
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '購入履歴の読み込みエラー',
                    message: this.errorMessage,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    formatHistoryItem(item) {
        const dateFormatter = new Intl.DateTimeFormat('ja-JP');
        const currencyFormatter = new Intl.NumberFormat('ja-JP', {
            style: 'currency',
            currency: item.currencyIsoCode || 'JPY'
        });
        const numberFormatter = new Intl.NumberFormat('ja-JP');

        return {
            ...item,
            purchaseDateFormatted: item.purchaseDate
                ? dateFormatter.format(new Date(item.purchaseDate))
                : '',
            quantityFormatted:
                item.quantity !== undefined && item.quantity !== null
                    ? numberFormatter.format(item.quantity)
                    : '',
            unitPriceFormatted:
                item.unitPrice !== undefined && item.unitPrice !== null
                    ? currencyFormatter.format(item.unitPrice)
                    : '',
            totalPriceFormatted:
                item.totalPrice !== undefined && item.totalPrice !== null
                    ? currencyFormatter.format(item.totalPrice)
                    : ''
        };
    }
}
