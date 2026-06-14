import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class KodeshModeDelegate extends WatchUi.BehaviorDelegate {
    private const EXIT_TAPS = 5;
    private const EXIT_WINDOW_MS = 5000; // 5 seconds
    private const EVENT_DEBOUNCE_MS = 500;

    private var _exitTapCount as Number = 0;
    private var _exitWindowStart as Number = 0;
    private var _lastKeyTime as Number = 0;

    function initialize() {
        BehaviorDelegate.initialize();
    }

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
        if (ShabbatMode.isHebrew()) {
            ShabbatMode.setStatus(WatchUi.loadResource(Rez.Strings.TextExitInstructionHe));
        } else {
            ShabbatMode.setStatus(WatchUi.loadResource(Rez.Strings.TextExitInstructionEn));
        }
        WatchUi.requestUpdate();
    }

    function handlePrimaryPressed() as Void {
        var now = System.getTimer();

        if ((now - _lastKeyTime) < EVENT_DEBOUNCE_MS) {
            return;
        }

        _lastKeyTime = now;

        if (ShabbatMode.isEnabled()) {
            if (_exitWindowStart == 0 || (now - _exitWindowStart) > EXIT_WINDOW_MS) {
                _exitTapCount = 0;
                _exitWindowStart = now;
            }

            _exitTapCount++;

            if (_exitTapCount >= EXIT_TAPS) {
                _exitTapCount = 0;
                _exitWindowStart = 0;
                ShabbatMode.disable();
                WatchUi.requestUpdate();
                return;
            }

            if (ShabbatMode.isHebrew()) {
                ShabbatMode.setStatus(WatchUi.loadResource(Rez.Strings.TextExitProgressHe) + _exitTapCount + "/" + EXIT_TAPS);
            } else {
                ShabbatMode.setStatus(WatchUi.loadResource(Rez.Strings.TextExitProgressEn) + _exitTapCount + "/" + EXIT_TAPS);
            }
            WatchUi.requestUpdate();
        } else {
            var enabled = ShabbatMode.enable();
            if (!enabled) {
                openGuide();
                return;
            }
            WatchUi.requestUpdate();
        }
    }

    function openMainMenuDebounced() as Boolean {
        var now = System.getTimer();

        if ((now - _lastKeyTime) < EVENT_DEBOUNCE_MS) {
            return true;
        }

        _lastKeyTime = now;
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

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return openMainMenuDebounced();
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (isMenuKey(keyEvent)) {
            return openMainMenuDebounced();
        }

        return false;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (isMenuKey(keyEvent)) {
            return openMainMenuDebounced();
        }

        if (isEnterKey(keyEvent)) {
            handlePrimaryPressed();
            return true;
        }

        if (isBackKey(keyEvent) && ShabbatMode.isEnabled()) {
            showExitInstruction();
            return true;
        }

        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (isEnterKey(keyEvent)) {
            return true;
        }

        if (isBackKey(keyEvent) && ShabbatMode.isEnabled()) {
            return true;
        }

        return false;
    }

    function onSelect() as Boolean {
        handlePrimaryPressed();
        return true;
    }

    function openMainMenu() as Boolean {
        return showPhoneSettingsOnly();
    }
}

var gLastInteractionTime as Number = 0;
