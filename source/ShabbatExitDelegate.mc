import Toybox.WatchUi;
import Toybox.System;
import Toybox.Timer;
import Toybox.Lang;

class ShabbatExitDelegate extends WatchUi.BehaviorDelegate {
    private var _view as ShabbatExitView;
    private var _tapCount as Number;
    private const EXIT_TAPS = 5;
    private const TIMEOUT_MS = 5000;
    private var _timer as Timer.Timer?;

    function initialize(view as ShabbatExitView, initialTapCount as Number) {
        BehaviorDelegate.initialize();
        _view = view;
        _tapCount = initialTapCount;
        _timer = new Timer.Timer();
        _timer.start(method(:onTimeout), TIMEOUT_MS, false);
    }

    function onTimeout() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function cleanupTimer() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function handleTap() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer.start(method(:onTimeout), TIMEOUT_MS, false);
        }

        _tapCount++;
        _view.updateTapCount(_tapCount);

        if (_tapCount >= EXIT_TAPS) {
            cleanupTimer();
            ShabbatMode.disable();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onSelect() as Boolean {
        handleTap();
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            handleTap();
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        // Back button cancels exit
        cleanupTimer();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
