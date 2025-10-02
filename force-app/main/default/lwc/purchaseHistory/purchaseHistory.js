import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPurchaseHistory from '@salesforce/apex/PurchaseHistoryController.getPurchaseHistory';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { launchReturnsAgentUi } from 'c/returnsAgentLauncher';

export default class PurchaseHistory extends NavigationMixin(LightningElement) {
    @api recordId = '001gK00000KKvNCQA1';
    orders = [];
    error;
    isLoading = false;
    isLaunchingAgent = false;

    connectedCallback() {
        this.loadPurchaseHistory();
    }

    get hasData() {
        return this.orders && this.orders.length > 0;
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
        this.orders = [];

        try {
            const history = await getPurchaseHistory({ accountId: this.recordId });
            this.orders = this.groupHistoryByOrder(history || []);
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

    async handleReturnExchange(event) {
        const button = event.currentTarget;
        const { orderId, orderItemId, orderNumber, productName } = button.dataset;
        const contextLabel =
            productName && orderNumber
                ? `${productName}（注文番号: ${orderNumber}）`
                : productName || (orderNumber ? `注文番号: ${orderNumber}` : '商品');

        this.isLaunchingAgent = true;

        try {
            await launchReturnsAgentUi({
                context: { orderId, orderItemId },
                navigate: (pageReference) => this[NavigationMixin.Navigate](pageReference)
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: '返品・交換サポート',
                    message: `${contextLabel}の返品・交換サポートを開始しました。`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '返品・交換サポートの起動に失敗しました',
                    message: this.getErrorMessageFrom(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLaunchingAgent = false;
        }
    }

    groupHistoryByOrder(historyItems) {
        if (!Array.isArray(historyItems) || historyItems.length === 0) {
            return [];
        }

        const ordersById = new Map();

        historyItems.forEach((item) => {
            const orderId = item.orderId;
            if (!orderId) {
                return;
            }

            if (!ordersById.has(orderId)) {
                ordersById.set(orderId, {
                    orderId,
                    orderNumber: item.orderNumber,
                    purchaseDate: item.purchaseDate,
                    status: item.status,
                    currencyIsoCode: item.currencyIsoCode || 'JPY',
                    totalPrice: 0,
                    items: [],
                    itemCount: 0
                });
            }

            const order = ordersById.get(orderId);
            const hasQuantity =
                item.quantity !== null && item.quantity !== undefined;
            const quantity = hasQuantity
                ? this.getNumericValue(item.quantity)
                : null;
            const unitPrice = this.getNumericValue(item.unitPrice);
            const totalPrice = this.getNumericValue(item.totalPrice);

            order.items.push({
                orderItemId: item.orderItemId,
                productName: item.productName || '商品名未設定',
                productCode: item.productCode,
                productDescription:
                    this.formatDescription(item.productDescription),
                quantityFormatted: hasQuantity
                    ? this.formatNumber(quantity)
                    : '',
                unitPriceFormatted: this.formatCurrency(
                    unitPrice,
                    order.currencyIsoCode
                ),
                totalPriceFormatted: this.formatCurrency(
                    totalPrice,
                    order.currencyIsoCode
                ),
                initial: this.getInitial(item.productName)
            });

            order.totalPrice += totalPrice;
            const quantityForCount =
                hasQuantity && quantity > 0 ? quantity : 1;
            order.itemCount += quantityForCount;
        });

        return Array.from(ordersById.values()).map((order) => ({
            ...order,
            purchaseDateFormatted: this.formatDate(order.purchaseDate),
            totalPriceFormatted: this.formatCurrency(
                order.totalPrice,
                order.currencyIsoCode
            ),
            statusText: order.status || '不明',
            itemCountText: this.formatItemCount(order.itemCount)
        }));
    }

    formatDate(value) {
        if (!value) {
            return '';
        }

        const date = new Date(value);
        if (Number.isNaN(date.getTime())) {
            return '';
        }

        return new Intl.DateTimeFormat('ja-JP', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        }).format(date);
    }

    formatCurrency(value, currencyIsoCode = 'JPY') {
        if (value === null || value === undefined || Number.isNaN(value)) {
            return '';
        }

        return new Intl.NumberFormat('ja-JP', {
            style: 'currency',
            currency: currencyIsoCode
        }).format(value);
    }

    formatNumber(value) {
        if (value === null || value === undefined || Number.isNaN(value)) {
            return '';
        }

        return new Intl.NumberFormat('ja-JP').format(value);
    }

    formatDescription(description) {
        if (!description) {
            return 'この商品の詳細情報は登録されていません。';
        }

        const trimmed = description.trim();
        if (!trimmed) {
            return 'この商品の詳細情報は登録されていません。';
        }

        return trimmed.length > 120
            ? `${trimmed.substring(0, 120)}…`
            : trimmed;
    }

    getInitial(name) {
        if (!name) {
            return '商';
        }

        const trimmed = name.trim();
        return trimmed ? trimmed.charAt(0) : '商';
    }

    getNumericValue(value) {
        if (value === null || value === undefined) {
            return 0;
        }

        const number = Number(value);
        return Number.isNaN(number) ? 0 : number;
    }

    formatItemCount(count) {
        const value = this.getNumericValue(count);
        if (value <= 0) {
            return '商品は含まれていません';
        }

        if (value === 1) {
            return '商品数: 1点';
        }

        return `商品数: ${this.formatNumber(value)}点`;
    }

    getErrorMessageFrom(error) {
        const defaultMessage = '予期せぬエラーが発生しました。時間をおいて再度お試しください。';

        if (!error) {
            return defaultMessage;
        }

        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }

        if (typeof error.message === 'string') {
            return error.message;
        }

        return defaultMessage;
    }
}
