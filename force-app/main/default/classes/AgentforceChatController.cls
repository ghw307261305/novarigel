public with sharing class AgentforceChatController {
    @AuraEnabled(cacheable=true)
    public static AgentforceChatConfig getConfig() {
        Agentforce_Config__mdt config = Agentforce_Config__mdt.getInstance('Default');
        if (config == null) {
            return new AgentforceChatConfig('', '');
        }
        return new AgentforceChatConfig(config.Endpoint_Url__c, config.Bot_Id__c);
    }

    public class AgentforceChatConfig {
        @AuraEnabled
        public String endpointUrl { get; set; }

        @AuraEnabled
        public String botId { get; set; }

        public AgentforceChatConfig(String endpointUrl, String botId) {
            this.endpointUrl = endpointUrl;
            this.botId = botId;
        }
    }
}
