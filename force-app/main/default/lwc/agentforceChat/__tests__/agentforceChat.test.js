import { createElement } from 'lwc';
import AgentforceChat from 'c/agentforceChat';
import { registerApexTestWireAdapter } from '@salesforce/wire-service-jest-util';

const mockGetConfig = jest.fn();
const mockStartSession = jest.fn();
const mockSendMessage = jest.fn();

jest.mock(
    '@salesforce/apex/AgentforceChatController.getConfig',
    () => ({
        default: mockGetConfig
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/AgentforceChatController.startSession',
    () => ({
        default: mockStartSession
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/AgentforceChatController.sendMessage',
    () => ({
        default: mockSendMessage
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/user/Id',
    () => ({
        default: '005000000000001'
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/i18n/locale',
    () => ({
        default: 'en_US'
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/i18n/timeZone',
    () => ({
        default: 'America/Los_Angeles'
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

        getConfigAdapter.emit({
            startSessionEndpointUrl: 'https://default.example.com/sessions',
            messagesEndpointUrl: 'https://default.example.com',
            botId: 'default-bot'
        });

        mockStartSession.mockResolvedValue({
            sessionId: 'session-123',
            messagesUrl: 'https://example.com/api/sessions/session-123/messages',
            externalSessionKey: 'abc'
        });
        mockSendMessage.mockResolvedValue({ message: 'Hello from Agentforce' });

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Hi there';
        textarea.dispatchEvent(new CustomEvent('change'));

        const button = element.shadowRoot.querySelector('lightning-button');
        button.click();

        await flushPromises();
        await flushPromises();

        expect(mockStartSession).toHaveBeenCalledWith(
            expect.objectContaining({
                endpointUrl: 'https://example.com/api'
            })
        );

        expect(mockSendMessage).toHaveBeenCalledWith(
            expect.objectContaining({
                message: 'Hi there',
                endpointUrl: 'https://example.com/api/sessions/session-123/messages',
                botId: 'bot-123',
                sessionId: 'session-123'
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

        getConfigAdapter.emit({
            startSessionEndpointUrl: 'https://default.example.com/sessions',
            messagesEndpointUrl: 'https://default.example.com',
            botId: 'default-bot'
        });

        mockStartSession.mockResolvedValue({
            sessionId: 'session-123',
            messagesUrl: 'https://example.com/api/sessions/session-123/messages'
        });
        mockSendMessage.mockRejectedValue({
            body: { message: 'Agentforce request failed' }
        });

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Hi there';
        textarea.dispatchEvent(new CustomEvent('change'));

        const button = element.shadowRoot.querySelector('lightning-button');
        button.click();

        await flushPromises();
        await flushPromises();

        const statusText = element.shadowRoot.querySelector('[data-id="status"] .status-text');
        expect(statusText.textContent).toContain('Unable to send message');
        expect(statusText.textContent).toContain('Agentforce request failed');

        const agentMessage = element.shadowRoot.querySelector('div[data-role="agent"] .message-body');
        expect(agentMessage.textContent).toBe('Agentforce request failed');
    });

    it('builds the messages endpoint from configured metadata when the session response omits URLs', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        element.botId = 'bot-123';
        document.body.appendChild(element);

        getConfigAdapter.emit({
            startSessionEndpointUrl:
                'https://api.salesforce.com/einstein/ai-agent/v1/agents/{0}/sessions',
            messagesEndpointUrl:
                'https://api.salesforce.com/einstein/ai-agent/v1/sessions/{0}/messages',
            botId: 'bot-123'
        });

        mockStartSession.mockResolvedValue({
            sessionId: 'session-789'
        });
        mockSendMessage.mockResolvedValue({ message: 'Reply' });

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Hi there';
        textarea.dispatchEvent(new CustomEvent('change'));

        const button = element.shadowRoot.querySelector('lightning-button');
        button.click();

        await flushPromises();
        await flushPromises();

        expect(mockStartSession).toHaveBeenCalledWith(
            expect.objectContaining({
                endpointUrl:
                    'https://api.salesforce.com/einstein/ai-agent/v1/agents/bot-123/sessions'
            })
        );

        expect(mockSendMessage).toHaveBeenCalledWith(
            expect.objectContaining({
                endpointUrl:
                    'https://api.salesforce.com/einstein/ai-agent/v1/sessions/session-789/messages',
                sessionId: 'session-789'
            })
        );
    });

    it('applies placeholder substitution when the component overrides the start session endpoint', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        element.startSessionEndpointUrl =
            'https://example.com/agents/{0}/sessions';
        element.messagesEndpointUrl =
            'https://example.com/sessions/{0}/messages';
        element.botId = 'override-bot';
        document.body.appendChild(element);

        getConfigAdapter.emit({
            startSessionEndpointUrl: null,
            messagesEndpointUrl: null,
            botId: 'ignored-bot'
        });

        mockStartSession.mockResolvedValue({
            sessionId: 'session-456'
        });
        mockSendMessage.mockResolvedValue({ message: 'Reply' });

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Hi there';
        textarea.dispatchEvent(new CustomEvent('change'));

        const button = element.shadowRoot.querySelector('lightning-button');
        button.click();

        await flushPromises();
        await flushPromises();

        expect(mockStartSession).toHaveBeenCalledWith(
            expect.objectContaining({
                endpointUrl: 'https://example.com/agents/override-bot/sessions'
            })
        );
        expect(mockSendMessage).toHaveBeenCalledWith(
            expect.objectContaining({
                endpointUrl: 'https://example.com/sessions/session-456/messages',
                sessionId: 'session-456'
            })
        );
    });
});
