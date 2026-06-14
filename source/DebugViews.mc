import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application.Storage;

// ---------------------------------------------------------------------------
// GuideView — a simple paged on-watch user guide.
// 3 pages: (1) How to enable, (2) While active, (3) Screen protection.
// Navigation: ENTER / SELECT advances to next page; BACK goes to previous
// page (or pops back to the main screen from page 1).
// ---------------------------------------------------------------------------

class GuideDelegate extends WatchUi.BehaviorDelegate {
    private var _view as GuideView;

    function initialize(view as GuideView) {
        BehaviorDelegate.initialize();
        _view = view;
        gLastInteractionTime = System.getTimer();
    }

    function onBack() as Boolean {
        var now = System.getTimer();
        if (now - gLastInteractionTime < 400) {
            return true;
        }
        gLastInteractionTime = now;

        if (_view.getPage() > 0) {
            _view.prevPage();
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() as Boolean {
        var now = System.getTimer();
        if (now - gLastInteractionTime < 400) {
            return true;
        }
        gLastInteractionTime = now;

        if (_view.getPage() < GuideView.PAGE_COUNT - 1) {
            _view.nextPage();
            WatchUi.requestUpdate();
        } else {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN || key == WatchUi.KEY_ENTER || key == WatchUi.KEY_UP || key == WatchUi.KEY_ESC) {
            return true;
        }
        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN || key == WatchUi.KEY_ENTER) {
            return onSelect();
        }
        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_ESC) {
            return onBack();
        }
        return false;
    }
    
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (swipeEvent.getDirection() == WatchUi.SWIPE_LEFT) {
            return onSelect();
        }
        if (swipeEvent.getDirection() == WatchUi.SWIPE_RIGHT) {
            return onBack();
        }
        return false;
    }
}

class GuideView extends WatchUi.View {
    static const PAGE_COUNT = 3;
    private var _page as Number = 0;
    private var _hebrewFont;

    function initialize() {
        View.initialize();
        var sys = System.getDeviceSettings();
        if (sys.screenWidth <= 200) {
            _hebrewFont = AppFonts.getCustomFontForFamilyAndSize("varela", "clock_size_18");
            if (_hebrewFont == null) {
                _hebrewFont = AppFonts.getHebrewTextFont();
            }
        } else {
            _hebrewFont = AppFonts.getHebrewTextFont();
        }
    }

    function getPage() as Number { return _page; }
    function nextPage() as Void { _page = _page + 1; }
    function prevPage() as Void { _page = _page - 1; }

