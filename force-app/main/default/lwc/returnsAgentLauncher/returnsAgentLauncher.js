const WORKSPACE_BASE_URL = '/lightning/n/NovaRigel_Returns_Agent';
const ORDER_ID_PARAM = 'c__orderId';
const ORDER_ITEM_ID_PARAM = 'c__orderItemId';

function isPromiseLike(value) {
    return value && typeof value.then === 'function';
}

export function buildReturnsAgentUrl(context = {}) {
    const params = new URLSearchParams();
    const { orderId, orderItemId } = context;

    if (orderId) {
        params.append(ORDER_ID_PARAM, orderId);
    }

    if (orderItemId) {
        params.append(ORDER_ITEM_ID_PARAM, orderItemId);
    }

    const queryString = params.toString();
    return queryString ? `${WORKSPACE_BASE_URL}?${queryString}` : WORKSPACE_BASE_URL;
}

export function buildReturnsAgentPageReference(context = {}) {
    return {
        type: 'standard__webPage',
        attributes: {
            url: buildReturnsAgentUrl(context)
        }
    };
}

export async function launchReturnsAgentUi({ navigate, context } = {}) {
    if (!context || (!context.orderId && !context.orderItemId)) {
        throw new Error(
            '返品・交換サポートを起動するには注文または注文明細の識別子が必要です。'
        );
    }

    const pageReference = buildReturnsAgentPageReference(context);

    if (typeof navigate === 'function') {
        const navigationResult = navigate(pageReference);
        if (isPromiseLike(navigationResult)) {
            await navigationResult;
        }
    } else if (typeof window !== 'undefined' && typeof window.open === 'function') {
        window.open(pageReference.attributes.url, '_blank', 'noopener');
    } else {
        throw new Error('Agentforce ワークスペースを開く方法が構成されていません。');
    }

    return pageReference;
}
