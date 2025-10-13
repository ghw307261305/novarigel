public with sharing class AgentforceChatController {
  @AuraEnabled(cacheable=true)
  public static AgentforceChatConfig getConfig() {
    Agentforce_Config__mdt config = Agentforce_Config__mdt.getInstance(
      'Default'
    );
    if (config == null) {
      return new AgentforceChatConfig('', '', '', '', '', '', '', '', '');
    }
    String startSessionEndpoint = config.Start_Session_Endpoint_Url__c;
    if (String.isBlank(startSessionEndpoint)) {
      startSessionEndpoint = config.Chat_Endpoint_Url__c;
    }

    String messagesEndpoint = config.Messages_Endpoint_Url__c;
    if (String.isBlank(messagesEndpoint)) {
      messagesEndpoint = config.Chat_Endpoint_Url__c;
    }

    return new AgentforceChatConfig(
      startSessionEndpoint,
      messagesEndpoint,
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
    String botId,
    String sessionId
  ) {
    Agentforce_Config__mdt config = Agentforce_Config__mdt.getInstance(
      'Default'
    );

    String configuredMessagesEndpoint = config != null
      ? preferString(
          config.Messages_Endpoint_Url__c,
          config.Chat_Endpoint_Url__c
        )
      : null;

    String resolvedEndpoint = String.isNotBlank(endpointUrl)
      ? endpointUrl
      : configuredMessagesEndpoint;
    String resolvedBotId = String.isNotBlank(botId)
      ? botId
      : (config != null ? config.Bot_Id__c : null);

    if (config == null) {
      throw new AuraHandledException('Missing Agentforce configuration');
    }

    if (String.isBlank(resolvedEndpoint) || String.isBlank(resolvedBotId)) {
      throw new AuraHandledException('Missing Agentforce configuration');
    }

    if (String.isBlank(sessionId)) {
      throw new AuraHandledException('Missing Agentforce session');
    }

    String tokenEndpoint = config.Endpoint_Url__c;
    String consumerKey = config.Consumer_Key__c;
    String consumerSecret = config.Consumer_Secret__c;
    if (
      String.isBlank(tokenEndpoint) ||
      String.isBlank(consumerKey) ||
      String.isBlank(consumerSecret)
    ) {
      throw new AuraHandledException('Missing Agentforce OAuth configuration');
    }

    String accessToken = requestAccessToken(
      tokenEndpoint,
      consumerKey,
      consumerSecret
    );

    String messagesEndpoint = applySessionPlaceholder(
      resolvedEndpoint,
      sessionId
    );
    if (String.isNotBlank(messagesEndpoint)) {
      Boolean hasSessionSegment = messagesEndpoint.contains('/sessions/');
      Boolean endsWithMessages = messagesEndpoint.endsWith('/messages');
      if (!hasSessionSegment || !endsWithMessages) {
        messagesEndpoint = buildMessagesUrl(messagesEndpoint, sessionId);
      }
    }

    if (String.isBlank(messagesEndpoint)) {
      throw new AuraHandledException('Missing Agentforce configuration');
    }

    HttpRequest request = new HttpRequest();
    request.setMethod('POST');
    request.setEndpoint(messagesEndpoint);
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('Authorization', 'Bearer ' + accessToken);
    if (String.isNotBlank(config.Authorization_Header_Value__c)) {
      request.setHeader(
        'X-Agentforce-Authorization',
        config.Authorization_Header_Value__c
      );
    }

    Map<String, Object> messagePayload = new Map<String, Object>{
      'sequenceId' => DateTime.now().getTime(),
      'type' => 'Text',
      'text' => message != null ? message : ''
    };
    Map<String, Object> payload = new Map<String, Object>{
      'message' => messagePayload,
      'variables' => new List<Object>()
    };
    request.setBody(JSON.serialize(payload));

    Http http = new Http();
    HttpResponse response;
    try {
      response = http.send(request);
    } catch (System.CalloutException ex) {
      throw new AuraHandledException(
        'Agentforce request failed: ' + ex.getMessage()
      );
    }

    if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
      if (String.isBlank(response.getBody())) {
        return new AgentforceChatResponse();
      }
      return (AgentforceChatResponse) JSON.deserialize(
        response.getBody(),
        AgentforceChatResponse.class
      );
    }

    String errorMessage = extractErrorMessage(response.getBody());
    if (String.isBlank(errorMessage)) {
      errorMessage = 'Agentforce request failed';
    }
    throw new AuraHandledException(errorMessage);
  }

  @AuraEnabled
  public static AgentforceStartSessionResult startSession(
    String endpointUrl,
    Map<String, Object> payload
  ) {
    Agentforce_Config__mdt config = Agentforce_Config__mdt.getInstance(
      'Default'
    );

    String configuredStartSessionEndpoint = config != null
      ? preferString(
          config.Start_Session_Endpoint_Url__c,
          config.Chat_Endpoint_Url__c
        )
      : null;

    String resolvedEndpoint = String.isNotBlank(endpointUrl)
      ? endpointUrl
      : configuredStartSessionEndpoint;

    if (config == null) {
      throw new AuraHandledException('Missing Agentforce configuration');
    }

    if (String.isBlank(resolvedEndpoint)) {
      throw new AuraHandledException('Missing Agentforce configuration');
    }

    resolvedEndpoint = applyAgentPlaceholder(
      resolvedEndpoint,
      config != null ? config.Bot_Id__c : null
    );

    String tokenEndpoint = config.Endpoint_Url__c;
    String consumerKey = config.Consumer_Key__c;
    String consumerSecret = config.Consumer_Secret__c;
    if (
      String.isBlank(tokenEndpoint) ||
      String.isBlank(consumerKey) ||
      String.isBlank(consumerSecret)
    ) {
      throw new AuraHandledException('Missing Agentforce OAuth configuration');
    }

    String accessToken = requestAccessToken(
      tokenEndpoint,
      consumerKey,
      consumerSecret
    );

    HttpRequest request = new HttpRequest();
    request.setMethod('POST');
    request.setEndpoint(resolvedEndpoint);
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('Authorization', 'Bearer ' + accessToken);
    if (String.isNotBlank(config.Authorization_Header_Value__c)) {
      request.setHeader(
        'X-Agentforce-Authorization',
        config.Authorization_Header_Value__c
      );
    }

    Map<String, Object> payloadToSend = payload != null
      ? new Map<String, Object>(payload)
      : new Map<String, Object>();
    applyDefaultStartSessionPayload(payloadToSend);

    String sessionKeyFromPayload = payloadToSend.containsKey(
        'externalSessionKey'
      ) && payloadToSend.get('externalSessionKey') instanceof String
      ? (String) payloadToSend.get('externalSessionKey')
      : null;

    request.setBody(JSON.serialize(payloadToSend));

    Http http = new Http();
    HttpResponse response;
    try {
      response = http.send(request);
    } catch (System.CalloutException ex) {
      throw new AuraHandledException(
        'Agentforce request failed: ' + ex.getMessage()
      );
    }

    if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
      AgentforceStartSessionResult result = new AgentforceStartSessionResult();
      result.statusCode = response.getStatusCode();
      result.externalSessionKey = sessionKeyFromPayload;
      if (String.isNotBlank(response.getBody())) {
        result.body = response.getBody();
        Object parsed = JSON.deserializeUntyped(response.getBody());
        if (parsed instanceof Map<String, Object>) {
          result.data = (Map<String, Object>) parsed;
          enrichStartSessionResult(result);
        }
      }
      return result;
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
        if (
          responseMap.containsKey('message') &&
          responseMap.get('message') instanceof String
        ) {
          return (String) responseMap.get('message');
        }
        if (
          responseMap.containsKey('error_description') &&
          responseMap.get('error_description') instanceof String
        ) {
          return (String) responseMap.get('error_description');
        }
        if (
          responseMap.containsKey('error') &&
          responseMap.get('error') instanceof String
        ) {
          return (String) responseMap.get('error');
        }
      }
      AgentforceErrorResponse errorResponse = (AgentforceErrorResponse) JSON.deserialize(
        responseBody,
        AgentforceErrorResponse.class
      );
      return errorResponse != null ? errorResponse.message : null;
    } catch (Exception ex) {
      return null;
    }
  }

  private static String requestAccessToken(
    String tokenEndpoint,
    String consumerKey,
    String consumerSecret
  ) {
    HttpRequest tokenRequest = new HttpRequest();
    tokenRequest.setMethod('POST');
    tokenRequest.setEndpoint(tokenEndpoint);
    tokenRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');

    String requestBody = String.join(
      new List<String>{
        'grant_type=client_credentials',
        'client_id=' + consumerKey,
        'client_secret=' + consumerSecret
      },
      '&'
    );
    tokenRequest.setBody(requestBody);

    Http http = new Http();
    HttpResponse tokenResponse;
    try {
      tokenResponse = http.send(tokenRequest);
    } catch (System.CalloutException ex) {
      throw new AuraHandledException(
        'Agentforce OAuth request failed: ' + ex.getMessage()
      );
    }

    if (
      tokenResponse.getStatusCode() < 200 ||
      tokenResponse.getStatusCode() >= 300
    ) {
      String tokenError = extractErrorMessage(tokenResponse.getBody());
      if (String.isBlank(tokenError)) {
        tokenError = 'Agentforce OAuth request failed';
      }
      throw new AuraHandledException(tokenError);
    }

    if (String.isBlank(tokenResponse.getBody())) {
      throw new AuraHandledException(
        'Agentforce OAuth response missing access token'
      );
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
      throw new AuraHandledException(
        'Agentforce OAuth response missing access token'
      );
    }

    return accessToken;
  }

  private static void applyDefaultStartSessionPayload(
    Map<String, Object> payload
  ) {
    if (payload == null) {
      return;
    }

    Object existingSessionKey = payload.get('externalSessionKey');
    if (
      !(existingSessionKey instanceof String) ||
      String.isBlank((String) existingSessionKey)
    ) {
      payload.put('externalSessionKey', generateExternalSessionKey());
    }

    Map<String, Object> instanceConfig = new Map<String, Object>();
    if (
      payload.containsKey('instanceConfig') &&
      payload.get('instanceConfig') instanceof Map<String, Object>
    ) {
      instanceConfig.putAll(
        (Map<String, Object>) payload.get('instanceConfig')
      );
    }
    if (
      !instanceConfig.containsKey('endpoint') ||
      !(instanceConfig.get('endpoint') instanceof String) ||
      String.isBlank((String) instanceConfig.get('endpoint'))
    ) {
      try {
        instanceConfig.put(
          'endpoint',
          URL.getSalesforceBaseUrl().toExternalForm()
        );
      } catch (Exception ex) {
        // If the base URL cannot be resolved we leave the endpoint unset.
      }
    }
    payload.put('instanceConfig', instanceConfig);

    Object tzValue = payload.get('tz');
    if (!(tzValue instanceof String) || String.isBlank((String) tzValue)) {
      try {
        payload.put('tz', UserInfo.getTimeZone().getID());
      } catch (Exception ex) {
        // Ignore and leave timezone unset when unavailable.
      }
    }

    Boolean hasVariables =
      payload.containsKey('variables') &&
      payload.get('variables') instanceof List<Object> &&
      !((List<Object>) payload.get('variables')).isEmpty();
    if (!hasVariables) {
      List<Object> variables = new List<Object>();
      variables.add(
        new Map<String, Object>{
          'name' => '$Context.EndUserLanguage',
          'type' => 'Text',
          'value' => UserInfo.getLocale()
        }
      );
      variables.add(
        new Map<String, Object>{
          'name' => '$Context.EndUser.Id',
          'type' => 'Text',
          'value' => UserInfo.getUserId()
        }
      );
      variables.add(
        new Map<String, Object>{
          'name' => '$Context.EndUser.Type',
          'type' => 'Text',
          'value' => UserInfo.getUserType()
        }
      );
      payload.put('variables', variables);
    }

    Object featureSupport = payload.get('featureSupport');
    if (
      !(featureSupport instanceof String) ||
      String.isBlank((String) featureSupport)
    ) {
      payload.put('featureSupport', 'Streaming');
    }

    Map<String, Object> streamingCapabilities = new Map<String, Object>();
    if (
      payload.containsKey('streamingCapabilities') &&
      payload.get('streamingCapabilities') instanceof Map<String, Object>
    ) {
      streamingCapabilities.putAll(
        (Map<String, Object>) payload.get('streamingCapabilities')
      );
    }
    Boolean hasChunkTypes =
      streamingCapabilities.containsKey('chunkTypes') &&
      streamingCapabilities.get('chunkTypes') instanceof List<Object> &&
      !((List<Object>) streamingCapabilities.get('chunkTypes')).isEmpty();
    if (!hasChunkTypes) {
      streamingCapabilities.put('chunkTypes', new List<Object>{ 'Text' });
    }
    payload.put('streamingCapabilities', streamingCapabilities);
  }

  private static void enrichStartSessionResult(
    AgentforceStartSessionResult result
  ) {
    if (result == null || result.data == null) {
      return;
    }

    result.sessionId = preferString(
      result.sessionId,
      extractString(result.data, new List<String>{ 'sessionId', 'id' })
    );
    result.sessionUrl = preferString(
      result.sessionUrl,
      extractString(result.data, new List<String>{ 'sessionUrl', 'url' })
    );
    result.messagesUrl = preferString(
      result.messagesUrl,
      extractString(result.data, new List<String>{ 'messagesUrl' })
    );

    if (
      result.data.containsKey('session') &&
      result.data.get('session') instanceof Map<String, Object>
    ) {
      Map<String, Object> sessionMap = (Map<String, Object>) result.data.get(
        'session'
      );
      result.sessionId = preferString(
        result.sessionId,
        extractString(sessionMap, new List<String>{ 'sessionId', 'id' })
      );
      result.sessionUrl = preferString(
        result.sessionUrl,
        extractString(sessionMap, new List<String>{ 'sessionUrl', 'url' })
      );
      result.messagesUrl = preferString(
        result.messagesUrl,
        extractString(sessionMap, new List<String>{ 'messagesUrl' })
      );
    }

    if (
      String.isBlank(result.messagesUrl) && String.isNotBlank(result.sessionUrl)
    ) {
      String normalizedSessionUrl = result.sessionUrl.endsWith('/messages')
        ? result.sessionUrl
        : result.sessionUrl + '/messages';
      result.messagesUrl = normalizedSessionUrl;
    }

    if (
      String.isBlank(result.messagesUrl) && String.isNotBlank(result.sessionId)
    ) {
      String baseSessionsUrl = extractString(
        result.data,
        new List<String>{ 'baseSessionsUrl', 'sessionsUrl', 'endpoint' }
      );
      if (String.isNotBlank(baseSessionsUrl)) {
        result.messagesUrl = buildMessagesUrl(
          baseSessionsUrl,
          result.sessionId
        );
      }
    }
  }

  private static String buildMessagesUrl(String baseUrl, String sessionId) {
    if (String.isBlank(baseUrl) || String.isBlank(sessionId)) {
      return null;
    }

    String resolvedTemplate = applySessionPlaceholder(baseUrl, sessionId);
    if (resolvedTemplate != null && resolvedTemplate != baseUrl) {
      return resolvedTemplate;
    }

    String normalizedBase = baseUrl;
    while (normalizedBase.endsWith('/')) {
      normalizedBase = normalizedBase.substring(0, normalizedBase.length() - 1);
    }
    if (!normalizedBase.endsWith('/sessions')) {
      normalizedBase = normalizedBase + '/sessions';
    }

    return normalizedBase +
      '/' +
      EncodingUtil.urlEncode(sessionId, 'UTF-8') +
      '/messages';
  }

  private static String extractString(
    Map<String, Object> source,
    List<String> keys
  ) {
    if (source == null || keys == null) {
      return null;
    }
    for (String key : keys) {
      if (source.containsKey(key) && source.get(key) instanceof String) {
        String value = (String) source.get(key);
        if (String.isNotBlank(value)) {
          return value;
        }
      }
    }
    return null;
  }

  private static String preferString(String currentValue, String candidate) {
    return String.isNotBlank(currentValue) ? currentValue : candidate;
  }

  private static String generateExternalSessionKey() {
    Blob randomBlob = Crypto.generateDigest(
      'MD5',
      Blob.valueOf(String.valueOf(Crypto.getRandomLong()))
    );
    return EncodingUtil.convertToHex(randomBlob);
  }

  private static String applyAgentPlaceholder(String template, String botId) {
    if (String.isBlank(template)) {
      return template;
    }

    Boolean containsPlaceholder =
      template.contains('{0}') || template.contains('{botId}');
    if (!containsPlaceholder) {
      return template;
    }

    if (String.isBlank(botId)) {
      throw new AuraHandledException('Missing Agentforce bot configuration');
    }

    String encoded = EncodingUtil.urlEncode(botId, 'UTF-8');
    if (template.contains('{0}')) {
      template = template.replace('{0}', encoded);
    }
    if (template.contains('{botId}')) {
      template = template.replace('{botId}', encoded);
    }
    return template;
  }

  private static String applySessionPlaceholder(
    String template,
    String sessionId
  ) {
    if (String.isBlank(template)) {
      return template;
    }

    Boolean containsPlaceholder =
      template.contains('{0}') || template.contains('{sessionId}');
    if (!containsPlaceholder) {
      return template;
    }

    if (String.isBlank(sessionId)) {
      throw new AuraHandledException('Missing Agentforce session');
    }

    String encoded = EncodingUtil.urlEncode(sessionId, 'UTF-8');
    if (template.contains('{0}')) {
      template = template.replace('{0}', encoded);
    }
    if (template.contains('{sessionId}')) {
      template = template.replace('{sessionId}', encoded);
    }
    return template;
  }

  public class AgentforceChatConfig {
    @AuraEnabled
    public String endpointUrl { get; set; }

    @AuraEnabled
    public String startSessionEndpointUrl { get; set; }

    @AuraEnabled
    public String messagesEndpointUrl { get; set; }

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
      String startSessionEndpointUrl,
      String messagesEndpointUrl,
      String botId,
      String authorizationHeaderValue,
      String tokenEndpointUrl,
      String consumerKey,
      String consumerSecret,
      String username,
      String password
    ) {
      this.startSessionEndpointUrl = startSessionEndpointUrl;
      this.endpointUrl = startSessionEndpointUrl;
      this.messagesEndpointUrl = messagesEndpointUrl;
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

  public class AgentforceStartSessionResult {
    @AuraEnabled
    public Integer statusCode { get; set; }

    @AuraEnabled
    public String body { get; set; }

    @AuraEnabled
    public Map<String, Object> data { get; set; }

    @AuraEnabled
    public String sessionId { get; set; }

    @AuraEnabled
    public String sessionUrl { get; set; }

    @AuraEnabled
    public String messagesUrl { get; set; }

    @AuraEnabled
    public String externalSessionKey { get; set; }
  }

  private class AgentforceErrorResponse {
    public String message { get; set; }
  }
}