    function onLayout(dc as Graphics.Dc) as Void {}

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var isHe = ShabbatMode.isHebrew();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_page == 0) {
            drawPage0(dc, w, h, isHe);
        } else if (_page == 1) {
            drawPage1(dc, w, h, isHe);
        } else {
            drawPage2(dc, w, h, isHe);
        }

        drawPageDots(dc, w, h);
    }

    // -- Page helpers --------------------------------------------------------

    function cx(w as Number) as Number { return w / 2; }

    function drawTitle(dc as Graphics.Dc, w as Number, y as Number, text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx(w), y, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawHebrewLine(dc as Graphics.Dc, w as Number, y as Number, text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx(w), y, _hebrewFont, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawLine(dc as Graphics.Dc, w as Number, y as Number, text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx(w), y, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawDivider(dc as Graphics.Dc, w as Number, y as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w / 5, y, (w * 4) / 5, y);
    }

    function drawPageDots(dc as Graphics.Dc, w as Number, h as Number) as Void {
        var dotR = 3;
        var gap = 10;
        var totalW = PAGE_COUNT * (dotR * 2) + (PAGE_COUNT - 1) * (gap - dotR * 2);
        var startX = (w - totalW) / 2;
        var dotY = h - 10;

        for (var i = 0; i < PAGE_COUNT; i++) {
            var dotX = startX + i * gap + dotR;
            if (i == _page) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, dotY, dotR);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dotX, dotY, dotR);
            }
        }
    }

    // -- Page 0: How to enable -----------------------------------------------
    function drawPage0(dc as Graphics.Dc, w as Number, h as Number, isHe as Boolean) as Void {
        var topY = (h.toFloat() * 0.22f).toNumber();
        var lineH = (h.toFloat() * 0.11f).toNumber();

        if (isHe) {
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideEnableHe), Graphics.COLOR_YELLOW);
        } else {
            drawTitle(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideEnableEn), Graphics.COLOR_YELLOW);
        }

        topY += lineH - 4;
        drawDivider(dc, w, topY);
        topY += 14;

        if (isHe) {
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuidePressStartHe), Graphics.COLOR_WHITE);
            topY += lineH;
            drawDivider(dc, w, topY);
            topY += 12;
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBeforeHe), Graphics.COLOR_LT_GRAY);
            topY += lineH - 4;
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBTHe), Graphics.COLOR_WHITE);
            topY += lineH - 6;
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideActivityHe), Graphics.COLOR_WHITE);
        } else {
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuidePressStartEn), Graphics.COLOR_WHITE);
            topY += lineH;
            drawDivider(dc, w, topY);
            topY += 12;
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBeforeEn), Graphics.COLOR_LT_GRAY);
            topY += lineH - 4;
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBTEn), Graphics.COLOR_WHITE);
            topY += lineH - 6;
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideActivityEn), Graphics.COLOR_WHITE);
        }
    }

    // -- Page 1: While Shabbat Mode is active --------------------------------
    function drawPage1(dc as Graphics.Dc, w as Number, h as Number, isHe as Boolean) as Void {
        var topY = (h.toFloat() * 0.22f).toNumber();
        var lineH = (h.toFloat() * 0.11f).toNumber();

        if (isHe) {
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideWhileActiveHe), Graphics.COLOR_YELLOW);
        } else {
            drawTitle(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideWhileActiveEn), Graphics.COLOR_YELLOW);
        }

        topY += lineH - 4;
        drawDivider(dc, w, topY);
        topY += 14;

        if (isHe) {
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBackBlockedHe), Graphics.COLOR_LT_GRAY);
            topY += lineH - 2;
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideToExitHe), Graphics.COLOR_LT_GRAY);
            topY += lineH - 4;
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideActionHe), Graphics.COLOR_GREEN);
            topY += lineH - 6;
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuide5TimesHe), Graphics.COLOR_GREEN);
        } else {
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBackBlockedEn), Graphics.COLOR_LT_GRAY);
            topY += lineH;
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideToExitEn), Graphics.COLOR_LT_GRAY);
            topY += lineH - 4;
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideActionEn), Graphics.COLOR_GREEN);
            topY += lineH - 6;
            drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuide5TimesEn), Graphics.COLOR_GREEN);
        }
    }

    function drawPage2(dc as Graphics.Dc, w as Number, h as Number, isHe as Boolean) as Void {
        var topY = (h.toFloat() * 0.22f).toNumber();
        var lineH = (h.toFloat() * 0.11f).toNumber();

        if (isHe) {
            drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideProtectionHe), Graphics.COLOR_YELLOW);
        } else {
            drawTitle(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideProtectionEn), Graphics.COLOR_YELLOW);
        }

        topY += lineH - 4;
        drawDivider(dc, w, topY);
        topY += 14;

        var isAmoled = deviceRequiresBurnInProtection(System.getDeviceSettings());
        var isProtectorOn = KodeshSettings.getBool("screenProtector", true);

        if (isHe) {
            if (isAmoled) {
                drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideAmoledHe), Graphics.COLOR_LT_GRAY);
                topY += lineH - 4;
                if (isProtectorOn) {
                    drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBurnInOnHe), Graphics.COLOR_WHITE);
                } else {
                    drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBurnInOffHe), Graphics.COLOR_WHITE);
                }
            } else {
                drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideMipHe), Graphics.COLOR_LT_GRAY);
                topY += lineH - 4;
                drawHebrewLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideStaticHe), Graphics.COLOR_WHITE);
            }
        } else {
            if (isAmoled) {
                drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideAmoledEn), Graphics.COLOR_LT_GRAY);
                topY += lineH - 4;
                if (isProtectorOn) {
                    drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBurnInOnEn), Graphics.COLOR_WHITE);
                } else {
                    drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideBurnInOffEn), Graphics.COLOR_WHITE);
                }
            } else {
                drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideMipEn), Graphics.COLOR_LT_GRAY);
                topY += lineH - 4;
                drawLine(dc, w, topY, WatchUi.loadResource(Rez.Strings.TextGuideStaticEn), Graphics.COLOR_WHITE);
            }
        }
    }
}



class SimpleBackDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}

class ResetDoneView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerY = h / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, centerY - 15, Graphics.FONT_SMALL, "Settings reset", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, centerY + 15, Graphics.FONT_XTINY, "Back to return", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class ZmanimDebugView extends WatchUi.View {
    private var _engine;
    private var _parasha;
    private var _hebrewFont;

    function initialize() {
        View.initialize();
        _engine = new ZmanimEngine();
        _parasha = new ParashaLookup();
        _hebrewFont = AppFonts.getHebrewTextFont();
    }

    function formatMoment(m as Time.Moment) as String {
        var info = Gregorian.info(m, Time.FORMAT_SHORT);
        return Lang.format("$1$:$2$", [info.hour.format("%02d"), info.min.format("%02d")]);
    }

