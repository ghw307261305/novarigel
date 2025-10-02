import { createElement } from 'lwc';
import { ShowToastEventName } from 'lightning/platformShowToastEvent';
import PurchaseHistory from 'c/purchaseHistory';

jest.mock(
    '@salesforce/apex/PurchaseHistoryController.getPurchaseHistory',
    () => ({
        default: jest.fn().mockResolvedValue([])
    }),
    { virtual: true }
);

const launchReturnsAgentUiMock = jest.fn().mockResolvedValue({});

jest.mock(
    'c/returnsAgentLauncher',
    () => ({
        launchReturnsAgentUi: (...args) => launchReturnsAgentUiMock(...args)
    }),
    { virtual: true }
);

describe('c-purchase-history', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('launches the returns agent workspace when the button is clicked', async () => {
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

        expect(launchReturnsAgentUiMock).toHaveBeenCalledTimes(1);
        const launchArgs = launchReturnsAgentUiMock.mock.calls[0][0];
        expect(launchArgs.context).toEqual({
            orderId: '801000000000001AAA',
            orderItemId: '802000000000001AAA'
        });
        expect(typeof launchArgs.navigate).toBe('function');
        expect(handler).toHaveBeenCalled();
    });
});
