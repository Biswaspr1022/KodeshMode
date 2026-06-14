import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;

class ShabbatTransitionView extends WatchUi.View {
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimerFinished), 2000, false);
    }

    function onTimerFinished() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var text = ShabbatMode.isHebrew() 
            ? WatchUi.loadResource(Rez.Strings.TextTurningOnHe) 
            : WatchUi.loadResource(Rez.Strings.TextTurningOnEn);

        var font = AppFonts.getHebrewTextFont();
        if (font == null) {
            font = Graphics.FONT_MEDIUM;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2, 
            dc.getHeight() / 2, 
            font, 
            text as String, 
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
