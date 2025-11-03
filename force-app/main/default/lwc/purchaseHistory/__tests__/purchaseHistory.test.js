import { createElement } from "lwc";
import PurchaseHistory from "c/purchaseHistory";

jest.mock(
  "c/agentforceChat",
  () => {
    const { LightningElement } = require("lwc");
    const initializeConversationMock = jest.fn().mockResolvedValue();
    const prefillDraftMessageMock = jest.fn();
    const focusComposerMock = jest.fn();
    const applySessionResultMock = jest.fn().mockResolvedValue();
    return {
      __esModule: true,
      initializeConversationMock,
      prefillDraftMessageMock,
      focusComposerMock,
      applySessionResultMock,
      default: class AgentforceChatStub extends LightningElement {
        initializeConversation(...args) {
          return initializeConversationMock(...args);
        }

        prefillDraftMessage(...args) {
          return prefillDraftMessageMock(...args);
        }

        focusComposer(...args) {
          return focusComposerMock(...args);
        }

        applySessionResult(...args) {
          return applySessionResultMock(...args);
        }
      }
    };
  },
  { virtual: true }
);

const {
  initializeConversationMock,
  prefillDraftMessageMock,
  focusComposerMock,
  applySessionResultMock
} = require("c/agentforceChat");

jest.mock(
  "@salesforce/apex/PurchaseHistoryController.getPurchaseHistory",
  () => ({
    default: jest.fn().mockResolvedValue([])
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AgentforceChatController.startSession",
  () => ({
    default: jest.fn().mockResolvedValue({
      sessionId: "mock-session-id",
      messagesUrl: "https://example.com/messages",
      externalSessionKey: "mock-session-key",
      data: {
        messages: [
          {
            type: "Inform",
            message: "Hello. This is NovaRigel Returns Agent.",
            id: "message-1"
          }
        ]
      }
    })
  }),
  { virtual: true }
);

const startSessionMock = require("@salesforce/apex/AgentforceChatController.startSession").default;

async function flushPromises(iterations = 1) {
  for (let index = 0; index < iterations; index += 1) {
    // eslint-disable-next-line no-await-in-loop
    await Promise.resolve();
  }
}

describe("c-purchase-history", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.restoreAllMocks();
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("opens Agentforce chat and prefills the order number when the button is clicked", async () => {
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

    await flushPromises(2);
    jest.runAllTimers();
    await flushPromises(2);
    jest.runAllTimers();
    await flushPromises(2);

    const container = element.shadowRoot.querySelector(
      ".agentforce-chat-container"
    );
    expect(
      container.classList.contains("agentforce-chat-container--visible")
    ).toBe(true);

    const chatComponent = element.shadowRoot.querySelector("c-agentforce-chat");
    expect(chatComponent).not.toBeNull();

    expect(startSessionMock).toHaveBeenCalledTimes(1);
    expect(startSessionMock).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({
          context: expect.objectContaining({ orderNumber: "00012345" })
        })
      })
    );

    expect(applySessionResultMock).toHaveBeenCalledTimes(1);
    expect(applySessionResultMock).toHaveBeenCalledWith(
      expect.objectContaining({
        sessionId: "mock-session-id",
        messagesUrl: "https://example.com/messages"
      })
    );

    expect(initializeConversationMock).toHaveBeenCalledTimes(1);
    expect(prefillDraftMessageMock).toHaveBeenCalledWith("00012345");
    expect(focusComposerMock).toHaveBeenCalled();
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

    await flushPromises(2);

    const container = element.shadowRoot.querySelector(
      ".agentforce-chat-container"
    );
    expect(
      container.classList.contains("agentforce-chat-container--visible")
    ).toBe(false);

    const chatComponent = element.shadowRoot.querySelector("c-agentforce-chat");
    expect(chatComponent).toBeNull();

    expect(startSessionMock).not.toHaveBeenCalled();
    expect(applySessionResultMock).not.toHaveBeenCalled();
  });
});
