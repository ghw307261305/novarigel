import { LightningElement, api, wire } from 'lwc';
import getConfig from '@salesforce/apex/AgentforceChatController.getConfig';
import sendMessage from '@salesforce/apex/AgentforceChatController.sendMessage';

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
    _endpointUrl;
    _botId;

    @api
    get endpointUrl() {
        return this._endpointUrl;
    }

    set endpointUrl(value) {
        this._endpointUrl = value;
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
        return !this.draftMessage || this.isLoading || !this.resolvedEndpoint;
    }

    get resolvedEndpoint() {
        return this.endpointUrl || (this.wiredConfig?.data && this.wiredConfig.data.endpointUrl);
    }

    get resolvedBotId() {
        return this.botId || (this.wiredConfig?.data && this.wiredConfig.data.botId);
    }

    applyConfig(data) {
        if (!this.endpointUrl) {
            this._endpointUrl = data.endpointUrl;
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
        const endpoint = this.resolvedEndpoint;
        const botId = this.resolvedBotId;

        if (!endpoint || !botId) {
            throw new Error('Missing Agentforce configuration');
        }

        return sendMessage({
            message: content,
            transcript: this.messages.map((message) => ({
                role: message.role,
                content: message.content,
                timestamp: message.timestamp
            })),
            endpointUrl: endpoint,
            botId
        });
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
