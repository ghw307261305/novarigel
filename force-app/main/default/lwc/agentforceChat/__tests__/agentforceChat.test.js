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

const flushPromises = () =>
    Promise.resolve().then(
        () =>
            new Promise((resolve) => {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(resolve, 0);
            })
    );

const DEFAULT_START_SESSION_NOTICE = `こんにちは。NovaRigel返品エージェントです。
ご購入商品の返品や交換に関するご相談をサポートいたします。
注文番号をお持ちの場合は、まず注文番号を入力してください。`;

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

        await flushPromises();

        mockStartSession.mockResolvedValue({
            sessionId: 'session-123',
            messagesUrl: 'https://example.com/api/sessions/session-123/messages',
            externalSessionKey: 'abc'
        });
        mockSendMessage.mockResolvedValue({
            messages: [
                {
                    type: 'Inform',
                    message: 'Hello from Agentforce'
                }
            ]
        });

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

        const startSessionCall = mockStartSession.mock.calls[0][0];
        expect(startSessionCall.payload).toEqual(
            expect.objectContaining({
                sessionConfig: expect.objectContaining({
                    forceConfig: expect.objectContaining({
                        endpoint: expect.any(String)
                    }),
                    featureSupport: 'Streaming',
                    streamingCapabilities: expect.objectContaining({
                        chunkTypes: ['Text']
                    })
                })
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

        const agentMessages = Array.from(
            element.shadowRoot.querySelectorAll('div[data-role="agent"] .message-body')
        ).map((node) => node.textContent);

        expect(agentMessages[0]).toBe(DEFAULT_START_SESSION_NOTICE);
        expect(agentMessages[agentMessages.length - 1]).toBe('Hello from Agentforce');
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

        await flushPromises();

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

        const statusBubble = element.shadowRoot.querySelector('.message.status .message-body');
        expect(statusBubble).not.toBeNull();
        expect(statusBubble.textContent).toBe('Sending message…');

        await flushPromises();
        await flushPromises();

        expect(element.shadowRoot.querySelector('.message.status')).toBeNull();

        const agentMessages = Array.from(
            element.shadowRoot.querySelectorAll('div[data-role="agent"] .message-body')
        ).map((node) => node.textContent);

        expect(agentMessages[0]).toBe(DEFAULT_START_SESSION_NOTICE);
        expect(agentMessages).toContain('Agentforce request failed');
    });

    it('initializes the session and renders notice messages from the start session response', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        element.botId = 'bot-notice';
        document.body.appendChild(element);

        getConfigAdapter.emit({
            startSessionEndpointUrl: 'https://example.com/sessions',
            messagesEndpointUrl: 'https://example.com/messages',
            botId: 'bot-notice'
        });

        await flushPromises();

        mockStartSession.mockResolvedValueOnce({
            sessionId: 'session-notice',
            messagesUrl: 'https://example.com/messages/session-notice',
            data: {
                session: {
                    noticeMessages: [
                        '返品・交換サポートへようこそ。',
                        { message: '注文番号を入力してください。', type: 'notice' }
                    ]
                }
            }
        });

        await flushPromises();

        await element.initializeConversation();
        await flushPromises();

        expect(mockStartSession).toHaveBeenCalledTimes(1);

        const agentMessages = Array.from(
            element.shadowRoot.querySelectorAll('div[data-role="agent"] .message-body')
        ).map((node) => node.textContent);

        expect(agentMessages[0]).toBe(DEFAULT_START_SESSION_NOTICE);
        expect(agentMessages).toContain('返品・交換サポートへようこそ。');
        expect(agentMessages).toContain('注文番号を入力してください。');
    });

    it('adds the default notice message when no initial messages are returned', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        element.botId = 'bot-empty';
        document.body.appendChild(element);

        getConfigAdapter.emit({
            startSessionEndpointUrl: 'https://example.com/sessions',
            messagesEndpointUrl: 'https://example.com/messages',
            botId: 'bot-empty'
        });

        mockStartSession.mockResolvedValueOnce({
            sessionId: 'session-empty',
            messagesUrl: 'https://example.com/messages/session-empty'
        });

        await flushPromises();

        await element.initializeConversation();
        await flushPromises();

        const agentMessages = Array.from(
            element.shadowRoot.querySelectorAll('div[data-role="agent"] .message-body')
        ).map((node) => node.textContent);

        expect(agentMessages).toHaveLength(1);
        expect(agentMessages[0]).toBe(DEFAULT_START_SESSION_NOTICE);
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

        await flushPromises();

        mockStartSession.mockResolvedValue({
            sessionId: 'session-789'
        });
        mockSendMessage.mockResolvedValue({
            messages: [
                {
                    type: 'Inform',
                    message: 'Reply'
                }
            ]
        });

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

        await flushPromises();

        mockStartSession.mockResolvedValue({
            sessionId: 'session-456'
        });
        mockSendMessage.mockResolvedValue({
            messages: [
                {
                    type: 'Inform',
                    message: 'Reply'
                }
            ]
        });

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

    it('allows programmatic sends through the public sendMessage API', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        element.endpointUrl = 'https://example.com/api';
        element.botId = 'bot-456';
        document.body.appendChild(element);

        getConfigAdapter.emit({
            startSessionEndpointUrl: 'https://default.example.com/sessions',
            messagesEndpointUrl: 'https://default.example.com',
            botId: 'default-bot'
        });

        await flushPromises();

        mockStartSession.mockResolvedValue({
            sessionId: 'session-999',
            messagesUrl: 'https://example.com/api/sessions/session-999/messages'
        });

        mockSendMessage.mockResolvedValue({
            messages: [
                {
                    type: 'Inform',
                    message: 'Acknowledged'
                }
            ]
        });

        await flushPromises();

        await element.sendMessage('Order 42');

        expect(mockStartSession).toHaveBeenCalledTimes(1);
        expect(mockSendMessage).toHaveBeenCalledWith(
            expect.objectContaining({
                message: 'Order 42',
                sessionId: 'session-999',
                endpointUrl: 'https://example.com/api/sessions/session-999/messages'
            })
        );

        const agentMessages = Array.from(
            element.shadowRoot.querySelectorAll('div[data-role="agent"] .message-body')
        ).map((node) => node.textContent);

        expect(agentMessages[0]).toBe(DEFAULT_START_SESSION_NOTICE);
        expect(agentMessages[agentMessages.length - 1]).toBe('Acknowledged');
    });

    it('prefills the composer when prefillDraftMessage is invoked', async () => {
        const element = createElement('c-agentforce-chat', {
            is: AgentforceChat
        });
        document.body.appendChild(element);

        element.prefillDraftMessage('00099999');

        await flushPromises();

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        expect(textarea.value).toBe('00099999');
    });
});
