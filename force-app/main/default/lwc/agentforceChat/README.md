# Agentforce Chat LWC

This Lightning Web Component renders an Agentforce-powered chat experience for Experience Cloud sites and standard Lightning pages.

## Setup

1. **Deploy metadata**
   - Deploy the `Agentforce_Config__mdt` custom metadata type, default record, Apex controller, and the `agentforceChat` LWC to your org.
2. **Configure Agentforce connection and authentication**
   - Create a **Named Credential** that targets the Agentforce Agent API host (for example, `Agentforce_Named_Credential`). Store the API host URL in the Named Credential and, if using a static token, save it as a bearer token in the `Authorization` header value field described below. Grant the appropriate permission set so that the running user can access the Named Credential.
   - Update the `Agentforce_Config.Default` custom metadata record with your API settings:
     - `Endpoint Url` – the API path used for chat messages (for example, `/agentforce`). Absolute URLs are accepted; the controller will strip the host before performing the callout through the Named Credential.
     - `Bot Id` – the Agentforce bot identifier to target.
     - `Named Credential` – the API name of the Named Credential you created.
     - `Authorization Header Value` – optional authorization header value (for example, `Bearer 00Dxxx!AQw...`). Leave blank when the Named Credential handles authentication automatically.
   - Optionally override the endpoint or bot ID per component instance through the Experience Builder property panel.
3. **Assign permissions**
   - Ensure that the running users have access to invoke the `AgentforceChatController` Apex class and read the `Agentforce_Config__mdt` metadata. Assign a permission set or profile that includes the Named Credential if it is marked as requiring explicit access.
4. **Experience Builder**
   - In Experience Builder, open the desired page and drag the **Agentforce Chat** component from the custom components section onto the canvas.
   - Publish the site after configuration.

## Runtime behavior

- Messages sent from the composer are posted to the configured Agentforce REST endpoint along with the existing transcript.
- Agent responses are appended to the transcript when the API returns.
- Errors are surfaced in the status banner and echoed into the transcript for quick diagnosis.

## Testing

Run `npm test agentforceChat` (or `npm test` for the full suite) to execute the Jest tests that verify message rendering and error-handling logic.