    function locationLabel() as String {
        var loc = KodeshSettings.getValue("location");

        if (loc == null) {
            return "Jerusalem";
        }

        var value = loc as String;

        if (value.equals("loc_jerusalem")) {
            return "Jerusalem";
        }

        if (value.equals("loc_telaviv")) {
            return "Tel Aviv";
        }

        if (value.equals("loc_haifa")) {
            return "Haifa";
        }

        if (value.equals("loc_eilat")) {
            return "Eilat";
        }

        if (value.equals("loc_gps")) {
            if (ShabbatMode.isEnabled()) {
                return "GPS Frozen";
            }

            return "Last GPS";
        }

        return value;
    }

    function boolLabel(value as Boolean) as String {
        return value ? "ON" : "OFF";
    }

    function shortCoord(value as Float) as String {
        var scaled = (value * 1000.0f).toNumber();
        return ((scaled.toFloat()) / 1000.0f).toString();
    }

    function drawDivider(dc as Graphics.Dc, y as Number, width as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(28, y, width - 28, y);
    }

    function drawCenteredLine(dc as Graphics.Dc, text as String, y as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            y,
            Graphics.FONT_XTINY,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function drawCenteredHebrewLine(dc as Graphics.Dc, text as String, y as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            y,
            _hebrewFont,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function drawTimeBlock(dc as Graphics.Dc, centerX as Number, topY as Number, label as String, value as String, color as Number) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            topY,
            Graphics.FONT_XTINY,
            label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            topY + 23,
            Graphics.FONT_SMALL,
            value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function getSafeParashaName(now) as String {
        var name = _parasha.getCurrentParashaName(now);

        if (name == null) {
            return "";
        }

        return name;
    }

    function getSafeSpecialName(now) as String {
        var name = _parasha.getCurrentSpecialShabbatName(now);

        if (name == null) {
            return "";
        }

        return name;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var now = Time.now();
        var coords = _engine.getCoordinates();
        var times = _engine.getShabbatTimes(now);

        var parashaName = getSafeParashaName(now);
        var specialName = getSafeSpecialName(now);

        var y = (height.toFloat() * 0.12f).toNumber();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            y,
            Graphics.FONT_TINY,
            "Zmanim Debug",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        y += 20;
        drawDivider(dc, y, width);
        y += 22;

        if (times != null) {
            drawTimeBlock(
                dc,
                (width.toFloat() * 0.32f).toNumber(),
                y,
                "Entry",
                formatMoment(times.entryMoment),
                Graphics.COLOR_GREEN
            );

            drawTimeBlock(
                dc,
                (width.toFloat() * 0.68f).toNumber(),
                y,
                "Exit",
                formatMoment(times.exitMoment),
                Graphics.COLOR_RED
            );

            y += 52;

            var entryInfo = Gregorian.info(times.entryMoment, Time.FORMAT_SHORT);
            var exitInfo = Gregorian.info(times.exitMoment, Time.FORMAT_SHORT);
            var entryOffset = _engine.getIsraelUtcOffsetHours(entryInfo.year, entryInfo.month, entryInfo.day, entryInfo.hour.toFloat()).toNumber();
            var exitOffset = _engine.getIsraelUtcOffsetHours(exitInfo.year, exitInfo.month, exitInfo.day, exitInfo.hour.toFloat()).toNumber();

            drawCenteredLine(
                dc,
                Lang.format("Candle $1$m   Havdalah $2$m", [
                    _engine.getCandleOffsetMinutes(coords).toNumber(),
                    _engine.getHavdalahOffsetMinutes().toNumber()
                ]),
                y,
                Graphics.COLOR_LT_GRAY
            );

            y += 16;

            drawCenteredLine(
                dc,
                Lang.format("UTC +$1$ / +$2$", [entryOffset, exitOffset]),
                y,
                Graphics.COLOR_LT_GRAY
            );

            y += 18;
        } else {
            drawCenteredLine(dc, "No upcoming block", y, Graphics.COLOR_RED);
            y += 28;
        }

        drawDivider(dc, y, width);
        y += 18;

        drawCenteredLine(dc, Lang.format("Location: $1$", [locationLabel()]), y, Graphics.COLOR_WHITE);
        y += 16;

        drawCenteredLine(
            dc,
            Lang.format("Coords: $1$, $2$", [shortCoord(coords.lat), shortCoord(coords.lon)]),
            y,
            Graphics.COLOR_LT_GRAY
        );

        y += 18;

        if (!parashaName.equals("")) {
            drawCenteredHebrewLine(dc, parashaName, y, Graphics.COLOR_WHITE);
            y += 18;
        }

        if (!specialName.equals("")) {
            drawCenteredHebrewLine(dc, specialName, y, Graphics.COLOR_YELLOW);
            y += 18;
        }

        drawCenteredLine(
            dc,
            Lang.format("Mode $1$   Special $2$", [
                boolLabel(ShabbatMode.isEnabled()),
                boolLabel(ShabbatMode.isSpecialModeEnabled())
            ]),
            y,
            Graphics.COLOR_YELLOW
        );
    }
}