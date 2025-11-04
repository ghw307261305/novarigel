@IsTest
private class AgentforceChatControllerTest {
  private class RecordingHttpCalloutMock implements HttpCalloutMock {
    private List<HttpResponse> responses;
    public List<HttpRequest> requests = new List<HttpRequest>();
    private Integer index = 0;

    RecordingHttpCalloutMock(List<HttpResponse> responses) {
      this.responses = responses;
    }

    public HTTPResponse respond(HTTPRequest req) {
      requests.add(req);
      if (responses.isEmpty()) {
        HttpResponse emptyResponse = new HttpResponse();
        emptyResponse.setStatusCode(200);
        return emptyResponse;
      }
      if (index >= responses.size()) {
        return responses[responses.size() - 1];
      }
      return responses[index++];
    }
  }

  @IsTest
  static void startSessionIncludesConfiguredOverrides() {
    Test.setCustomMetadata(
      Agentforce_Config__mdt.SObjectType,
      'Default',
      new Map<String, Object>{
        'DeveloperName' => 'Default',
        'MasterLabel' => 'Default',
        'Bot_Id__c' => 'test-bot',
        'Endpoint_Url__c' => 'https://example.com/oauth/token',
        'Start_Session_Endpoint_Url__c' => 'https://example.com/agents/{0}/sessions',
        'Messages_Endpoint_Url__c' => 'https://example.com/sessions/{0}/messages',
        'Chat_Endpoint_Url__c' => 'https://example.com/agentforce',
        'Consumer_Key__c' => 'client-id',
        'Consumer_Secret__c' => 'client-secret',
        'Start_Session_Parameters__c' => '{"context":{"origin":"AgentforceBuilder"},"sessionConfig":{"mode":"Debug"}}'
      }
    );

    HttpResponse tokenResponse = buildJsonResponse(
      200,
      '{"access_token":"token-123"}'
    );
    HttpResponse startSessionResponse = buildJsonResponse(
      200,
      '{"sessionId":"session-1","messagesUrl":"https://example.com/sessions/session-1/messages"}'
    );

    RecordingHttpCalloutMock mock = new RecordingHttpCalloutMock(
      new List<HttpResponse>{ tokenResponse, startSessionResponse }
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    AgentforceChatController.AgentforceStartSessionResult result = AgentforceChatController.startSession(
      null,
      new Map<String, Object>{}
    );
    Test.stopTest();

    System.assertEquals('session-1', result.sessionId);
    System.assertEquals(2, mock.requests.size());

    HttpRequest startRequest = mock.requests[1];
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      startRequest.getBody()
    );
    System.assertEquals(
      'AgentforceBuilder',
      ((Map<String, Object>) payload.get('context')).get('origin')
    );
    System.assertEquals('Debug', payload.get('mode'));
    System.assert(payload.containsKey('externalSessionKey'));
  }

  @IsTest
  static void sendMessageIncludesConfiguredOverrides() {
    Test.setCustomMetadata(
      Agentforce_Config__mdt.SObjectType,
      'Default',
      new Map<String, Object>{
        'DeveloperName' => 'Default',
        'MasterLabel' => 'Default',
        'Bot_Id__c' => 'test-bot',
        'Endpoint_Url__c' => 'https://example.com/oauth/token',
        'Start_Session_Endpoint_Url__c' => 'https://example.com/agents/{0}/sessions',
        'Messages_Endpoint_Url__c' => 'https://example.com/sessions/{sessionId}/messages',
        'Chat_Endpoint_Url__c' => 'https://example.com/agentforce',
        'Consumer_Key__c' => 'client-id',
        'Consumer_Secret__c' => 'client-secret',
        'Send_Message_Parameters__c' => '{"metadata":{"origin":"AgentforceBuilder"},"message":{"mode":"Debug"}}'
      }
    );

    HttpResponse tokenResponse = buildJsonResponse(
      200,
      '{"access_token":"token-123"}'
    );
    HttpResponse messageResponse = buildJsonResponse(
      200,
      '{"messages":[{"type":"Inform","message":"Hello"}]}'
    );

    RecordingHttpCalloutMock mock = new RecordingHttpCalloutMock(
      new List<HttpResponse>{ tokenResponse, messageResponse }
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    AgentforceChatController.sendMessage(
      'Hi',
      new List<AgentforceChatController.AgentforceChatTranscriptEntry>(),
      null,
      null,
      'session-abc'
    );
    Test.stopTest();

    System.assertEquals(2, mock.requests.size());
    HttpRequest messageRequest = mock.requests[1];
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      messageRequest.getBody()
    );
    System.assertEquals(
      'AgentforceBuilder',
      ((Map<String, Object>) payload.get('metadata')).get('origin')
    );
    Map<String, Object> messageSection = (Map<String, Object>) payload.get(
      'message'
    );
    System.assertEquals('Debug', messageSection.get('mode'));
    System.assertEquals('Hi', messageSection.get('text'));
  }

  private static HttpResponse buildJsonResponse(
    Integer statusCode,
    String body
  ) {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(statusCode);
    response.setBody(body);
    response.setHeader('Content-Type', 'application/json');
    return response;
  }
}
