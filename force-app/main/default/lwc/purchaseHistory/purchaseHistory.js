import { LightningElement, api } from "lwc";
import getPurchaseHistory from "@salesforce/apex/PurchaseHistoryController.getPurchaseHistory";
import startAgentforceSession from "@salesforce/apex/AgentforceChatController.startSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class PurchaseHistory extends LightningElement {
  orders = [];
  error;
  isLoading = false;
  isAgentforceChatVisible = false;
  isAgentforceChatStarting = false;
  isAgentforceChatSessionReady = false;
  agentforceSessionResult;

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
    return `agentforce-chat-container${this.isAgentforceChatVisible ? " agentforce-chat-container--visible" : ""
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
    this.isLoading = true;
    this.error = undefined;
    this.orders = [];

    try {
      const history = await getPurchaseHistory();
      this.orders = this.normalizeOrders(history || []);
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

    try {
      await this.startAgentforceChat(orderNumber);

      this.dispatchEvent(
        new ShowToastEvent({
          title: "返品・交換サポート",
          message: `注文番号: ${orderNumber}のサポートチャットを開始しました。`,
          variant: "success"
        })
      );
    } catch (error) {
      const message = this.extractErrorMessage(
        error,
        "サポートチャットの開始に失敗しました。時間をおいて再度お試しください。"
      );

      this.dispatchEvent(
        new ShowToastEvent({
          title: "返品・交換サポート",
          message,
          variant: "error"
        })
      );
    }
  }

  async startAgentforceChat(orderNumber) {
    this.isAgentforceChatVisible = true;
    this.isAgentforceChatStarting = true;
    this.isAgentforceChatSessionReady = false;
    this.agentforceSessionResult = undefined;

    try {
      const sessionResult = await this.requestAgentforceSession(orderNumber);
      this.agentforceSessionResult = sessionResult;

      if (!this.isAgentforceChatSessionReady) {
        await this.delay(this.chatLaunchDelay);
        this.isAgentforceChatSessionReady = true;
      }

      await this.waitForRender();
      await this.prepareAgentforceChat(orderNumber);
    } catch (error) {
      this.isAgentforceChatVisible = false;
      this.agentforceSessionResult = undefined;
      throw error;
    } finally {
      this.isAgentforceChatStarting = false;
      await this.waitForRender();
    }
  }

  async requestAgentforceSession(orderNumber) {
    // const payload = this.buildAgentforceSessionPayload(orderNumber);
    const payload = null;
    const result = await startAgentforceSession({ payload });
    return this.normalizeAgentforceSessionResult(result);
  }

  buildAgentforceSessionPayload(orderNumber) {
    const payload = {};
    const normalizedOrderNumber = this.normalizeOrderNumber(orderNumber);

    if (normalizedOrderNumber) {
      payload.context = {
        orderNumber: normalizedOrderNumber
      };
    }

    return payload;
  }

  normalizeAgentforceSessionResult(result) {
    if (!result) {
      return undefined;
    }

    const normalized = this.cloneSerializable(result);

    if (normalized && normalized.data && typeof normalized.data !== "object") {
      normalized.data = this.parseJsonSafely(normalized.data);
    }

    if (!normalized?.data && typeof normalized?.body === "string") {
      const parsed = this.parseJsonSafely(normalized.body);
      if (parsed && typeof parsed === "object") {
        normalized.data = parsed;
      }
    }

    return normalized;
  }

  cloneSerializable(value) {
    if (value === null || value === undefined) {
      return value;
    }

    if (typeof structuredClone === "function") {
      try {
        return structuredClone(value);
      } catch {
        // Ignore structured clone errors and fall back to other strategies.
      }
    }

    if (
      typeof window !== "undefined" &&
      typeof window.structuredClone === "function"
    ) {
      try {
        return window.structuredClone(value);
      } catch {
        // Ignore structured clone errors and fall back to JSON parsing.
      }
    }

    try {
      return JSON.parse(JSON.stringify(value));
    } catch {
      return value;
    }
  }

  parseJsonSafely(value) {
    if (!value || typeof value !== "string") {
      return undefined;
    }

    try {
      return JSON.parse(value);
    } catch {
      return undefined;
    }
  }

  extractErrorMessage(error, fallbackMessage) {
    if (!error) {
      return fallbackMessage;
    }

    if (typeof error === "string" && error.trim()) {
      return error.trim();
    }

    if (error.body) {
      if (typeof error.body === "string" && error.body.trim()) {
        return error.body.trim();
      }

      if (typeof error.body.message === "string" && error.body.message.trim()) {
        return error.body.message.trim();
      }
    }

    if (typeof error.message === "string" && error.message.trim()) {
      return error.message.trim();
    }

    return fallbackMessage;
  }

  normalizeOrderNumber(orderNumber) {
    if (orderNumber === null || orderNumber === undefined) {
      return "";
    }

    const value = String(orderNumber).trim();
    return "注文番号は「" + value + "」です";
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

  async prepareAgentforceChat(orderNumber) {
    const chat = this.template.querySelector("c-agentforce-chat");
    if (!chat) {
      return;
    }

    try {
      let applySessionResultFn =
        typeof chat.applySessionResult === "function"
          ? chat.applySessionResult.bind(chat)
          : null;

      if (!applySessionResultFn) {
        await Promise.resolve();
        if (typeof chat.applySessionResult === "function") {
          applySessionResultFn = chat.applySessionResult.bind(chat);
        }
      }

      if (this.agentforceSessionResult && applySessionResultFn) {
        await applySessionResultFn(this.agentforceSessionResult);
      }

      if (typeof chat.initializeConversation === "function") {
        await chat.initializeConversation();
      }
    } catch (error) {
      console.error("Failed to initialize Agentforce chat session", error);
    }

    const normalizedOrderNumber = this.normalizeOrderNumber(orderNumber);

    try {
      if (typeof chat.prefillDraftMessage === "function") {
        chat.prefillDraftMessage(normalizedOrderNumber);
      } else if ("draftMessage" in chat) {
        chat.draftMessage = normalizedOrderNumber;
      }

      if (typeof chat.focusComposer === "function") {
        chat.focusComposer();
      }
    } catch (error) {
      console.error("Failed to prepare Agentforce chat composer", error);
    }
  }

  handleAgentforceChatClose() {
    this.isAgentforceChatVisible = false;
    this.isAgentforceChatStarting = false;
    this.isAgentforceChatSessionReady = false;
    this.agentforceSessionResult = undefined;
  }

  normalizeOrders(orders) {
    if (!Array.isArray(orders) || orders.length === 0) {
      return [];
    }

    return orders
      .filter((order) => order && order.orderId)
      .map((order) => {
        const currencyIsoCode = order.currencyIsoCode || "JPY";
        const items = Array.isArray(order.items) ? order.items : [];
        let itemCount = 0;
        let computedTotalPrice = 0;

        const normalizedItems = items.map((item) => {
          const hasQuantity =
            item?.quantity !== null && item?.quantity !== undefined;
          const quantity = hasQuantity
            ? this.getNumericValue(item.quantity)
            : null;
          const unitPrice = this.getNumericValue(item.unitPrice);
          const lineTotalPrice = this.getNumericValue(item.totalPrice);
          const quantityForCount = hasQuantity && quantity > 0 ? quantity : 1;
          itemCount += quantityForCount;
          computedTotalPrice += lineTotalPrice;

          return {
            orderItemId: item.orderItemId,
            productName: item.productName || "商品名未設定",
            productCode: item.productCode,
            productDescription: this.formatDescription(item.productDescription),
            quantityFormatted: hasQuantity ? this.formatNumber(quantity) : "",
            unitPriceFormatted: this.formatCurrency(unitPrice, currencyIsoCode),
            totalPriceFormatted: this.formatCurrency(
              lineTotalPrice,
              currencyIsoCode
            ),
            initial: this.getInitial(item.productName)
          };
        });

        const providedTotalPrice = this.getNumericValue(order.totalPrice);
        const totalPrice =
          providedTotalPrice > 0 ? providedTotalPrice : computedTotalPrice;

        return {
          orderId: order.orderId,
          orderNumber: order.orderNumber,
          purchaseDate: order.purchaseDate,
          status: order.status,
          currencyIsoCode,
          totalPrice,
          items: normalizedItems,
          itemCount,
          purchaseDateFormatted: this.formatDate(order.purchaseDate),
          totalPriceFormatted: this.formatCurrency(totalPrice, currencyIsoCode),
          statusText: order.status || "不明",
          itemCountText: this.formatItemCount(itemCount)
        };
      });
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
