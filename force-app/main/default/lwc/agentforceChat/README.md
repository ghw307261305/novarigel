# Agentforce Chat LWC

This Lightning Web Component renders an Agentforce-powered chat experience for Experience Cloud sites and standard Lightning pages.

## Setup

1. **Deploy metadata**
   - Deploy the `Agentforce_Config__mdt` custom metadata type, default record, Apex controller, and the `agentforceChat` LWC to your org.
2. **Configure Agentforce connection and authentication**
   - Confirm that the OAuth and chat endpoints you plan to reach are added to Remote Site Settings (or otherwise permitted for callouts).
   - Update the `Agentforce_Config.Default` custom metadata record with your API settings:
     - `Chat Endpoint Url` – the REST endpoint that accepts chat messages (for example, `https://example.com/agentforce`). This value is used as the component default and can still be overridden per component instance in Experience Builder.
     - `Bot Id` – the Agentforce bot identifier to target.
     - `Endpoint Url` – the OAuth token endpoint that issues access tokens (for example, `https://example.com/oauth/token`).
     - `Consumer Key` and `Consumer Secret` – the client credentials for the OAuth connected app.
     - `Username` and `Password` – the credentials of the Agentforce integration user. Include any required security token as part of the password value.
     - `Authorization Header Value` – optional additional header value to include with the chat request. When populated, the value is sent in an `X-Agentforce-Authorization` header alongside the bearer token.
   - Optionally override the chat endpoint or bot ID per component instance through the Experience Builder property panel.
3. **Assign permissions**
   - Ensure that the running users have access to invoke the `AgentforceChatController` Apex class and read the `Agentforce_Config__mdt` metadata. Grant access to the Remote Site Settings (or other callout permissions) required for your integration.
4. **Experience Builder**
   - In Experience Builder, open the desired page and drag the **Agentforce Chat** component from the custom components section onto the canvas.
   - Publish the site after configuration.

## Runtime behavior

- Messages sent from the composer are posted to the configured Agentforce REST endpoint along with the existing transcript. Before each chat callout, the controller performs the OAuth username-password flow using the stored credentials and passes the resulting bearer token to the chat service.
- Agent responses are appended to the transcript when the API returns.
- Errors are surfaced in the status banner and echoed into the transcript for quick diagnosis.

## Testing

Run `npm test agentforceChat` (or `npm test` for the full suite) to execute the Jest tests that verify message rendering and error-handling logic.
