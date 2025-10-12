import { LightningElement, api, wire } from 'lwc';
import getConfig from '@salesforce/apex/AgentforceChatController.getConfig';
import startSession from '@salesforce/apex/AgentforceChatController.startSession';
import sendMessage from '@salesforce/apex/AgentforceChatController.sendMessage';
import USER_ID from '@salesforce/user/Id';
import USER_LOCALE from '@salesforce/i18n/locale';
import USER_TIMEZONE from '@salesforce/i18n/timeZone';

const ROLE_LABELS = {
    user: 'You',
    agent: 'Agentforce'
};

const STATUS = {
    READY: 'Ready to chat',
    SENDING: 'Sending message…',
    ERROR: 'Unable to send message'
};

export default class AgentforceChat extends LightningElement {
    _startSessionEndpointUrl;
    _messagesEndpointUrl;
    _botId;

    @api
    get startSessionEndpointUrl() {
        return this._startSessionEndpointUrl;
    }

    set startSessionEndpointUrl(value) {
        this._startSessionEndpointUrl = value;
    }

    @api
    get endpointUrl() {
        return this.startSessionEndpointUrl;
    }

    set endpointUrl(value) {
        this.startSessionEndpointUrl = value;
    }

    @api
    get messagesEndpointUrl() {
        return this._messagesEndpointUrl;
    }

    set messagesEndpointUrl(value) {
        this._messagesEndpointUrl = value;
    }

    @api
    get botId() {
        return this._botId;
    }

    set botId(value) {
        this._botId = value;
    }

    messages = [];
    draftMessage = '';
    isLoading = false;
    errorMessage;
    sessionId;
    sessionKey;
    messagesEndpoint;
    sessionInitializationPromise;

    wiredConfig;

    @wire(getConfig)
    wiredGetConfig(value) {
        this.wiredConfig = value;
        const { data, error } = value;
        if (data) {
            this.applyConfig(data);
        } else if (error) {
            this.errorMessage = 'Configuration error';
            // eslint-disable-next-line no-console
            console.error('AgentforceChat configuration error', error);
        }
    }

