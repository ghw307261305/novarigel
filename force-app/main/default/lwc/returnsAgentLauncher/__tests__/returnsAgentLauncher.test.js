import { launchReturnsAgentUi } from 'c/returnsAgentLauncher';

describe('returnsAgentLauncher.launchReturnsAgentUi', () => {
    afterEach(() => {
        if (typeof window !== 'undefined') {
            delete window.embedded_svc;
            delete window.embeddedservice_bootstrap;
        }

        jest.useRealTimers();
    });

    it('throws when no context is provided', async () => {
        await expect(launchReturnsAgentUi()).rejects.toThrow(
            '返品・交換サポートを起動するには注文または注文明細の識別子が必要です。'
        );
    });

    it('throws when embedded service is not available', async () => {

        jest.useFakeTimers();

        const promise = launchReturnsAgentUi({
            context: { orderId: '801000000000001AAA' }
        });

        jest.runAllTimers();

        await expect(promise).rejects.toThrow(
            '返品・交換サポートの組み込みサービスが初期化されていません。'
        );
    });

    it('starts a chat with prechat details when liveAgentAPI is available', async () => {
        const startChat = jest.fn();

        window.embedded_svc = {
            settings: {
                extraPrechatFormDetails: [
                    { label: '既存情報', value: '保持する値', displayToAgent: true },
                    { label: '注文ID', value: '上書き前', displayToAgent: true }
                ]
            },
            liveAgentAPI: {
                startChat
            }
        };

        const result = await launchReturnsAgentUi({
            context: {
                orderId: '801000000000001AAA',
                orderItemId: '802000000000001AAA'
            }
        });

        expect(startChat).toHaveBeenCalledTimes(1);
        expect(result).toEqual({
            context: {
                orderId: '801000000000001AAA',
                orderItemId: '802000000000001AAA'
            },
            prechatDetails: [
                { label: '注文ID', value: '801000000000001AAA', displayToAgent: true },
                { label: '注文明細ID', value: '802000000000001AAA', displayToAgent: true }
            ]
        });
        expect(window.embedded_svc.settings.extraPrechatFormDetails).toEqual([
            { label: '注文ID', value: '801000000000001AAA', displayToAgent: true },
            { label: '注文明細ID', value: '802000000000001AAA', displayToAgent: true },
            { label: '既存情報', value: '保持する値', displayToAgent: true }
        ]);
    });

    it('falls back to openChat when liveAgentAPI is unavailable', async () => {
        const openChat = jest.fn(() => Promise.resolve());

        window.embedded_svc = {
            openChat
        };

        const result = await launchReturnsAgentUi({
            context: {
                orderItemId: '802000000000001AAA'
            }
        });

        expect(openChat).toHaveBeenCalledTimes(1);
        expect(result).toEqual({
            context: {
                orderItemId: '802000000000001AAA'
            },
            prechatDetails: [
                { label: '注文明細ID', value: '802000000000001AAA', displayToAgent: true }
            ]
        });
        expect(window.embedded_svc.settings.extraPrechatFormDetails).toEqual([
            { label: '注文明細ID', value: '802000000000001AAA', displayToAgent: true }
        ]);
    });

    it('resolves embeddedservice_bootstrap globals when present', async () => {
        const startChat = jest.fn();

        window.embeddedservice_bootstrap = {
            embeddedserviceBootstrap: {
                settings: {
                    extraPrechatFormDetails: []
                },
                liveAgentAPI: {
                    startChat
                }
            }
        };

        const result = await launchReturnsAgentUi({
            context: { orderId: '801000000000001AAC' }
        });

        expect(startChat).toHaveBeenCalledTimes(1);
        expect(result).toEqual({
            context: { orderId: '801000000000001AAC' },
            prechatDetails: [
                { label: '注文ID', value: '801000000000001AAC', displayToAgent: true }
            ]
        });
        expect(
            window.embeddedservice_bootstrap.embeddedserviceBootstrap.settings
                .extraPrechatFormDetails
        ).toEqual([
            { label: '注文ID', value: '801000000000001AAC', displayToAgent: true }
        ]);
    });

    it('waits for embedded service to load before launching', async () => {
        jest.useFakeTimers();

        const startChat = jest.fn();

        setTimeout(() => {
            window.embedded_svc = {
                settings: {},
                liveAgentAPI: {
                    startChat
                }
            };
        }, 75);

        const promise = launchReturnsAgentUi({
            context: { orderId: '801000000000001AAB' }
        });

        jest.advanceTimersByTime(200);

        await promise;

        expect(startChat).toHaveBeenCalledTimes(1);
        expect(window.embedded_svc.settings.extraPrechatFormDetails).toEqual([
            { label: '注文ID', value: '801000000000001AAB', displayToAgent: true }
        ]);
    });
});
