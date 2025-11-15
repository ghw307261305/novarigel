public with sharing class PromptFlowInvokerExample {
  public class PromptFlowResponse {
    @AuraEnabled
    public String llmCompletion;

    @AuraEnabled
    public Map<String, Object> flowOutputs;
  }

  @AuraEnabled(cacheable=false)
  public static PromptFlowResponse runPromptFlow(
    String productIdentifier,
    String extraInstruction
  ) {
    Map<String, Object> inputs = new Map<String, Object>{
      'var_productIdentifier' => productIdentifier
    };

    Flow.Interview interview = Flow.Interview.createInterview(
      'testpromptflow',
      inputs
    );

    if (!String.isBlank(extraInstruction)) {
      Flow.PromptMessageInput additionalInstruction = new Flow.PromptMessageInput();
      additionalInstruction.messageType = Flow.PromptMessageType.AdditionalInstruction;
      additionalInstruction.text = extraInstruction;
      interview.addPromptMessage(additionalInstruction);
    }

    interview.start();

    Flow.PromptResult promptResult = interview.getPromptResult();

    PromptFlowResponse response = new PromptFlowResponse();
    response.llmCompletion = promptResult != null
      ? promptResult.completion
      : null;
    response.flowOutputs = interview.getVariables();
    return response;
  }
}
