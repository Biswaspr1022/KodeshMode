import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.Lang;

class ShabbatExitView extends WatchUi.View {
    private var _tapCount as Number;
    private const EXIT_TAPS = 5;

    function initialize(tapCount as Number) {
        View.initialize();
        _tapCount = tapCount;
    }

    function updateTapCount(tapCount as Number) as Void {
        _tapCount = tapCount;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var text = "";
        if (ShabbatMode.isHebrew()) {
            text = WatchUi.loadResource(Rez.Strings.TextExitProgressHe) as String + _tapCount + "/" + EXIT_TAPS;
        } else {
            text = WatchUi.loadResource(Rez.Strings.TextExitProgressEn) as String + _tapCount + "/" + EXIT_TAPS;
        }

        var font = AppFonts.getHebrewTextFont();
        if (font == null) {
            font = Graphics.FONT_MEDIUM;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2, 
            dc.getHeight() / 2, 
            font, 
            text, 
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
