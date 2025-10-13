import { createElement } from 'lwc';
import { ShowToastEventName } from 'lightning/platformShowToastEvent';
import PurchaseHistory from 'c/purchaseHistory';

const sendAgentforceMessageMock = jest.fn().mockResolvedValue();

jest.mock(
    'c/agentforceChat',
    () => {
        const { LightningElement, api } = require('lwc');
        return {
            default: class AgentforceChatStub extends LightningElement {
                @api
                async sendMessage(message) {
                    return sendAgentforceMessageMock(message);
                }
            }
        };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/PurchaseHistoryController.getPurchaseHistory',
    () => ({
        default: jest.fn().mockResolvedValue([])
    }),
    { virtual: true }
);

describe('c-purchase-history', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        sendAgentforceMessageMock.mockClear();
    });

    it('opens Agentforce chat and sends the order number when the button is clicked', async () => {
        const element = createElement('c-purchase-history', {
            is: PurchaseHistory
        });
        document.body.appendChild(element);

        await Promise.resolve();

        element.orders = [
            {
                orderId: '801000000000001AAA',
                orderNumber: '00012345',
                items: [
                    {
                        orderItemId: '802000000000001AAA',
                        productName: 'テスト商品'
                    }
                ]
            }
        ];

        await Promise.resolve();

        const button = element.shadowRoot.querySelector(
            'button[data-order-item-id="802000000000001AAA"]'
        );
        expect(button).not.toBeNull();

        const handler = jest.fn();
        element.addEventListener(ShowToastEventName, handler);

        button.click();

        await Promise.resolve();
        await Promise.resolve();

        expect(sendAgentforceMessageMock).toHaveBeenCalledWith('00012345');

        const container = element.shadowRoot.querySelector('.agentforce-chat-container');
        expect(container.classList.contains('agentforce-chat-container--visible')).toBe(true);

        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail).toMatchObject({
            title: '返品・交換サポート',
            message: 'テスト商品（注文番号: 00012345）のサポートチャットを開始しました。',
            variant: 'success'
        });
    });

    it('shows an error toast when the order number is missing', async () => {
        const element = createElement('c-purchase-history', {
            is: PurchaseHistory
        });
        document.body.appendChild(element);

        await Promise.resolve();

        element.orders = [
            {
                items: [
                    {
                        productName: '商品情報なし'
                    }
                ]
            }
        ];

        await Promise.resolve();

        const button = element.shadowRoot.querySelector('button.item-action');
        expect(button).not.toBeNull();

        const handler = jest.fn();
        element.addEventListener(ShowToastEventName, handler);

        button.click();

        await Promise.resolve();

        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler.mock.calls[0][0].detail).toMatchObject({
            title: '返品・交換サポート',
            message: '注文番号を取得できませんでした。時間をおいて再度お試しください。',
            variant: 'error'
        });

        expect(sendAgentforceMessageMock).not.toHaveBeenCalled();
    });
});
