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

    if (!String.isBlank(extraInstruction)) {
      inputs.put('var_additionalInstruction', extraInstruction);
    }

    Flow.Interview interview = Flow.Interview.createInterview(
      'testpromptflow',
      inputs
    );

    interview.start();

    PromptFlowResponse response = new PromptFlowResponse();
    response.flowOutputs = new Map<String, Object>();

    List<String> outputVariableNames = new List<String>{
      'ReturnOrderProcess_success',
      'ReturnOrderProcess_status',
      'ReturnOrderProcess_primaryMessage',
      'ReturnOrderProcess_secondaryMessage',
      'ReturnOrderProcess_returnOrderNumber',
      'ReturnOrderProcess_caseNumber',
      'ReturnOrderProcess_evaluation'
    };

    for (String variableName : outputVariableNames) {
      Object value;
      try {
        value = interview.getVariableValue(variableName);
      } catch (Exception ex) {
        continue;
      }

      if (value != null) {
        response.flowOutputs.put(variableName, value);
      }
    }

    Object primaryMessage = response.flowOutputs.get(
      'ReturnOrderProcess_primaryMessage'
    );
    response.llmCompletion = primaryMessage instanceof String
      ? (String) primaryMessage
      : null;

    return response;
  }
}
