# Quickstart: cute-entry-gateway

This guide explains how to preview and test the cute entry gateway in the development environment.

## Prerequisites

- Flutter SDK installed and configured.
- The application running locally (`flutter run -d chrome`).

## Testing the Gateway Flow

1. **Initial Load**: 
   - Refresh the web application.
   - You should immediately see the overwhelmingly cute, pinkish environment.
   - Verify the entry element (door/lock) bounces or pops into view.

2. **Incorrect Passcode**:
   - Tap/click the passcode input area.
   - Enter an incorrect 4-digit code (e.g., `1234`).
   - Verify the lock shakes playfully and the input clears automatically.
   - Ensure no harsh "corporate" error messages appear.

3. **Successful Entry & Reveal**:
   - Enter the hardcoded passcode: `1111`.
   - Verify the lock pops open (e.g., with hearts) or the door swings wide.
   - Watch the transition: The screen should NOT cut abruptly.
   - Verify the main dashboard gracefully animates into view (blooming or petal shower effect).

## Development Notes

- The gateway is a visual overlay. It does not authenticate with a backend.
- To bypass the gateway quickly during further development, you can temporarily change the initial state from `GatewayState.initialLoad` to `GatewayState.complete` in the state controller.
