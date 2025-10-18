public with sharing class NovaRigelReturnsAgentController {
    public class ReturnsAgentSession {
        @AuraEnabled
        public String sessionId;

        @AuraEnabled
        public String launchUrl;

        @AuraEnabled
        public String conversationId;

        @AuraEnabled
        public String message;
    }

    @AuraEnabled
    public static ReturnsAgentSession launchReturnsAgent(Id orderId, Id orderItemId) {
        if (orderId == null && orderItemId == null) {
            throw new AuraHandledException('注文もしくは注文明細の識別子が指定されていません。');
        }

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:NovaRigel_Agentforce/agentforce/agents/NovaRigel_Returns_Agent/sessions');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');

        Map<String, Object> payload = new Map<String, Object>();
        if (orderId != null) {
            payload.put('orderId', orderId);
        }
        if (orderItemId != null) {
            payload.put('orderItemId', orderItemId);
        }

        request.setBody(JSON.serialize(payload));

        HttpResponse response;
        try {
            response = http.send(request);
        } catch (System.CalloutException e) {
            String message = '返品・交換サポートの起動に失敗しました。外部サービスの認証情報（NovaRigel_Agentforce）や権限を確認してください。';
            if (!String.isBlank(e.getMessage())) {
                message += ' 詳細: ' + e.getMessage();
            }

            throw new AuraHandledException(message);
        }
        Integer statusCode = response.getStatusCode();
        if (statusCode >= 200 && statusCode < 300) {
            String body = response.getBody();
            if (String.isBlank(body)) {
                return new ReturnsAgentSession();
            }

            return (ReturnsAgentSession) JSON.deserialize(body, ReturnsAgentSession.class);
        }

        String errorMessage = '返品・交換サポートの起動に失敗しました。(' + statusCode + ')';
        if (!String.isBlank(response.getBody())) {
            errorMessage += ' ' + response.getBody();
        }

        throw new AuraHandledException(errorMessage);
    }
}