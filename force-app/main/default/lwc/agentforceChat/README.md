# Agentforce Chat LWC

This Lightning Web Component renders an Agentforce-powered chat experience for Experience Cloud sites and standard Lightning pages.

## Setup

1. **Deploy metadata**
   - Deploy the `Agentforce_Config__mdt` custom metadata type, default record, Apex controller, and the `agentforceChat` LWC to your org.
2. **Configure Agentforce connection and authentication**
   - Confirm that the OAuth and chat endpoints you plan to reach are added to Remote Site Settings (or otherwise permitted for callouts).
    - Update the `Agentforce_Config.Default` custom metadata record with your API settings:
     - `Start Session Endpoint Url` – the REST endpoint that creates a new chat session (for example, `https://api.salesforce.com/einstein/ai-agent/v1/agents/{0}/sessions`). The `{0}` token is replaced with the configured Agent ID (bot ID) automatically. This value is used as the component default and can still be overridden per component instance in Experience Builder.
     - `Messages Endpoint Url` – the REST endpoint (or base URL) that receives chat messages once a session exists (for example, `https://api.salesforce.com/einstein/ai-agent/v1/sessions/{0}/messages`). The `{0}` token is replaced with the active session ID automatically before the request is sent.
     - `Chat Endpoint Url` – retained for backward compatibility. When populated, it is used as a fallback for the start-session and messages endpoints.
     - `Bot Id` – the Agentforce bot identifier to target.
     - `Endpoint Url` – the OAuth token endpoint that issues access tokens (for example, `https://example.com/oauth/token`).
    - `Consumer Key` and `Consumer Secret` – the client credentials for the OAuth connected app used in the client credentials flow.
     - `Authorization Header Value` – optional additional header value to include with the chat request. When populated, the value is sent in an `X-Agentforce-Authorization` header alongside the bearer token.
   - Optionally override the chat endpoint or bot ID per component instance through the Experience Builder property panel.
3. **Assign permissions**
   - Ensure that the running users have access to invoke the `AgentforceChatController` Apex class and read the `Agentforce_Config__mdt` metadata. Grant access to the Remote Site Settings (or other callout permissions) required for your integration.
4. **Experience Builder**
   - In Experience Builder, open the desired page and drag the **Agentforce Chat** component from the custom components section onto the canvas.
   - Publish the site after configuration.

## Runtime behavior

- Messages sent from the composer are posted to the configured Agentforce REST endpoint along with the existing transcript. Before each chat callout, the controller performs the OAuth client credentials flow using the stored client ID and secret and passes the resulting bearer token to the chat service.
- Agent responses are appended to the transcript when the API returns.
- Status updates (sending state and errors) appear inline within the agent transcript so customers can track progress without a
  separate header.

## Testing

Run `npm test agentforceChat` (or `npm test` for the full suite) to execute the Jest tests that verify message rendering and error-handling logic.
