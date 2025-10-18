import { LightningElement, api } from "lwc";
import getPurchaseHistory from "@salesforce/apex/PurchaseHistoryController.getPurchaseHistory";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class PurchaseHistory extends LightningElement {
  @api recordId = "001gK00000NYz8gQAD";
  orders = [];
  error;
  isLoading = false;
  isAgentforceChatVisible = false;
  isAgentforceChatStarting = false;
  isAgentforceChatSessionReady = false;

  @api
  set testOrders(value) {
    this.orders = Array.isArray(value) ? [...value] : [];
  }

  get testOrders() {
    return this.orders;
  }

  connectedCallback() {
    this.loadPurchaseHistory();
  }

  get hasData() {
    return this.orders && this.orders.length > 0;
  }

  get agentforceChatContainerClass() {
    return `agentforce-chat-container${
      this.isAgentforceChatVisible ? " agentforce-chat-container--visible" : ""
    }`;
  }

  get agentforceChatAriaHidden() {
    return this.isAgentforceChatVisible ? "false" : "true";
  }

  get errorMessage() {
    return (
      this.error?.body?.message ||
      this.error?.message ||
      "予期せぬエラーが発生しました。"
    );
  }

  async loadPurchaseHistory() {
    if (!this.recordId) {
      this.error = {
        message: "購入履歴を表示するには取引先のレコードIDが必要です。"
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
          title: "購入履歴の読み込みエラー",
          message: this.errorMessage,
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleReturnExchange(event) {
    const button = event.currentTarget;
    const { orderNumber } = button.dataset;

    if (!orderNumber) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "返品・交換サポート",
          message:
            "注文番号を取得できませんでした。時間をおいて再度お試しください。",
          variant: "error"
        })
      );
      return;
    }

    await this.startAgentforceChat(orderNumber);

    this.dispatchEvent(
      new ShowToastEvent({
        title: "返品・交換サポート",
        message: `注文番号: ${orderNumber}のサポートチャットを開始しました。`,
        variant: "success"
      })
    );
  }

  async startAgentforceChat(orderNumber) {
    this.isAgentforceChatVisible = true;
    this.isAgentforceChatStarting = true;

    try {
      if (!this.isAgentforceChatSessionReady) {
        await this.delay(this.chatLaunchDelay);
        this.isAgentforceChatSessionReady = true;
        await this.waitForRender();
      }

      await this.sendOrderNumberToAgentforceChat(orderNumber);
    } finally {
      this.isAgentforceChatStarting = false;
      await this.waitForRender();
    }
  }

  get chatLaunchDelay() {
    return 450;
  }

  delay(duration) {
    return new Promise((resolve) => {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(resolve, duration);
    });
  }

  waitForRender() {
    return new Promise((resolve) => {
      if (typeof requestAnimationFrame === "function") {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => resolve());
      } else {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(resolve, 0);
      }
    });
  }

  async sendOrderNumberToAgentforceChat(orderNumber) {
    if (!orderNumber) {
      return;
    }

    try {
      const chat = this.template.querySelector("c-agentforce-chat");
      if (chat && typeof chat.sendMessage === "function") {
        await chat.sendMessage(orderNumber);
      }
    } catch (error) {
      console.error("Failed to send message to Agentforce chat", error);
    }
  }

  handleAgentforceChatClose() {
    this.isAgentforceChatVisible = false;
    this.isAgentforceChatStarting = false;
    this.isAgentforceChatSessionReady = false;
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
          currencyIsoCode: item.currencyIsoCode || "JPY",
          totalPrice: 0,
          items: [],
          itemCount: 0
        });
      }

      const order = ordersById.get(orderId);
      const hasQuantity = item.quantity !== null && item.quantity !== undefined;
      const quantity = hasQuantity ? this.getNumericValue(item.quantity) : null;
      const unitPrice = this.getNumericValue(item.unitPrice);
      const totalPrice = this.getNumericValue(item.totalPrice);

      order.items.push({
        orderItemId: item.orderItemId,
        productName: item.productName || "商品名未設定",
        productCode: item.productCode,
        productDescription: this.formatDescription(item.productDescription),
        quantityFormatted: hasQuantity ? this.formatNumber(quantity) : "",
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
      const quantityForCount = hasQuantity && quantity > 0 ? quantity : 1;
      order.itemCount += quantityForCount;
    });

    return Array.from(ordersById.values()).map((order) => ({
      ...order,
      purchaseDateFormatted: this.formatDate(order.purchaseDate),
      totalPriceFormatted: this.formatCurrency(
        order.totalPrice,
        order.currencyIsoCode
      ),
      statusText: order.status || "不明",
      itemCountText: this.formatItemCount(order.itemCount)
    }));
  }

  formatDate(value) {
    if (!value) {
      return "";
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return "";
    }

    return new Intl.DateTimeFormat("ja-JP", {
      year: "numeric",
      month: "long",
      day: "numeric"
    }).format(date);
  }

  formatCurrency(value, currencyIsoCode = "JPY") {
    if (value === null || value === undefined || Number.isNaN(value)) {
      return "";
    }

    return new Intl.NumberFormat("ja-JP", {
      style: "currency",
      currency: currencyIsoCode
    }).format(value);
  }

  formatNumber(value) {
    if (value === null || value === undefined || Number.isNaN(value)) {
      return "";
    }

    return new Intl.NumberFormat("ja-JP").format(value);
  }

  formatDescription(description) {
    if (!description) {
      return "この商品の詳細情報は登録されていません。";
    }

    const trimmed = description.trim();
    if (!trimmed) {
      return "この商品の詳細情報は登録されていません。";
    }

    return trimmed.length > 120 ? `${trimmed.substring(0, 120)}…` : trimmed;
  }

  getInitial(name) {
    if (!name) {
      return "商";
    }

    const trimmed = name.trim();
    return trimmed ? trimmed.charAt(0) : "商";
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
      return "商品は含まれていません";
    }

    if (value === 1) {
      return "商品数: 1点";
    }

    return `商品数: ${this.formatNumber(value)}点`;
  }
}
