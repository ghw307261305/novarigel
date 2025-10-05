# Agentforce Chat LWC

This Lightning Web Component renders an Agentforce-powered chat experience for Experience Cloud sites and standard Lightning pages.

## Setup

1. **Deploy metadata**
   - Deploy the `Agentforce_Config__mdt` custom metadata type, default record, Apex controller, and the `agentforceChat` LWC to your org.
2. **Configure Agentforce connection**
   - Update the `Agentforce_Config.Default` custom metadata record with your Agentforce endpoint URL and bot identifier. These values are read automatically when component properties are left blank.
   - Optionally override the endpoint or bot ID per component instance through the Experience Builder property panel.
3. **Experience Builder**
   - In Experience Builder, open the desired page and drag the **Agentforce Chat** component from the custom components section onto the canvas.
   - Publish the site after configuration.

## Runtime behavior

- Messages sent from the composer are posted to the configured Agentforce REST endpoint along with the existing transcript.
- Agent responses are appended to the transcript when the API returns.
- Errors are surfaced in the status banner and echoed into the transcript for quick diagnosis.

## Testing

Run `npm test agentforceChat` (or `npm test` for the full suite) to execute the Jest tests that verify message rendering and error-handling logic.
