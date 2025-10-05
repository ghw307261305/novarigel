public with sharing class AgentforceChatController {
    @AuraEnabled(cacheable=true)
    public static AgentforceChatConfig getConfig() {
        Agentforce_Config__mdt config = Agentforce_Config__mdt.getInstance('Default');
        if (config == null) {
            return new AgentforceChatConfig('', '', '', '');
        }
        return new AgentforceChatConfig(
            config.Endpoint_Url__c,
            config.Bot_Id__c,
            config.Named_Credential__c,
            config.Authorization_Header_Value__c
        );
    }

    @AuraEnabled
    public static AgentforceChatResponse sendMessage(
        String message,
        List<AgentforceChatTranscriptEntry> transcript,
        String endpointUrl,
        String botId
    ) {
        Agentforce_Config__mdt config = Agentforce_Config__mdt.getInstance('Default');

        String resolvedEndpoint = String.isNotBlank(endpointUrl)
            ? endpointUrl
            : (config != null ? config.Endpoint_Url__c : null);
        String resolvedBotId = String.isNotBlank(botId)
            ? botId
            : (config != null ? config.Bot_Id__c : null);
        String namedCredential = config != null ? config.Named_Credential__c : null;
        String authorizationHeader = config != null ? config.Authorization_Header_Value__c : null;

        if (String.isBlank(resolvedEndpoint) || String.isBlank(resolvedBotId) || String.isBlank(namedCredential)) {
            throw new AuraHandledException('Missing Agentforce configuration');
        }

        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(buildCalloutEndpoint(namedCredential, resolvedEndpoint));
        request.setHeader('Content-Type', 'application/json');
        if (String.isNotBlank(authorizationHeader)) {
            request.setHeader('Authorization', authorizationHeader);
        }

        Map<String, Object> payload = new Map<String, Object>{
            'botId' => resolvedBotId,
            'message' => message,
            'transcript' => transcript != null ? transcript : new List<AgentforceChatTranscriptEntry>()
        };
        request.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse response;
        try {
            response = http.send(request);
        } catch (System.CalloutException ex) {
            throw new AuraHandledException('Agentforce request failed: ' + ex.getMessage());
        }

        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            if (String.isBlank(response.getBody())) {
                return new AgentforceChatResponse();
            }
            return (AgentforceChatResponse) JSON.deserialize(response.getBody(), AgentforceChatResponse.class);
        }

        String errorMessage = extractErrorMessage(response.getBody());
        if (String.isBlank(errorMessage)) {
            errorMessage = 'Agentforce request failed';
        }
        throw new AuraHandledException(errorMessage);
    }

    private static String buildCalloutEndpoint(String namedCredential, String endpointUrl) {
        String trimmedEndpoint = endpointUrl == null ? '' : endpointUrl.trim();
        if (startsWithIgnoreCase(trimmedEndpoint, 'http://') || startsWithIgnoreCase(trimmedEndpoint, 'https://')) {
            Integer startOfPath = trimmedEndpoint.indexOf('/', trimmedEndpoint.indexOf('//') + 2);
            trimmedEndpoint = startOfPath > -1 ? trimmedEndpoint.substring(startOfPath) : '';
        }

        if (String.isBlank(trimmedEndpoint)) {
            return 'callout:' + namedCredential;
        }

        if (!trimmedEndpoint.startsWith('/')) {
            trimmedEndpoint = '/' + trimmedEndpoint;
        }

        return 'callout:' + namedCredential + trimmedEndpoint;
    }

    private static String extractErrorMessage(String responseBody) {
        if (String.isBlank(responseBody)) {
            return null;
        }

        try {
            AgentforceErrorResponse errorResponse = (AgentforceErrorResponse) JSON.deserialize(responseBody, AgentforceErrorResponse.class);
            return errorResponse != null ? errorResponse.message : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Boolean startsWithIgnoreCase(String value, String prefix) {
        return String.isNotBlank(value)
            && String.isNotBlank(prefix)
            && value.toLowerCase().startsWith(prefix.toLowerCase());
    }

    public class AgentforceChatConfig {
        @AuraEnabled
        public String endpointUrl { get; set; }

        @AuraEnabled
        public String botId { get; set; }

        @AuraEnabled
        public String namedCredential { get; set; }

        @AuraEnabled
        public String authorizationHeaderValue { get; set; }

        public AgentforceChatConfig(
            String endpointUrl,
            String botId,
            String namedCredential,
            String authorizationHeaderValue
        ) {
            this.endpointUrl = endpointUrl;
            this.botId = botId;
            this.namedCredential = namedCredential;
            this.authorizationHeaderValue = authorizationHeaderValue;
        }
    }

    public class AgentforceChatTranscriptEntry {
        @AuraEnabled
        public String role { get; set; }

        @AuraEnabled
        public String content { get; set; }

        @AuraEnabled
        public String timestamp { get; set; }
    }

    public class AgentforceChatResponse {
        @AuraEnabled
        public String message { get; set; }
    }

    private class AgentforceErrorResponse {
        public String message { get; set; }
    }
}
