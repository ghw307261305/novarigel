const EMBEDDED_SERVICE_GLOBAL = 'embedded_svc';
const EMBEDDED_SERVICE_FALLBACKS = [
    'embeddedservice_bootstrap',
    'embeddedserviceBootstrap'
];
const EMBEDDED_SERVICE_POLL_ATTEMPTS = 10;
const EMBEDDED_SERVICE_POLL_INTERVAL = 150;
const DEFAULT_DETAIL_LABELS = {
    orderId: '注文ID',
    orderItemId: '注文明細ID'
};

function isPromiseLike(value) {
    return value && typeof value.then === 'function';
}

function getWindowObject() {
    if (typeof window === 'undefined') {
        return undefined;
    }

    return window;
}

function hasServiceInterface(candidate) {
    if (!candidate) {
        return false;
    }

    if (candidate.liveAgentAPI && typeof candidate.liveAgentAPI.startChat === 'function') {
        return true;
    }

    return (
        typeof candidate.openChat === 'function' ||
        typeof candidate.openHelp === 'function' ||
        typeof candidate.bootstrapEmbeddedService === 'function'
    );
}

function findEmbeddedServiceGlobal(win) {
    if (!win) {
        return undefined;
    }

    const primary = win[EMBEDDED_SERVICE_GLOBAL];
    if (hasServiceInterface(primary)) {
        return primary;
    }

    for (const fallback of EMBEDDED_SERVICE_FALLBACKS) {
        const candidate = win[fallback];
        if (candidate) {
            if (
                candidate.embeddedserviceBootstrap &&
                typeof candidate.embeddedserviceBootstrap === 'object'
            ) {
                const nested = candidate.embeddedserviceBootstrap;
                if (hasServiceInterface(nested)) {
                    return nested;
                }
            }

            if (hasServiceInterface(candidate)) {
                return candidate;
            }
        }
    }

    return undefined;
}

function delay(duration) {
    return new Promise((resolve) => {
        setTimeout(resolve, duration);
    });
}

async function waitForEmbeddedService(win) {
    let attemptsRemaining = EMBEDDED_SERVICE_POLL_ATTEMPTS;

    while (attemptsRemaining > 0) {
        const service = findEmbeddedServiceGlobal(win);
        if (service) {
            return service;
        }

        attemptsRemaining -= 1;
        await delay(EMBEDDED_SERVICE_POLL_INTERVAL);
    }

    return undefined;
}

async function resolveEmbeddedService(embeddedService) {
    if (embeddedService) {
        return embeddedService;
    }

    const win = getWindowObject();
    const service = await waitForEmbeddedService(win);

    if (!service) {
        throw new Error(
            '返品・交換サポートの組み込みサービスが初期化されていません。'
        );
    }

    return service;
}

function buildPrechatDetail(label, value) {
    return {
        label,
        value,
        displayToAgent: true
    };
}

function buildPrechatDetails(context = {}) {
    return Object.entries(DEFAULT_DETAIL_LABELS)
        .map(([key, label]) => ({ label, value: context[key] }))
        .filter((detail) => detail.value)
        .map(({ label, value }) => buildPrechatDetail(label, value));
}

function mergePrechatDetails(settings, details) {
    if (!details.length) {
        return [];
    }

    const existing = Array.isArray(settings.extraPrechatFormDetails)
        ? settings.extraPrechatFormDetails
        : settings.extraPrechatFormDetails
        ? [settings.extraPrechatFormDetails]
        : [];

    const existingWithoutDuplicates = existing.filter((entry) => {
        if (!entry || !entry.label) {
            return true;
        }

        return !details.some((detail) => detail.label === entry.label);
    });

    const merged = [...details, ...existingWithoutDuplicates];
    settings.extraPrechatFormDetails = merged;
    return merged;
}

function getEmbeddedServiceSettings(service) {
    if (!service.settings) {
        service.settings = {};
    }

    return service.settings;
}

function openEmbeddedService(service) {
    if (service.liveAgentAPI && typeof service.liveAgentAPI.startChat === 'function') {
        const result = service.liveAgentAPI.startChat();
        return isPromiseLike(result) ? result : Promise.resolve();
    }

    if (typeof service.openChat === 'function') {
        const result = service.openChat();
        return isPromiseLike(result) ? result : Promise.resolve();
    }

    if (typeof service.openHelp === 'function') {
        const result = service.openHelp();
        return isPromiseLike(result) ? result : Promise.resolve();
    }

    if (typeof service.bootstrapEmbeddedService === 'function') {
        const result = service.bootstrapEmbeddedService();
        return isPromiseLike(result) ? result : Promise.resolve();
    }

    throw new Error(
        '返品・交換サポートを開始するための組み込みサービスが構成されていません。'
    );
}

export async function launchReturnsAgentUi({ context, embeddedService } = {}) {
    if (!context || (!context.orderId && !context.orderItemId)) {
        throw new Error(
            '返品・交換サポートを起動するには注文または注文明細の識別子が必要です。'
        );
    }

    const service = await resolveEmbeddedService(embeddedService);
    const settings = getEmbeddedServiceSettings(service);
    const prechatDetails = buildPrechatDetails(context);

    mergePrechatDetails(settings, prechatDetails);
    await openEmbeddedService(service);

    return {
        context,
        prechatDetails
    };
}

export function buildReturnsAgentUrl() {
    throw new Error('Experience Cloud サイトでは直接URLに遷移できません。');
}

export function buildReturnsAgentPageReference() {
    throw new Error('Experience Cloud サイトではLightningページ参照を生成しません。');
}
