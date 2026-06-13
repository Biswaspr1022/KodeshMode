import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class KodeshModeDelegate extends WatchUi.BehaviorDelegate {
    private const EXIT_HOLD_MS = 5000;
    private const EVENT_DEBOUNCE_MS = 700;
    private var _enterDownAt as Number = 0;

    function initialize() {
        BehaviorDelegate.initialize();
    }

    // Settings are controlled only from the phone app settings.
    // The watch no longer opens an on-device settings menu.
    function onMenu() as Boolean {
        return showPhoneSettingsOnly();
    }

    function isEnterKey(keyEvent) as Boolean {
        return keyEvent != null && keyEvent.getKey() == WatchUi.KEY_ENTER;
    }

    function isBackKey(keyEvent) as Boolean {
        return keyEvent != null && keyEvent.getKey() == WatchUi.KEY_ESC;
    }

    function isMenuKey(keyEvent) as Boolean {
        if (keyEvent == null) {
            return false;
        }

        var key = keyEvent.getKey();

        if (key == WatchUi.KEY_MENU) {
            return true;
        }

        return false;
    }

    function showExitInstruction() as Void {
        ShabbatMode.setStatus("Hold GPS 5 sec to exit");
        WatchUi.requestUpdate();
    }

    function handleEnterPressed() as Void {
        var now = System.getTimer();
        if ((now - gLastInteractionTime) < EVENT_DEBOUNCE_MS) {
            return;
        }
        _enterDownAt = now;
    }

    function handleEnterReleased() as Void {
        var now = System.getTimer();
        var heldMs = 0;

        if (_enterDownAt == 0 || (now - gLastInteractionTime) < EVENT_DEBOUNCE_MS) {
            _enterDownAt = 0;
            return;
        }

        heldMs = now - _enterDownAt;
        _enterDownAt = 0;
        gLastInteractionTime = now;

        if (ShabbatMode.isEnabled()) {
            if (heldMs >= EXIT_HOLD_MS) {
                ShabbatMode.disable();
            } else {
                showExitInstruction();
                return;
            }
        } else {
            // Upper-right / START / ENTER button enters Shabbat Mode.
            // On touch watches such as Venu/vivoactive this is the top-right button.
            // On Instinct/fenix/Forerunner this keeps the existing START/GPS behavior.
            var enabled = ShabbatMode.enable();
            if (!enabled) {
                // Pre-conditions not met — show the guide so the user
                // knows what needs to be done before Shabbat Mode can start.
                openGuide();
                return;
            }
        }

        WatchUi.requestUpdate();
    }

    function openMainMenuDebounced() as Boolean {
        var now = System.getTimer();

        if ((now - gLastInteractionTime) < EVENT_DEBOUNCE_MS) {
            return true;
        }

        gLastInteractionTime = now;
        return showPhoneSettingsOnly();
    }

    function showPhoneSettingsOnly() as Boolean {
        if (ShabbatMode.isEnabled()) {
            showExitInstruction();
        } else {
            ShabbatMode.setStatus(ShabbatMode.settingsOnPhoneText());
            WatchUi.requestUpdate();
        }

        return true;
    }

    // Block BACK while Shabbat Mode is active so the user does not leave
    // the app by accident during Shabbat Mode.
    function onBack() as Boolean {
        if (ShabbatMode.isEnabled()) {
            showExitInstruction();
            return true;
        }

        return false;
    }

    function openGuide() as Boolean {
        var guide = new GuideView();
        WatchUi.pushView(guide, new GuideDelegate(guide), WatchUi.SLIDE_LEFT);
        return true;
    }

    // Long press is not used for settings. Settings are phone-only.
    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return openMainMenuDebounced();
    }

    // Some device profiles send a plain key event instead of the split
    // onKeyPressed/onKeyReleased pair. Handle menu keys here as a fallback.
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (isMenuKey(keyEvent)) {
            return openMainMenuDebounced();
        }

        return false;
    }

    // Physical button support:
    // - KEY_ENTER / upper-right toggles Shabbat Mode.
    // - Menu/middle shows a phone-settings-only message.
    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (isMenuKey(keyEvent)) {
            return openMainMenuDebounced();
        }

        if (isEnterKey(keyEvent)) {
            handleEnterPressed();
            return true;
        }

        if (isBackKey(keyEvent) && ShabbatMode.isEnabled()) {
            showExitInstruction();
            return true;
        }

        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (isMenuKey(keyEvent)) {
            return openMainMenuDebounced();
        }

        if (isEnterKey(keyEvent)) {
            handleEnterReleased();
            return true;
        }

        if (isBackKey(keyEvent) && ShabbatMode.isEnabled()) {
            showExitInstruction();
            return true;
        }

        return false;
    }

    // Fallback for devices/simulator paths that only generate BehaviorDelegate
    // select events. Keep this as Shabbat Mode, not settings, so the upper-right
    // Venu/vivoactive button can enter/exit Shabbat Mode.
    function onSelect() as Boolean {
        var now = System.getTimer();

        if ((now - gLastInteractionTime) < EVENT_DEBOUNCE_MS) {
            return true;
        }

        gLastInteractionTime = now;

        if (ShabbatMode.isEnabled()) {
            showExitInstruction();
        } else {
            var enabled = ShabbatMode.enable();
            if (!enabled) {
                openGuide();
                return true;
            }
            WatchUi.requestUpdate();
        }

        return true;
    }

    function openMainMenu() as Boolean {
        return showPhoneSettingsOnly();
    }
}

var gLastInteractionTime as Number = 0;
