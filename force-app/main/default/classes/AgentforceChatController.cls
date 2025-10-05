public with sharing class AgentforceChatController {
    @AuraEnabled(cacheable=true)
    public static AgentforceChatConfig getConfig() {
        Agentforce_Config__mdt config = Agentforce_Config__mdt.getInstance('Default');
        if (config == null) {
            return new AgentforceChatConfig('', '', '', '', '', '', '', '');
        }
        return new AgentforceChatConfig(
            config.Chat_Endpoint_Url__c,
            config.Bot_Id__c,
            config.Authorization_Header_Value__c,
            config.Endpoint_Url__c,
            config.Consumer_Key__c,
            config.Consumer_Secret__c,
            config.Username__c,
            config.Password__c
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
            : (config != null ? config.Chat_Endpoint_Url__c : null);
        String resolvedBotId = String.isNotBlank(botId)
            ? botId
            : (config != null ? config.Bot_Id__c : null);

        if (config == null) {
            throw new AuraHandledException('Missing Agentforce configuration');
        }

        if (String.isBlank(resolvedEndpoint) || String.isBlank(resolvedBotId)) {
            throw new AuraHandledException('Missing Agentforce configuration');
        }

        String tokenEndpoint = config.Endpoint_Url__c;
        String consumerKey = config.Consumer_Key__c;
        String consumerSecret = config.Consumer_Secret__c;
        String usernameValue = config.Username__c;
        String passwordValue = config.Password__c;

        if (
            String.isBlank(tokenEndpoint) || String.isBlank(consumerKey) || String.isBlank(consumerSecret)
            || String.isBlank(usernameValue) || String.isBlank(passwordValue)
        ) {
            throw new AuraHandledException('Missing Agentforce OAuth configuration');
        }

        String accessToken = requestAccessToken(
            tokenEndpoint,
            consumerKey,
            consumerSecret,
            usernameValue,
            passwordValue
        );

        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(resolvedEndpoint);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        if (String.isNotBlank(config.Authorization_Header_Value__c)) {
            request.setHeader('X-Agentforce-Authorization', config.Authorization_Header_Value__c);
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

    private static String extractErrorMessage(String responseBody) {
        if (String.isBlank(responseBody)) {
            return null;
        }

        try {
            Object parsed = JSON.deserializeUntyped(responseBody);
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> responseMap = (Map<String, Object>) parsed;
                if (responseMap.containsKey('message') && responseMap.get('message') instanceof String) {
                    return (String) responseMap.get('message');
                }
                if (responseMap.containsKey('error_description') && responseMap.get('error_description') instanceof String) {
                    return (String) responseMap.get('error_description');
                }
                if (responseMap.containsKey('error') && responseMap.get('error') instanceof String) {
                    return (String) responseMap.get('error');
                }
            }
            AgentforceErrorResponse errorResponse = (AgentforceErrorResponse) JSON.deserialize(responseBody, AgentforceErrorResponse.class);
            return errorResponse != null ? errorResponse.message : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static String requestAccessToken(
        String tokenEndpoint,
        String consumerKey,
        String consumerSecret,
        String usernameValue,
        String passwordValue
    ) {
        HttpRequest tokenRequest = new HttpRequest();
        tokenRequest.setMethod('POST');
        tokenRequest.setEndpoint(tokenEndpoint);
        tokenRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String requestBody = String.join(new List<String>{
            'grant_type=password',
            'client_id=' + EncodingUtil.urlEncode(consumerKey, 'UTF-8'),
            'client_secret=' + EncodingUtil.urlEncode(consumerSecret, 'UTF-8'),
            'username=' + EncodingUtil.urlEncode(usernameValue, 'UTF-8'),
            'password=' + EncodingUtil.urlEncode(passwordValue, 'UTF-8')
        }, '&');
        tokenRequest.setBody(requestBody);

        Http http = new Http();
        HttpResponse tokenResponse;
        try {
            tokenResponse = http.send(tokenRequest);
        } catch (System.CalloutException ex) {
            throw new AuraHandledException('Agentforce OAuth request failed: ' + ex.getMessage());
        }

        if (tokenResponse.getStatusCode() < 200 || tokenResponse.getStatusCode() >= 300) {
            String tokenError = extractErrorMessage(tokenResponse.getBody());
            if (String.isBlank(tokenError)) {
                tokenError = 'Agentforce OAuth request failed';
            }
            throw new AuraHandledException(tokenError);
        }

        if (String.isBlank(tokenResponse.getBody())) {
            throw new AuraHandledException('Agentforce OAuth response missing access token');
        }

        Object parsed = JSON.deserializeUntyped(tokenResponse.getBody());
        if (!(parsed instanceof Map<String, Object>)) {
            throw new AuraHandledException('Agentforce OAuth response malformed');
        }

        Map<String, Object> responseMap = (Map<String, Object>) parsed;
        String accessToken = responseMap.containsKey('access_token')
            ? (String) responseMap.get('access_token')
            : null;

        if (String.isBlank(accessToken)) {
            throw new AuraHandledException('Agentforce OAuth response missing access token');
        }

        return accessToken;
    }

    public class AgentforceChatConfig {
        @AuraEnabled
        public String endpointUrl { get; set; }

        @AuraEnabled
        public String botId { get; set; }

        @AuraEnabled
        public String authorizationHeaderValue { get; set; }

        @AuraEnabled
        public String tokenEndpointUrl { get; set; }

        @AuraEnabled
        public String consumerKey { get; set; }

        @AuraEnabled
        public String consumerSecret { get; set; }

        @AuraEnabled
        public String username { get; set; }

        @AuraEnabled
        public String password { get; set; }

        public AgentforceChatConfig(
            String endpointUrl,
            String botId,
            String authorizationHeaderValue,
            String tokenEndpointUrl,
            String consumerKey,
            String consumerSecret,
            String username,
            String password
        ) {
            this.endpointUrl = endpointUrl;
            this.botId = botId;
            this.authorizationHeaderValue = authorizationHeaderValue;
            this.tokenEndpointUrl = tokenEndpointUrl;
            this.consumerKey = consumerKey;
            this.consumerSecret = consumerSecret;
            this.username = username;
            this.password = password;
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