    get statusMessage() {
        if (this.errorMessage) {
            return `${STATUS.ERROR}: ${this.errorMessage}`;
        }
        if (this.isLoading) {
            return STATUS.SENDING;
        }
        return STATUS.READY;
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    get isSendDisabled() {
        return !this.draftMessage || this.isLoading || !this.resolvedStartSessionEndpoint;
    }

    get resolvedBotId() {
        return this.botId || (this.wiredConfig?.data && this.wiredConfig.data.botId);
    }

    get resolvedInstanceEndpoint() {
        if (typeof window === 'undefined' || !window.location) {
            return undefined;
        }
        return window.location.origin;
    }

    get resolvedStartSessionEndpoint() {
        return (
            this.startSessionEndpointUrl ||
            (this.wiredConfig?.data &&
                (this.wiredConfig.data.startSessionEndpointUrl || this.wiredConfig.data.endpointUrl))
        );
    }

    get resolvedMessagesEndpointBase() {
        return this.messagesEndpointUrl || (this.wiredConfig?.data && this.wiredConfig.data.messagesEndpointUrl);
    }

    applyConfig(data) {
        if (!this.startSessionEndpointUrl) {
            this._startSessionEndpointUrl = data.startSessionEndpointUrl || data.endpointUrl;
        }
        if (!this.messagesEndpointUrl && data.messagesEndpointUrl) {
            this._messagesEndpointUrl = data.messagesEndpointUrl;
        }
        if (!this.botId) {
            this._botId = data.botId;
        }
    }

    handleDraftChange(event) {
        this.draftMessage = event.target.value;
    }

    async handleSend() {
        if (!this.draftMessage) {
            return;
        }

        const userMessage = this.createMessage('user', this.draftMessage);
        this.messages = [...this.messages, userMessage];
        const draft = this.draftMessage;
        this.draftMessage = '';
        this.errorMessage = undefined;
        this.isLoading = true;

        try {
            const response = await this.sendMessageToAgentforce(draft);
            const agentMessageText = response && response.message ? response.message : 'Agentforce response missing message.';
            const agentResponse = this.createMessage('agent', agentMessageText);
            this.messages = [...this.messages, agentResponse];
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            const errorMessage = this.createMessage('agent', this.errorMessage, 'error');
            this.messages = [...this.messages, errorMessage];
        } finally {
            this.isLoading = false;
        }
    }

    async sendMessageToAgentforce(content) {
        const botId = this.resolvedBotId;

        if (!botId) {
            throw new Error('Missing Agentforce configuration');
        }

        await this.ensureSession();

        if (!this.messagesEndpoint) {
            throw new Error('Missing Agentforce session endpoint');
        }

        return sendMessage({
            message: content,
            transcript: this.messages.map((message) => ({
                role: message.role,
                content: message.content,
                timestamp: message.timestamp
            })),
            endpointUrl: this.messagesEndpoint,
            botId,
            sessionId: this.sessionId
        });
    }

    async ensureSession() {
        if (this.sessionId && this.messagesEndpoint) {
            return;
        }

        if (this.sessionInitializationPromise) {
            return this.sessionInitializationPromise;
        }

        this.sessionInitializationPromise = this.initializeSession();

        try {
            await this.sessionInitializationPromise;
        } finally {
            this.sessionInitializationPromise = undefined;
        }
    }

    async initializeSession() {
        const startSessionEndpoint = this.resolvedStartSessionEndpoint;
        if (!startSessionEndpoint) {
            throw new Error('Missing Agentforce configuration');
        }

        const payload = this.buildStartSessionPayload();
        const result = await startSession({ endpointUrl: startSessionEndpoint, payload });

        const sessionId = this.extractSessionId(result);
        if (!sessionId) {
            throw new Error('Agentforce session did not return an identifier');
        }

        this.sessionId = sessionId;
        this.sessionKey = result?.externalSessionKey || payload.externalSessionKey;
        this.messagesEndpoint = this.resolveMessagesEndpoint(result, sessionId, startSessionEndpoint);
    }

    buildStartSessionPayload() {
        const sessionKey = this.sessionKey || this.generateExternalSessionKey();
        const payload = {
            externalSessionKey: sessionKey,
            instanceConfig: {
                endpoint: this.resolvedInstanceEndpoint
            },
            tz: USER_TIMEZONE || this.getBrowserTimeZone(),
            variables: [
                {
                    name: '$Context.EndUserLanguage',
                    type: 'Text',
                    value: this.normalizeLocale(USER_LOCALE)
                },
                {
                    name: '$Context.EndUser.Id',
                    type: 'Text',
                    value: USER_ID
                },
                {
                    name: '$Context.EndUser.Type',
                    type: 'Text',
                    value: 'SalesforceUser'
                }
            ],
            featureSupport: 'Streaming',
            streamingCapabilities: {
                chunkTypes: ['Text']
            }
        };
        return payload;
    }

    extractSessionId(result) {
        if (!result) {
            return undefined;
        }
        if (result.sessionId) {
            return result.sessionId;
        }
        if (result.data) {
            if (result.data.sessionId) {
                return result.data.sessionId;
            }
            if (result.data.id) {
                return result.data.id;
            }
            if (result.data.session && typeof result.data.session === 'object') {
                const session = result.data.session;
                if (session.sessionId) {
                    return session.sessionId;
                }
                if (session.id) {
                    return session.id;
                }
            }
        }
        return undefined;
    }

    resolveMessagesEndpoint(result, sessionId, startEndpoint) {
        if (result?.messagesUrl) {
            return result.messagesUrl;
        }
        if (result?.sessionUrl) {
            return this.appendPath(result.sessionUrl, 'messages');
        }
        if (result?.data?.messagesUrl) {
            return result.data.messagesUrl;
        }
        if (result?.data?.session && typeof result.data.session === 'object') {
            const session = result.data.session;
            if (session.messagesUrl) {
                return session.messagesUrl;
            }
            if (session.sessionUrl) {
                return this.appendPath(session.sessionUrl, 'messages');
            }
            if (session.url) {
                return this.appendPath(session.url, 'messages');
            }
        }

        const configuredBase = this.resolvedMessagesEndpointBase;
        const fallbackBase = configuredBase || startEndpoint;
        return this.buildMessagesEndpointFromBase(fallbackBase, sessionId);
    }

    buildMessagesEndpointFromBase(baseEndpoint, sessionId) {
        if (!baseEndpoint || !sessionId) {
            return undefined;
        }

        if (baseEndpoint.includes('{sessionId}')) {
            return baseEndpoint.replace('{sessionId}', encodeURIComponent(sessionId));
        }

        let normalized = baseEndpoint.replace(/\/+$/, '');
        if (!normalized.endsWith('/sessions')) {
            normalized = `${normalized}/sessions`;
        }
        return `${normalized}/${encodeURIComponent(sessionId)}/messages`;
    }

    appendPath(base, segment) {
        if (!base) {
            return undefined;
        }
        const trimmed = base.replace(/\/+$/, '');
        return `${trimmed}/${segment}`;
    }

    generateExternalSessionKey() {
        const array = new Uint32Array(4);
        const hasWindow = typeof window !== 'undefined';
        const cryptoProvider = hasWindow ? window.crypto : undefined;
        if (cryptoProvider && typeof cryptoProvider.getRandomValues === 'function') {
            cryptoProvider.getRandomValues(array);
        } else {
            for (let index = 0; index < array.length; index += 1) {
                array[index] = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER);
            }
        }
        return Array.from(array)
            .map((value) => value.toString(16).padStart(8, '0'))
            .join('');
    }

    normalizeLocale(locale) {
        if (!locale || typeof locale !== 'string') {
            return 'en_US';
        }
        return locale.replace('-', '_');
    }

    getBrowserTimeZone() {
        try {
            return Intl.DateTimeFormat().resolvedOptions().timeZone;
        } catch (error) {
            return 'UTC';
        }
    }

    normalizeError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (typeof error === 'string') {
            return error;
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return 'Unexpected error';
    }

    createMessage(role, content, variant = '') {
        const timestamp = new Date().toISOString();
        return {
            id: `${role}-${timestamp}-${Math.random().toString(36).slice(2, 10)}`,
            role,
            roleLabel: ROLE_LABELS[role] || role,
            content,
            timestamp,
            formattedTimestamp: new Intl.DateTimeFormat('en-US', {
                hour: 'numeric',
                minute: 'numeric',
                hour12: true
            }).format(new Date(timestamp)),
            cssClass: `message ${role}${variant ? ` ${variant}` : ''}`
        };
    }
}
