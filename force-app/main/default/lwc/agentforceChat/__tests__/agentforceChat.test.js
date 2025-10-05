import { createElement } from 'lwc';
import AgentforceChat from 'c/agentforceChat';
import { registerApexTestWireAdapter } from '@salesforce/wire-service-jest-util';

const mockGetConfig = jest.fn();

jest.mock(
    '@salesforce/apex/AgentforceChatController.getConfig',
    () => ({
        default: mockGetConfig
    }),
    { virtual: true }
);

const getConfigAdapter = registerApexTestWireAdapter(mockGetConfig);

const flushPromises = () => new Promise(setImmediate);

describe('c-agentforce-chat', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders messages from the user and Agentforce after send', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        element.endpointUrl = 'https://example.com/api';
        element.botId = 'bot-123';
        document.body.appendChild(element);

        getConfigAdapter.emit({ endpointUrl: 'https://default.example.com', botId: 'default-bot' });

        global.fetch = jest.fn().mockResolvedValue({
            ok: true,
            json: () => Promise.resolve({ message: 'Hello from Agentforce' })
        });

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Hi there';
        textarea.dispatchEvent(new CustomEvent('change'));

        const button = element.shadowRoot.querySelector('lightning-button');
        button.click();

        await flushPromises();

        expect(global.fetch).toHaveBeenCalledWith(
            'https://example.com/api',
            expect.objectContaining({
                method: 'POST'
            })
        );

        const userMessage = element.shadowRoot.querySelector('div[data-role="user"] .message-body');
        expect(userMessage.textContent).toBe('Hi there');

        const agentMessage = element.shadowRoot.querySelector('div[data-role="agent"] .message-body');
        expect(agentMessage.textContent).toBe('Hello from Agentforce');
    });

    it('shows error state when the Agentforce call fails', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        element.endpointUrl = 'https://example.com/api';
        element.botId = 'bot-123';
        document.body.appendChild(element);

        getConfigAdapter.emit({ endpointUrl: 'https://default.example.com', botId: 'default-bot' });

        global.fetch = jest.fn().mockResolvedValue({
            ok: false,
            json: () => Promise.resolve({ message: 'Agentforce request failed' })
        });

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Hi there';
        textarea.dispatchEvent(new CustomEvent('change'));

        const button = element.shadowRoot.querySelector('lightning-button');
        button.click();

        await flushPromises();

        const statusText = element.shadowRoot.querySelector('[data-id="status"] .status-text');
        expect(statusText.textContent).toContain('Unable to send message');
        expect(statusText.textContent).toContain('Agentforce request failed');

        const agentMessage = element.shadowRoot.querySelector('div[data-role="agent"] .message-body');
        expect(agentMessage.textContent).toBe('Agentforce request failed');
    });
});
