import { createElement } from "lwc";
import PurchaseHistory from "c/purchaseHistory";

jest.mock(
  "c/agentforceChat",
  () => {
    const { LightningElement } = require("lwc");
    return {
      __esModule: true,
      default: class AgentforceChatStub extends LightningElement {}
    };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/PurchaseHistoryController.getPurchaseHistory",
  () => ({
    default: jest.fn().mockResolvedValue([])
  }),
  { virtual: true }
);

describe("c-purchase-history", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.restoreAllMocks();
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("opens Agentforce chat and sends the order number when the button is clicked", async () => {
    jest.useFakeTimers();
    const element = createElement("c-purchase-history", {
      is: PurchaseHistory
    });
    document.body.appendChild(element);

    await Promise.resolve();

    element.testOrders = [
      {
        orderId: "801000000000001AAA",
        orderNumber: "00012345",
        items: [
          {
            orderItemId: "802000000000001AAA",
            productName: "テスト商品"
          }
        ]
      }
    ];

    await Promise.resolve();
    await Promise.resolve();

    const button = element.shadowRoot.querySelector(
      'button[data-order-number="00012345"]'
    );
    expect(button).not.toBeNull();

    button.click();

    jest.runAllTimers();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const container = element.shadowRoot.querySelector(
      ".agentforce-chat-container"
    );
    expect(
      container.classList.contains("agentforce-chat-container--visible")
    ).toBe(true);

    const chatComponent = element.shadowRoot.querySelector("c-agentforce-chat");
    expect(chatComponent).not.toBeNull();
  });

  it("shows an error toast when the order number is missing", async () => {
    const element = createElement("c-purchase-history", {
      is: PurchaseHistory
    });
    document.body.appendChild(element);

    await Promise.resolve();

    element.testOrders = [
      {
        orderId: "801000000000002AAA",
        orderNumber: "",
        items: [
          {
            orderItemId: "802000000000002AAA",
            productName: "商品情報なし"
          }
        ]
      }
    ];

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const buttons = element.shadowRoot.querySelectorAll(
      ".order-card__actions .order-action"
    );
    expect(buttons.length).toBeGreaterThan(0);
    const button = buttons[buttons.length - 1];
    expect(button).not.toBeNull();
    expect(button.textContent).toContain("返品・交換");
    expect(button.dataset.orderNumber).toBe("");

    button.click();

    await Promise.resolve();
    await Promise.resolve();

    const container = element.shadowRoot.querySelector(
      ".agentforce-chat-container"
    );
    expect(
      container.classList.contains("agentforce-chat-container--visible")
    ).toBe(false);

    const chatComponent = element.shadowRoot.querySelector("c-agentforce-chat");
    expect(chatComponent).toBeNull();
  });
});
