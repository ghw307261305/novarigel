@IsTest
private class NovaRigelReturnsAgentControllerTest {
    private class ReturnsAgentMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        ReturnsAgentMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals(
                'callout:NovaRigel_Agentforce/agentforce/agents/NovaRigel_Returns_Agent/sessions',
                req.getEndpoint(),
                'Unexpected endpoint.'
            );
            System.assertEquals('POST', req.getMethod(), 'HTTP method should be POST');

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            System.assertEquals('001000000000001AAA', (String) payload.get('orderId'));
            System.assertEquals('801000000000001AAA', (String) payload.get('orderItemId'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void testLaunchReturnsAgentSuccess() {
        Test.setMock(
            HttpCalloutMock.class,
            new ReturnsAgentMock(200, '{"sessionId":"session-123","launchUrl":"https://example.com","conversationId":"convo-001","message":"Launch"}')
        );

        Test.startTest();
        NovaRigelReturnsAgentController.ReturnsAgentSession result =
            NovaRigelReturnsAgentController.launchReturnsAgent(
                Id.valueOf('001000000000001AAA'),
                Id.valueOf('801000000000001AAA')
            );
        Test.stopTest();

        System.assertEquals('session-123', result.sessionId);
        System.assertEquals('https://example.com', result.launchUrl);
        System.assertEquals('convo-001', result.conversationId);
        System.assertEquals('Launch', result.message);
    }

    @IsTest
    static void testLaunchReturnsAgentError() {
        Test.setMock(HttpCalloutMock.class, new ReturnsAgentMock(500, 'Internal Error'));

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            NovaRigelReturnsAgentController.launchReturnsAgent(
                Id.valueOf('001000000000001AAA'),
                Id.valueOf('801000000000001AAA')
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('返品・交換サポートの起動に失敗しました。'));
            System.assert(e.getMessage().contains('500'));
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'An AuraHandledException should have been thrown');
    }

    private class ThrowingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException(
                'The callout couldn\'t access the endpoint. You might not have the required permissions, or the named credential "NovaRigel_Agentforce" might not exist.'
            );
        }
    }

    @IsTest
    static void testLaunchReturnsAgentCalloutException() {
        Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            NovaRigelReturnsAgentController.launchReturnsAgent(
                Id.valueOf('001000000000001AAA'),
                Id.valueOf('801000000000001AAA')
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('外部サービスの認証情報（NovaRigel_Agentforce）や権限を確認してください。'),
                'Should surface configuration guidance.'
            );
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'An AuraHandledException should have been thrown');
    }
}
