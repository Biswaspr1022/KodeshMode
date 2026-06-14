import Toybox.Graphics;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.Application.Storage;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Attention;

const FORCE_AOD_TEST = false;

function deviceRequiresBurnInProtection(settings) as Boolean {
    try {
        if (FORCE_AOD_TEST) {
            return true;
        }

        if (settings != null && (settings has :requiresBurnInProtection)) {
            return settings.requiresBurnInProtection == true;
        }
    } catch (ex) {
    }

    return false;
}

function shouldUseAmoledLayout(settings) as Boolean {
    return deviceRequiresBurnInProtection(settings);
}


class KodeshModeView extends WatchUi.View {
    private var _timer;
    private var _isLowPower as Boolean = false;
    private var _zmanimEngine;
    private var _parashaLookup;
    private var _hebrewFont;
    private var _lastShowSeconds as Boolean = false;

    private const MINUTE_MS = 60000;
    private const PRE_SHABBAT_ALERT_DISPLAY_MS = 10000;
    private const KEY_PRE_SHABBAT_ALERT_MESSAGE = "preShabbatAlertMessage";
    private const KEY_PRE_SHABBAT_ALERT_UNTIL = "preShabbatAlertUntil";

    function initialize() {
        View.initialize();
        _timer = new Timer.Timer();
        _zmanimEngine = new ZmanimEngine();
        _parashaLookup = new ParashaLookup();
        _hebrewFont = AppFonts.getHebrewTextFont();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        _isLowPower = false;
        checkPreShabbatAlert(Time.now());
        scheduleNextUpdate();
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
        }
    }

    function delayToNextMinute() as Number {
        var clockTime = System.getClockTime();
        var delay = (60 - clockTime.sec) * 1000;

        if (delay <= 0) {
            delay = MINUTE_MS;
        }

        return delay;
    }

    function scheduleNextUpdate() as Void {
        if (_timer != null) {
            _timer.stop();
        }

        var delay = MINUTE_MS;
        
        var settings = System.getDeviceSettings();
        var isAmoledLayout = shouldUseAmoledLayout(settings);
        var useAnalogClock = shouldUseAnalogClockForDevice(settings);
        var isAod = FORCE_AOD_TEST || (isAmoledLayout && (_isLowPower || isManualShabbatModeEnabled()));

        var wantsSeconds = useAnalogClock || isTimeFormatWithSeconds();

        if (_isLowPower) {
            if (getPreShabbatAlertMinutes() <= 0) {
                return;
            }
            delay = delayToNextMinute();
        } else if (wantsSeconds && !isAod) {
            delay = 1000;
        } else {
            delay = delayToNextMinute();
        }

        if (delay < 1000) {
            delay = 1000;
        }

        try {
            _timer.start(method(:onTimer), delay, false);
        } catch (timerEx) {
        }
    }

    function onTimer() as Void {
        var now = Time.now();

        // Always check the alert, even while the AMOLED view is dimmed/AOD.
        // In low power we do NOT request a redraw; we only vibrate and store
        // the message so it appears the next time the display wakes.
        checkPreShabbatAlert(now);

        if (!_isLowPower) {
            WatchUi.requestUpdate();
        }

        scheduleNextUpdate();
    }

    function onEnterSleep() as Void {
        // MIP/Solar devices do not need CIQ burn-in/AOD screen protection.
        // Keep them in the normal digital layout so Shabbat Mode remains readable.
        if (!isCurrentDeviceAmoled()) {
            _isLowPower = false;
            return;
        }

        _isLowPower = true;
        scheduleNextUpdate();
    }

    function onExitSleep() as Void {
        _isLowPower = false;
        WatchUi.requestUpdate();
        scheduleNextUpdate();
    }

    function getBurnInShiftRange(width as Number, height as Number) as Number {
        var minDim = width;
        if (height < minDim) {
            minDim = height;
        }

        // AOD/Kodesh burn-in protection needs more than 1-2 pixels. Use a
        // screen-relative shift so large AMOLED displays move further while
        // small screens still stay readable. The analog radius is reduced in
        // AOD by the same range so the face does not clip at the screen edge.
        var shift = (minDim.toFloat() * 0.055f).toNumber();

        if (shift < 8) {
            shift = 8;
        }

        if (shift > 22) {
            shift = 22;
        }

        return shift;
    }

    function burnInPatternValue(pattern as Number, range as Number) as Number {
        // Nine positions across the range. This keeps the same pixel from being
        // continuously lit by thick fonts, center dots, or analog hands during
        // a full Shabbat/AOD session.
        if (pattern == 0) { return -range; }
        if (pattern == 1) { return -((range * 3) / 4); }
        if (pattern == 2) { return -(range / 2); }
        if (pattern == 3) { return -(range / 4); }
        if (pattern == 4) { return 0; }
        if (pattern == 5) { return range / 4; }
        if (pattern == 6) { return range / 2; }
        if (pattern == 7) { return (range * 3) / 4; }
        return range;
    }

    function getBurnInOffsetX(clockTime, width as Number, height as Number) as Number {
        var range = getBurnInShiftRange(width, height);
        var pattern = (clockTime.min + (clockTime.hour * 3)) % 9;
        return burnInPatternValue(pattern, range);
    }

    function getBurnInOffsetY(clockTime, width as Number, height as Number) as Number {
        var range = getBurnInShiftRange(width, height);
        var pattern = ((clockTime.min * 2) + clockTime.hour) % 9;
        return burnInPatternValue(pattern, range);
    }

    function getClockString(clockTime, showSeconds as Boolean, use24Hour as Boolean) as String {
        var hour = clockTime.hour;
        var suffix = "";

        if (!use24Hour) {
            suffix = hour >= 12 ? " PM" : " AM";
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }

        if (showSeconds) {
            return Lang.format("$1$:$2$:$3$$4$", [
                hour,
                clockTime.min.format("%02d"),
                clockTime.sec.format("%02d"),
                suffix
            ]);
        }

        return Lang.format("$1$:$2$$3$", [
            hour,
            clockTime.min.format("%02d"),
            suffix
        ]);
    }

    function isTimeFormatWithSeconds() as Boolean {
        var formatId = KodeshSettings.getValue("timeFormat");

        if (formatId == null) {
            return false;
        }

        try {
            var formatString = formatId as String;
            return formatString.equals("format_hms") || formatString.equals("1");
        } catch (stringEx) {
        }

        try {
            return (formatId as Number) == 1;
        } catch (numberEx) {
        }

        return false;
    }

    function getClockSizeModeForSeconds(sizeMode as String, width as Number) as String {
        var size = AppFonts.normalizeClockSize(sizeMode);

        // Do not override the user's selected clock size just because HH:MM:SS is active.
        // The previous logic forced most MIP/Fenix widths (<= 280px) down to 36, so
        // choosing 52/60/68/76/84 looked as if it did nothing. Keep the selected size
        // and let the existing centered drawText/circular layout decide whether it fits.
        // Only very small legacy screens get a defensive cap to avoid unreadable clipping.
        if (width <= 176) {
            if (size.equals("clock_size_84") || size.equals("clock_size_68") ||
                size.equals("clock_size_52")) {
                return "clock_size_36";
            }
        }

        return size;
    }

    function getActiveFontForTime(showSeconds as Boolean, width as Number) {
        if (!showSeconds) {
            return getActiveFont();
        }

        var family = AppFonts.getClockFontMode();
        var sizeMode = getClockSizeModeForSeconds(AppFonts.getClockSizeMode(), width);
        return AppFonts.getFontForClockFamily(family, sizeMode);
    }

    function getActiveFont() {
        return AppFonts.getClockFont();
    }

    function getActiveColor() as Number {
        var colorId = KodeshSettings.getValue("fontColor");
        if (colorId != null) {
            var value = colorId as String;
            if (value.equals("color_gray")) { return Graphics.COLOR_DK_GRAY; }
            if (value.equals("color_yellow")) { return Graphics.COLOR_YELLOW; }
            if (value.equals("color_red")) { return Graphics.COLOR_RED; }
            if (value.equals("color_green")) { return Graphics.COLOR_GREEN; }
            if (value.equals("color_blue")) { return Graphics.COLOR_BLUE; }
            if (value.equals("color_orange")) { return Graphics.COLOR_ORANGE; }
        }
        return Graphics.COLOR_WHITE;
    }

    function getRenderColor(isAod as Boolean) as Number {
        if (isAod) {
            return 0x888888;
        }
        return getActiveColor();
    }

    function isAnalogClockEnabled() as Boolean {
        var mode = KodeshSettings.getValue("clockStyle");
        return mode != null && (mode as String).equals("clock_analog");
    }


    function shouldUseAnalogClockForDevice(settings) as Boolean {
        if (!shouldUseAmoledLayout(settings)) {
            return false;
        }

        return isAnalogClockEnabled();
    }

    function shouldDrawShabbatProgressForDevice(settings, useAnalogClock as Boolean) as Boolean {
        if (useAnalogClock) {
            return false;
        }

        // On MIP/Solar the large progress ring makes the small digital layout noisy
        // and there is no burn-in/AOD reason to keep an extra moving ring alive.
        // AMOLED digital keeps the ring because it is part of the protected face.
        return shouldUseAmoledLayout(settings);
    }

    function getAnalogRadius(width as Number, height as Number, isAod as Boolean) as Number {
        var minDim = width;
        if (height < minDim) {
            minDim = height;
        }

        var sizeMode = KodeshSettings.getValue("clockSize");
        var size = "clock_size_36";
        if (sizeMode != null) {
            size = sizeMode as String;
        }

        // Fenix-style: use almost the full safe circular area.
        var factor = 0.455f;
        if (size.equals("clock_size_18")) { factor = 0.405f; }
        else if (size.equals("clock_size_24")) { factor = 0.438f; }
        else if (size.equals("clock_size_28")) { factor = 0.452f; }
        else if (size.equals("clock_size_30")) { factor = 0.462f; }
        else if (size.equals("clock_size_36")) { factor = 0.472f; }
        else if (size.equals("clock_size_44")) { factor = 0.480f; }
        else if (size.equals("clock_size_52")) { factor = 0.486f; }
        else if (size.equals("clock_size_60")) { factor = 0.492f; }
        else if (size.equals("clock_size_68")) { factor = 0.495f; }
        else if (size.equals("clock_size_76")) { factor = 0.498f; }
        else if (size.equals("clock_size_84")) { factor = 0.502f; }

        var radius = (minDim.toFloat() * factor).toNumber();
        var maxRadius = (minDim.toFloat() * 0.492f).toNumber();

        if (isAod && isScreenProtectorEnabled()) {
            // Reserve physical screen space for the larger pixel shift. AOD burn
            // safety is more important than using the absolute maximum diameter.
            maxRadius = (minDim / 2) - getBurnInShiftRange(width, height) - 6;
        }

        if (radius > maxRadius) {
            radius = maxRadius;
        }

        if (radius < 82) {
            radius = 82;
        }

        return radius;
    }

    function analogPointX(centerX as Number, radius as Number, units as Float) as Number {
        var angle = ((units / 60.0f) * 6.283185f) - 1.570796f;
        return (centerX.toFloat() + (radius.toFloat() * Math.cos(angle))).toNumber();
    }

    function analogPointY(centerY as Number, radius as Number, units as Float) as Number {
        var angle = ((units / 60.0f) * 6.283185f) - 1.570796f;
        return (centerY.toFloat() + (radius.toFloat() * Math.sin(angle))).toNumber();
    }

    function drawSafeLine(dc as Graphics.Dc, x1 as Number, y1 as Number, x2 as Number, y2 as Number, color as Number, thickness as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x1, y1, x2, y2);

        if (thickness >= 2) {
            dc.drawLine(x1 + 1, y1, x2 + 1, y2);
            dc.drawLine(x1 - 1, y1, x2 - 1, y2);
        }

        if (thickness >= 3) {
            dc.drawLine(x1, y1 + 1, x2, y2 + 1);
            dc.drawLine(x1, y1 - 1, x2, y2 - 1);
        }
    }

    function getAnalogNumberFont(radius as Number, isAod as Boolean) {
        var fontMode = AppFonts.getClockFontMode();
        var sizeMode = "clock_size_24";

        if (isAod) {
            if (radius >= 150) {
                sizeMode = "clock_size_28";
            } else if (radius >= 120) {
                sizeMode = "clock_size_24";
            } else {
                sizeMode = "clock_size_24";
            }
        } else {
            if (radius >= 158) {
                sizeMode = "clock_size_28";
            } else if (radius >= 135) {
                sizeMode = "clock_size_28";
            } else if (radius >= 112) {
                sizeMode = "clock_size_24";
            } else {
                sizeMode = "clock_size_24";
            }
        }

        return AppFonts.getFontForClockFamily(fontMode, sizeMode);
    }

    function drawAnalogOuterFace(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, isAod as Boolean) as Void {
        var ringColor = isAod ? 0x5F5F5F : 0xD8D8D8;
        var softRingColor = isAod ? 0x3E3E3E : 0x777777;

        // Clean dial boundary only.
        // The inner content circle was removed because it made the analog face look busy
        // and competed with the Hebrew/date/battery text inside the center area.
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, radius);

        dc.setColor(softRingColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, radius - 3);
    }

    function drawAnalogTicks(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, isAod as Boolean) as Void {
        var majorColor = isAod ? 0x777777 : Graphics.COLOR_WHITE;
        var tick = 0;

        // Draw 60 ticks for normal mode, but only 12 ticks for AOD
        // to keep the screen clean and reduce burn-in footprint.
        while (tick < 60) {
            var isHour = (tick % 5) == 0;

            if (!isHour && isAod) {
                tick += 1;
                continue;
            }

            var units = tick.toFloat();
            var isCardinal = (tick % 15) == 0;
            var outer = radius - 6;
            
            var inner;
            var thickness;

            if (!isHour) {
                // Minute/second ticks
                inner = radius - 12;
                thickness = 1;
            } else {
                // Hour ticks
                inner = radius - (isCardinal ? 24 : 18);
                thickness = isAod ? (isCardinal ? 2 : 1) : (isCardinal ? 3 : 2);
            }

            drawSafeLine(
                dc,
                analogPointX(centerX, outer, units),
                analogPointY(centerY, outer, units),
                analogPointX(centerX, inner, units),
                analogPointY(centerY, inner, units),
                majorColor,
                thickness
            );

            tick += 1;
        }
    }

    function drawAnalogNumbers(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, isAod as Boolean) as Void {
        var font = getAnalogNumberFont(radius, isAod);
        var color = isAod ? 0x8A8A8A : Graphics.COLOR_WHITE;
        var numberRadius = (radius.toFloat() * 0.765f).toNumber();

        var number = 1;
        while (number <= 12) {
            // AOD uses the same 1-12 layout as the active display, only dimmed.
            var units = ((number % 12) * 5).toFloat();
            var text = Lang.format("$1$", [number]);
            var nx = analogPointX(centerX, numberRadius, units);
            var ny = analogPointY(centerY, numberRadius, units);

            // Small optical corrections so 12/6 do not touch the tick ring.
            if (number == 12) { ny += 4; }
            if (number == 6) { ny -= 4; }

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                nx,
                ny,
                font,
                text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );

            number += 1;
        }
    }

    function getAnalogSmallHebrewFont() {
        try {
            var f = AppFonts.getHebrewTextFont();
            if (f != null) {
                return f;
            }
        } catch (ex) {
        }

        try {
            var p = AppFonts.getParashaFont();
            if (p != null) {
                return p;
            }
        } catch (ex2) {
        }

        return Graphics.FONT_XTINY;
    }

    function getAnalogPrimaryHebrewFont() {
        // Use the larger parasha font for the top analog line.
        // This makes the parasha name readable while keeping the date/times smaller.
        try {
            var p = AppFonts.getParashaFont();
            if (p != null) {
                return p;
            }
        } catch (ex) {
        }

        return getAnalogSmallHebrewFont();
    }

    function loadTextResource(id) as String {
        try {
            return WatchUi.loadResource(id) as String;
        } catch (ex) {
        }

        return "";
    }

    function drawAnalogCenterText(dc as Graphics.Dc, x as Number, y as Number, font, text as String, color as Number) as Void {
        if (text == null || text.equals("")) {
            return;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function getBatteryText() as String {
        if (!getToggleValue("showBattery", false)) {
            return "";
        }

        if (!(System has :getSystemStats)) {
            return "";
        }

        var stats = System.getSystemStats();
        if (stats == null || !(stats has :battery)) {
            return "";
        }

        var percent = stats.battery;
        if (percent == null || percent < 0) {
            return "";
        }

        if (percent > 100) {
            percent = 100;
        }

        var pct = (percent + 0.5f).toNumber();
        return Lang.format("$1$%", [pct]);
    }

    function getShabbatTimesText(now) as String {
        try {
            if (!getToggleValue("showShabbatTimes", false)) {
                return "";
            }

            var times = _zmanimEngine.getShabbatTimes(now);
            if (times == null) {
                return "";
            }

            return Lang.format("$1$ | $2$", [formatHourFloat(times.entry), formatHourFloat(times.exit)]);
        } catch (ex) {
        }

        return "";
    }

    function getAnalogShabbatStatusText() as String {
        try {
            var status = getPriorityStatusMessage();
            if (!status.equals("")) {
                return status;
            }

            if (isManualShabbatModeEnabled()) {
                return loadTextResource(Rez.Strings.TextShabbatShalom);
            }
        } catch (ex) {
        }

        return "";
    }

    function drawAnalogInnerContent(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, now, isAod as Boolean) as Void {
        try {
            var primary = isAod ? 0x777777 : Graphics.COLOR_WHITE;
            var secondary = getSecondaryRenderColor(isAod);
            var accent = getAlertRenderColor(isAod);
            var hebSmall = getAnalogSmallHebrewFont();
            var hebTop = getAnalogPrimaryHebrewFont();
            var hebDateFont = AppFonts.getHebrewDateFont();

            if (hebDateFont == null) {
                hebDateFont = hebSmall;
            }

            // Analog inner layout:
            // - Parasha/Omer is moved higher (approx 80% of the inner radius area).
            // - Hebrew date sits directly below the parasha line.
            // - Shabbat times and battery are moved lower, but stay above the 6 digit.
            var topY = centerY - (radius.toFloat() * 0.605f).toNumber();
            var dateY = centerY - (radius.toFloat() * 0.455f).toNumber();
            var statusY = centerY - (radius.toFloat() * 0.235f).toNumber();
            var timesY = centerY + (radius.toFloat() * 0.275f).toNumber();
            var batteryY = centerY + (radius.toFloat() * 0.405f).toNumber();

            // Top inner line: Omer first, otherwise Parasha.
            var topText = "";
            var topKey = "omer";
            if (getToggleValue("showOmer", true)) {
                topText = getOmerText(now);
            }

            if (topText.equals("")) {
                topKey = "parasha";
                var showParasha = KodeshSettings.getValue("showParasha");
                if (showParasha == null || showParasha != false) {
                    topText = _parashaLookup.getCurrentParashaName(now);
                }
            }

            if (!topText.equals("")) {
                drawAnalogCenterText(dc, centerX + getLayoutOffsetX(topKey), topY + getLayoutOffsetY(topKey), hebTop, topText, secondary);
            }

            // Hebrew date directly below the parasha/Omer line.
            if (getToggleValue("showHebrewDate", true)) {
                var dateText = getHebrewDateText(now);
                if (!dateText.equals("")) {
                    drawAnalogCenterText(dc, centerX + getLayoutOffsetX("hebrewDate"), dateY + getLayoutOffsetY("hebrewDate"), hebDateFont, dateText, primary);
                }
            }

            // Center/greeting line.
            var statusText = getAnalogShabbatStatusText();
            if (!statusText.equals("")) {
                drawAnalogCenterText(dc, centerX + getLayoutOffsetX("status"), statusY + getLayoutOffsetY("status"), hebSmall, statusText, accent);
            }

            var timeText = getShabbatTimesText(now);
            if (!timeText.equals("")) {
                drawAnalogCenterText(dc, centerX + getLayoutOffsetX("shabbatTimes"), timesY + getLayoutOffsetY("shabbatTimes"), Graphics.FONT_XTINY, timeText, secondary);
            }

            var batteryText = getBatteryText();
            if (!batteryText.equals("")) {
                drawAnalogCenterText(dc, centerX + getLayoutOffsetX("battery"), batteryY + getLayoutOffsetY("battery"), Graphics.FONT_XTINY, batteryText, primary);
            }
        } catch (ex) {
        }
    }

    function drawAnalogAodInnerContent(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number, now) as Void {
        try {
            var color = 0x777777;
            var alert = 0x888888;
            var hebSmall = getAnalogSmallHebrewFont();
            var statusText = getAnalogShabbatStatusText();

            // AOD should be readable but sparse: no Omer/Battery/Shabbat-times here.
            // Show only the core Jewish state/date in the safe center area.
            if (!statusText.equals("")) {
                drawAnalogCenterText(
                    dc,
                    centerX + getLayoutOffsetX("status"),
                    centerY - (radius.toFloat() * 0.095f).toNumber() + getLayoutOffsetY("status"),
                    hebSmall,
                    statusText,
                    alert
                );
            }

            if (getToggleValue("showHebrewDate", true)) {
                var dateText = getHebrewDateText(now);
                if (!dateText.equals("")) {
                    drawAnalogCenterText(
                        dc,
                        centerX + getLayoutOffsetX("hebrewDate"),
                        centerY + (radius.toFloat() * 0.095f).toNumber() + getLayoutOffsetY("hebrewDate"),
                        hebSmall,
                        dateText,
                        color
                    );
                }
            }
        } catch (ex) {
        }
    }

    function drawAnalogHands(dc as Graphics.Dc, clockTime, centerX as Number, centerY as Number, radius as Number, isAod as Boolean, showSeconds as Boolean) as Void {
        var mainColor = isAod ? 0x999999 : Graphics.COLOR_WHITE;
        var accentColor = isAod ? 0x777777 : Graphics.COLOR_RED;

        var hourUnits = ((clockTime.hour % 12) * 5).toFloat() + (clockTime.min.toFloat() / 12.0f);
        var minuteUnits = clockTime.min.toFloat() + (clockTime.sec.toFloat() / 60.0f);

        // Fenix-style hands: long enough to be readable, but not over the digits.
        var hourRadius = (radius.toFloat() * 0.44f).toNumber();
        var minuteRadius = (radius.toFloat() * 0.68f).toNumber();
        var secondRadius = (radius.toFloat() * 0.78f).toNumber();

        drawSafeLine(
            dc,
            centerX,
            centerY,
            analogPointX(centerX, hourRadius, hourUnits),
            analogPointY(centerY, hourRadius, hourUnits),
            mainColor,
            isAod ? 2 : 4
        );

        drawSafeLine(
            dc,
            centerX,
            centerY,
            analogPointX(centerX, minuteRadius, minuteUnits),
            analogPointY(centerY, minuteRadius, minuteUnits),
            mainColor,
            isAod ? 2 : 3
        );

        if (showSeconds && !isAod) {
            // Red seconds hand, Fenix-like, but not all the way into the text area.
            drawSafeLine(
                dc,
                analogPointX(centerX, 10, clockTime.sec.toFloat() + 30.0f),
                analogPointY(centerY, 10, clockTime.sec.toFloat() + 30.0f),
                analogPointX(centerX, secondRadius, clockTime.sec.toFloat()),
                analogPointY(centerY, secondRadius, clockTime.sec.toFloat()),
                accentColor,
                1
            );
        }

        if (!isAod) {
            dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY, 5);
            dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(centerX, centerY, 7);
        } else {
            // Do not leave a thick, always-on filled center dot in AOD. The
            // hands already meet here, and the whole face is pixel-shifted.
            dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(centerX, centerY, 4);
        }
    }

    function drawAnalogClock(dc as Graphics.Dc, clockTime, centerX as Number, centerY as Number, width as Number, height as Number, now, isAod as Boolean, showSeconds as Boolean) as Void {
        var radius = getAnalogRadius(width, height, isAod);

        drawAnalogOuterFace(dc, centerX, centerY, radius, isAod);
        drawAnalogTicks(dc, centerX, centerY, radius, isAod);
        drawAnalogNumbers(dc, centerX, centerY, radius, isAod);

        // Draw the same Jewish/Shabbat content in active mode and AOD.
        // AOD gets dimmer colors from drawAnalogInnerContent(), and the whole
        // face is pixel-shifted by getBurnInOffsetX/Y to reduce burn-in risk.
        drawAnalogInnerContent(dc, centerX, centerY, radius, now, isAod);

        drawAnalogHands(dc, clockTime, centerX, centerY, radius, isAod, showSeconds);
    }

    function getToggleValue(key as String, defaultValue as Boolean) as Boolean {
        return KodeshSettings.getBool(key, defaultValue);
    }

    function getLayoutOffsetX(itemKey as String) as Number {
        return KodeshSettings.getLayoutOffsetX(itemKey);
    }

    function getLayoutOffsetY(itemKey as String) as Number {
        return KodeshSettings.getLayoutOffsetY(itemKey);
    }

    function getSecondaryRenderColor(isAod as Boolean) as Number {
        if (isAod) {
            return 0x777777;
        }

        return Graphics.COLOR_LT_GRAY;
    }

    function getAlertRenderColor(isAod as Boolean) as Number {
        if (isAod) {
            return 0x888888;
        }

        return Graphics.COLOR_YELLOW;
    }

    function isManualShabbatModeEnabled() as Boolean {
        try {
            return ShabbatMode.isEnabled();
        } catch (ex) {
        }

        return false;
    }

    function getPreShabbatAlertMessage() as String {
        var message = Storage.getValue(KEY_PRE_SHABBAT_ALERT_MESSAGE);
        var until = Storage.getValue(KEY_PRE_SHABBAT_ALERT_UNTIL);

        if (message == null || until == null) {
            return "";
        }

        if (System.getTimer() > (until as Number)) {
            try {
                Storage.deleteValue(KEY_PRE_SHABBAT_ALERT_MESSAGE);
                Storage.deleteValue(KEY_PRE_SHABBAT_ALERT_UNTIL);
            } catch (ex) {
            }
            return "";
        }

        return message as String;
    }

    function getPriorityStatusMessage() as String {
        var alertMessage = getPreShabbatAlertMessage();
        if (!alertMessage.equals("")) {
            return alertMessage;
        }

        return getShabbatModeStatusMessage();
    }

    function getShabbatModeStatusMessage() as String {
        try {
            return ShabbatMode.getStatusMessage();
        } catch (ex) {
        }

        return "";
    }

    function formatHourFloat(hours as Float) as String {
        var totalMinutes = ((hours * 60.0f) + 0.5f).toNumber();

        while (totalMinutes < 0) {
            totalMinutes += 1440;
        }

        while (totalMinutes >= 1440) {
            totalMinutes -= 1440;
        }

        var h = totalMinutes / 60;
        var m = totalMinutes % 60;

        return Lang.format("$1$:$2$", [h.format("%02d"), m.format("%02d")]);
    }

    function drawShabbatTimes(dc as Graphics.Dc, width as Number, height as Number, now, shiftX as Number, shiftY as Number, isAod as Boolean) as Void {
        try {
            if (!getToggleValue("showShabbatTimes", false)) {
                return;
            }

            var times = _zmanimEngine.getShabbatTimes(now);

            if (times == null) {
                return;
            }

            var text = Lang.format("$1$ | $2$", [formatHourFloat(times.entry), formatHourFloat(times.exit)]);
            var x = (width / 2) + shiftX + getLayoutOffsetX("shabbatTimes");
            var y = (height.toFloat() * 0.78f).toNumber() + shiftY + getLayoutOffsetY("shabbatTimes");

            var font = AppFonts.getShabbatTimesFont();
            if (font == null) {
                font = Graphics.FONT_XTINY;
            }

            dc.setColor(getSecondaryRenderColor(isAod), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x,
                y,
                font,
                text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        } catch (ex) {
        }
    }

    function drawBattery(dc as Graphics.Dc, width as Number, height as Number, shiftX as Number, shiftY as Number, isAod as Boolean) as Void {
        try {
            if (!getToggleValue("showBattery", false)) {
                return;
            }

            if (!(System has :getSystemStats)) {
                return;
            }

            var stats = System.getSystemStats();

            if (stats == null || !(stats has :battery)) {
                return;
            }

            var percent = stats.battery.toNumber();


            if (percent < 0) {
                return;
            }

            if (percent > 100) {
                percent = 100;
            }

            var text = Lang.format("$1$%", [percent]);
            var x = (width / 2) + shiftX + getLayoutOffsetX("battery");
            var y = (height.toFloat() * 0.855f).toNumber() + shiftY + getLayoutOffsetY("battery");

            dc.setColor(getSecondaryRenderColor(isAod), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x,
                y,
                Graphics.FONT_XTINY,
                text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        } catch (ex) {
        }
    }

    function getHebrewOmerNumberString(day as Number) as String {
        if (day == 1) { return loadTextResource(Rez.Strings.HebNum1); }
        if (day == 2) { return loadTextResource(Rez.Strings.HebNum2); }
        if (day == 3) { return loadTextResource(Rez.Strings.HebNum3); }
        if (day == 4) { return loadTextResource(Rez.Strings.HebNum4); }
        if (day == 5) { return loadTextResource(Rez.Strings.HebNum5); }
        if (day == 6) { return loadTextResource(Rez.Strings.HebNum6); }
        if (day == 7) { return loadTextResource(Rez.Strings.HebNum7); }
        if (day == 8) { return loadTextResource(Rez.Strings.HebNum8); }
        if (day == 9) { return loadTextResource(Rez.Strings.HebNum9); }
        if (day == 10) { return loadTextResource(Rez.Strings.HebNum10); }
        if (day == 11) { return loadTextResource(Rez.Strings.HebNum11); }
        if (day == 12) { return loadTextResource(Rez.Strings.HebNum12); }
        if (day == 13) { return loadTextResource(Rez.Strings.HebNum13); }
        if (day == 14) { return loadTextResource(Rez.Strings.HebNum14); }
        if (day == 15) { return loadTextResource(Rez.Strings.HebNum15); }
        if (day == 16) { return loadTextResource(Rez.Strings.HebNum16); }
        if (day == 17) { return loadTextResource(Rez.Strings.HebNum17); }
        if (day == 18) { return loadTextResource(Rez.Strings.HebNum18); }
        if (day == 19) { return loadTextResource(Rez.Strings.HebNum19); }
        if (day == 20) { return loadTextResource(Rez.Strings.HebNum20); }
        if (day == 21) { return loadTextResource(Rez.Strings.HebNum21); }
        if (day == 22) { return loadTextResource(Rez.Strings.HebNum22); }
        if (day == 23) { return loadTextResource(Rez.Strings.HebNum23); }
        if (day == 24) { return loadTextResource(Rez.Strings.HebNum24); }
        if (day == 25) { return loadTextResource(Rez.Strings.HebNum25); }
        if (day == 26) { return loadTextResource(Rez.Strings.HebNum26); }
        if (day == 27) { return loadTextResource(Rez.Strings.HebNum27); }
        if (day == 28) { return loadTextResource(Rez.Strings.HebNum28); }
        if (day == 29) { return loadTextResource(Rez.Strings.HebNum29); }
        if (day == 30) { return loadTextResource(Rez.Strings.HebNum30); }
        if (day == 31) { return loadTextResource(Rez.Strings.HebNum31); }
        if (day == 32) { return loadTextResource(Rez.Strings.HebNum32); }
        if (day == 33) { return loadTextResource(Rez.Strings.HebNum33); }
        if (day == 34) { return loadTextResource(Rez.Strings.HebNum34); }
        if (day == 35) { return loadTextResource(Rez.Strings.HebNum35); }
        if (day == 36) { return loadTextResource(Rez.Strings.HebNum36); }
        if (day == 37) { return loadTextResource(Rez.Strings.HebNum37); }
        if (day == 38) { return loadTextResource(Rez.Strings.HebNum38); }
        if (day == 39) { return loadTextResource(Rez.Strings.HebNum39); }
        if (day == 40) { return loadTextResource(Rez.Strings.HebNum40); }
        if (day == 41) { return loadTextResource(Rez.Strings.HebNum41); }
        if (day == 42) { return loadTextResource(Rez.Strings.HebNum42); }
        if (day == 43) { return loadTextResource(Rez.Strings.HebNum43); }
        if (day == 44) { return loadTextResource(Rez.Strings.HebNum44); }
        if (day == 45) { return loadTextResource(Rez.Strings.HebNum45); }
        if (day == 46) { return loadTextResource(Rez.Strings.HebNum46); }
        if (day == 47) { return loadTextResource(Rez.Strings.HebNum47); }
        if (day == 48) { return loadTextResource(Rez.Strings.HebNum48); }
        if (day == 49) { return loadTextResource(Rez.Strings.HebNum49); }

        return day.toString();
    }

    function getOmerText(now) as String {
        try {
            var date = Gregorian.info(now, Time.FORMAT_SHORT);
            var jd = _parashaLookup.gregorianToJd(date.year, date.month, date.day);

            // Safe evening rollover. Exact tzeit can be restored later once this path is stable.
            if (date.hour >= 18) {
                jd += 1;
            }

            var heb = _parashaLookup.hebrewFromJd(jd);
            var day = 0;

            if (heb.month == 1 && heb.day >= 16) {
                day = heb.day - 15;
            } else if (heb.month == 2) {
                day = heb.day + 15;
            } else if (heb.month == 3 && heb.day <= 5) {
                day = heb.day + 44;
            }

            if (day < 1 || day > 49) {
                return "";
            }

            var format = loadTextResource(Rez.Strings.TextOmerFormat);
            if (format.equals("")) {
                return Lang.format("Omer $1$", [day]);
            }

            return Lang.format(format, [getHebrewOmerNumberString(day)]);
        } catch (ex) {
            return "";
        }
    }

    function drawOmer(dc as Graphics.Dc, width as Number, height as Number, now, shiftX as Number, shiftY as Number, isAod as Boolean) as Void {
        try {
            if (!getToggleValue("showOmer", true)) {
                return;
            }

            var text = getOmerText(now);

            if (text.equals("")) {
                return;
            }

            var font = AppFonts.getHebrewTextFont();

            if (font == null) {
                return;
            }

            var x = (width / 2) + shiftX + getLayoutOffsetX("omer");
            var y = (height.toFloat() * 0.095f).toNumber() + shiftY + getLayoutOffsetY("omer");

            dc.setColor(getAlertRenderColor(isAod), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x,
                y,
                font,
                text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        } catch (ex) {
        }
    }

    function drawShabbatModeStatus(dc as Graphics.Dc, width as Number, height as Number, shiftX as Number, shiftY as Number, isAod as Boolean) as Void {
        try {
            var status = getPriorityStatusMessage();

            if (!status.equals("")) {
                var sx = (width / 2) + shiftX + getLayoutOffsetX("status");
                var sy = (height.toFloat() * 0.32f).toNumber() + shiftY + getLayoutOffsetY("status");
                var statusFont = Graphics.FONT_XTINY;
                var lang = KodeshSettings.getValue("language");
                var isHebrew = lang == null || (lang as String).equals("lang_he");

                if (isHebrew) {
                    try {
                        statusFont = AppFonts.getHebrewTextFont();
                    } catch (fontEx) {
                        statusFont = Graphics.FONT_XTINY;
                    }
                }

                if (statusFont == null) {
                    statusFont = Graphics.FONT_XTINY;
                }

                dc.setColor(getAlertRenderColor(isAod), Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    sx,
                    sy,
                    statusFont,
                    status,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
                return;
            }

            if (!isManualShabbatModeEnabled()) {
                return;
            }

            var font = AppFonts.getHebrewTextFont();

            if (font == null) {
                return;
            }

            var x = (width / 2) + shiftX + getLayoutOffsetX("status");
            var y = (height.toFloat() * 0.32f).toNumber() + shiftY + getLayoutOffsetY("status");

            dc.setColor(getSecondaryRenderColor(isAod), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x,
                y,
                font,
                loadTextResource(Rez.Strings.TextShabbatShalom),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        } catch (ex) {
        }
    }

    function drawParasha(dc as Graphics.Dc, width as Number, height as Number, now, shiftX as Number, shiftY as Number) as Void {
        var showParasha = KodeshSettings.getValue("showParasha");
        if (showParasha != null && showParasha == false) {
            return;
        }

        var parashaStr = _parashaLookup.getCurrentParashaName(now);
        if (parashaStr.equals("")) {
            return;
        }

        var topFont = Graphics.FONT_XTINY;
        var lang = KodeshSettings.getValue("language");
        var isHebrew = lang != null && (lang as String).equals("lang_he");
        
        if (isHebrew) {
            try {
                topFont = AppFonts.getParashaFont();
            } catch (ex) {
                topFont = _hebrewFont;
            }
        }

        var x = (width / 2) + shiftX + getLayoutOffsetX("parasha");
        var y = (height.toFloat() * 0.18f).toNumber() + shiftY + getLayoutOffsetY("parasha");

        dc.setColor(_isLowPower ? 0x888888 : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, topFont, parashaStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function getHebrewDayString(day as Number) as String {
        return getHebrewOmerNumberString(day);
    }

    function getHebrewMonthString(month as Number, year as Number) as String {
        if (month == 7) { return loadTextResource(Rez.Strings.HebMonthHe7); }
        if (month == 8) { return loadTextResource(Rez.Strings.HebMonthHe8); }
        if (month == 9) { return loadTextResource(Rez.Strings.HebMonthHe9); }
        if (month == 10) { return loadTextResource(Rez.Strings.HebMonthHe10); }
        if (month == 11) { return loadTextResource(Rez.Strings.HebMonthHe11); }
        if (month == 12) {
            if (_parashaLookup.isHebrewLeapYear(year)) {
                return loadTextResource(Rez.Strings.HebMonthHe12Leap);
            }
            return loadTextResource(Rez.Strings.HebMonthHe12);
        }
        if (month == 13) { return loadTextResource(Rez.Strings.HebMonthHe13Punct); }
        if (month == 1) { return loadTextResource(Rez.Strings.HebMonthHe1); }
        if (month == 2) { return loadTextResource(Rez.Strings.HebMonthHe2); }
        if (month == 3) { return loadTextResource(Rez.Strings.HebMonthHe3); }
        if (month == 4) { return loadTextResource(Rez.Strings.HebMonthHe4); }
        if (month == 5) { return loadTextResource(Rez.Strings.HebMonthHe5); }
        if (month == 6) { return loadTextResource(Rez.Strings.HebMonthHe6); }

        return "";
    }

    function getHebrewDateText(now) as String {
        var date = Gregorian.info(now, Time.FORMAT_SHORT);
        var jd = _parashaLookup.gregorianToJd(date.year, date.month, date.day);

        if (date.hour >= 18) {
            jd += 1;
        }

        var heb = _parashaLookup.hebrewFromJd(jd);
        if (heb == null) {
            return "";
        }

        var dayStr = getHebrewDayString(heb.day);
        
        var isShort = false;
        try { isShort = KodeshSettings.getBool("shortHebrewDate", false); } catch(ex) {}
        
        if (isShort) {
            return dayStr;
        }

        var monthName = getHebrewMonthString(heb.month, heb.year);
        if (monthName == null || monthName.equals("")) {
            return "";
        }

        var format = loadTextResource(Rez.Strings.TextHebrewDateFormat);
        if (format.equals("")) {
            return Lang.format("$1$ $2$", [getHebrewDayString(heb.day), monthName]);
        }

        return Lang.format(format, [getHebrewDayString(heb.day), monthName]);
    }

    function drawHebrewDate(dc as Graphics.Dc, width as Number, height as Number, now, shiftX as Number, shiftY as Number, isAod as Boolean) as Void {
        if (!getToggleValue("showHebrewDate", true)) {
            return;
        }

        var dateFont = AppFonts.getHebrewDateFont();
        if (dateFont == null) {
            return;
        }

        var text = getHebrewDateText(now);
        if (text.equals("")) {
            return;
        }

        var x = (width / 2) + shiftX + getLayoutOffsetX("hebrewDate");
        var y = (height.toFloat() * 0.64f).toNumber() + shiftY + getLayoutOffsetY("hebrewDate");

        dc.setColor(isAod ? 0x777777 : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, dateFont, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function getPreShabbatAlertMinutes() as Number {
        var alertId = KodeshSettings.getValue("preShabbatAlert");
        if (alertId == null) {
            // Production default: enable a safe 15 minute warning unless
            // the user explicitly selected Off in the menu.
            return 15;
        }

        var value = alertId as String;
        if (value.equals("alert_5")) { return 5; }
        if (value.equals("alert_10")) { return 10; }
        if (value.equals("alert_15")) { return 15; }
        if (value.equals("alert_30")) { return 30; }
        if (value.equals("alert_40")) { return 40; }
        if (value.equals("alert_60")) { return 60; }

        return 0;
    }

    function getPreShabbatAlertKey(date) as String {
        return Lang.format("$1$-$2$-$3$", [date.year, date.month, date.day]);
    }

    function isHourInWindow(currentHours as Float, startHours as Float, endHours as Float) as Boolean {
        if (startHours <= endHours) {
            return currentHours >= startHours && currentHours < endHours;
        }
        return currentHours >= startHours || currentHours < endHours;
    }

    function checkPreShabbatAlert(now) as Void {
        var alertMinutes = getPreShabbatAlertMinutes();
        if (alertMinutes <= 0) {
            return;
        }

        var date = Gregorian.info(now, Time.FORMAT_SHORT);
        if (date.day_of_week != 6) {
            return;
        }

        var times = _zmanimEngine.getShabbatTimes(now);
        if (times == null) {
            return;
        }

        var currentHours = date.hour + (date.min / 60.0f) + (date.sec / 3600.0f);
        var alertHours = times.entry - (alertMinutes.toFloat() / 60.0f);

        if (alertHours < 0.0f) {
            alertHours += 24.0f;
        }

        var alertKey = getPreShabbatAlertKey(date);
        var lastAlertKey = Storage.getValue("lastPreShabbatAlertKey");
        
        if (lastAlertKey != null && (lastAlertKey as String).equals(alertKey)) {
            return;
        }

        if (isHourInWindow(currentHours, alertHours, times.entry)) {
            Storage.setValue("lastPreShabbatAlertKey", alertKey);
            triggerPreShabbatAlert(alertMinutes);
        }
    }

    function getPreShabbatAlertDisplayText(alertMinutes as Number) as String {
        var lang = KodeshSettings.getValue("language");
        var isHebrew = lang == null || (lang as String).equals("lang_he");

        if (isHebrew) {
            var format = loadTextResource(Rez.Strings.TextPreShabbatAlertFormat);
            if (format.equals("")) {
                return Lang.format("Shabbat in $1$ min", [alertMinutes]);
            }
            return Lang.format(format, [alertMinutes]);
        }

        return Lang.format("Shabbat in $1$ min", [alertMinutes]);
    }

    function triggerPreShabbatAlert(alertMinutes as Number) as Void {
        Storage.setValue(KEY_PRE_SHABBAT_ALERT_MESSAGE, getPreShabbatAlertDisplayText(alertMinutes));
        Storage.setValue(KEY_PRE_SHABBAT_ALERT_UNTIL, System.getTimer() + PRE_SHABBAT_ALERT_DISPLAY_MS);

        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(90, 450),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(90, 450),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(90, 450)
            ]);
        }

        if (!_isLowPower) {
            WatchUi.requestUpdate();
        }
    }

    function isCurrentDeviceAmoled() as Boolean {
        return deviceRequiresBurnInProtection(System.getDeviceSettings());
    }

    (:test)
    function getShabbatTimesForTest(now as Time.Moment) as ZmanimEngine.ShabbatTimes? {
        return _zmanimEngine.getShabbatTimes(now);
    }

    function drawMipCenteredText(dc as Graphics.Dc, x as Number, y as Number, font, text as String, color as Number) as Void {
        if (text == null || text.equals("")) {
            return;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            y,
            font,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function getMipHebrewFont() {
        try {
            var f = AppFonts.getParashaFont();
            if (f != null) {
                return f;
            }
        } catch (ex) {
        }

        return Graphics.FONT_XTINY;
    }

    function getMipSmallHebrewFont() {
        try {
            var f = AppFonts.getHebrewDateFont();
            if (f != null) {
                return f;
            }
        } catch (ex) {
        }

        return getMipHebrewFont();
    }

    function getMipParashaText(now) as String {
        try {
            var showParasha = KodeshSettings.getValue("showParasha");
            if (showParasha != null && showParasha == false) {
                return "";
            }

            return _parashaLookup.getCurrentParashaName(now);
        } catch (ex) {
        }

        return "";
    }

    function drawMipDigitalFace(dc as Graphics.Dc, clockTime, now, width as Number, height as Number, timeString as String, showSeconds as Boolean) as Void {
        // MIP/Solar production layout:
        // - No screen-protection layout.
        // - No pixel shift.
        // - No analog face.
        // - No large Shabbat progress ring.
        // - Stable clean digital layout for small monochrome/limited-color displays.
        var x = width / 2;
        var primary = Graphics.COLOR_WHITE;
        var secondary = Graphics.COLOR_LT_GRAY;
        var alert = Graphics.COLOR_YELLOW;

        var hebMain = getMipHebrewFont();
        var hebSmall = getMipSmallHebrewFont();

        var omerText = "";
        if (getToggleValue("showOmer", true)) {
            omerText = getOmerText(now);
        }

        var parashaText = getMipParashaText(now);
        var dateText = "";
        if (getToggleValue("showHebrewDate", true)) {
            dateText = getHebrewDateText(now);
        }

        var statusText = getPriorityStatusMessage();
        var timesText = getShabbatTimesText(now);
        var batteryText = getBatteryText();

                if (!ShabbatMode.isEnabled()) {
            var statusFont = AppFonts.getStatusFont();
            if (statusFont == null) {
                statusFont = hebSmall;
            }
            drawMipCenteredText(dc, x + getLayoutOffsetX("status"), (height.toFloat() * 0.5f).toNumber() + getLayoutOffsetY("status"), statusFont, statusText, primary);
            return;
        }

        // Relative layout values are tuned for Instinct 3 Solar 45mm and still
        // scale safely on larger MIP/Fenix/Forerunner screens.
        if (!omerText.equals("")) {
            drawMipCenteredText(dc, x + getLayoutOffsetX("omer"), (height.toFloat() * 0.105f).toNumber() + getLayoutOffsetY("omer"), hebSmall, omerText, alert);
        }

        if (!parashaText.equals("")) {
            drawMipCenteredText(dc, x + getLayoutOffsetX("parasha"), (height.toFloat() * 0.175f).toNumber() + getLayoutOffsetY("parasha"), hebMain, parashaText, secondary);
        }

        if (!dateText.equals("")) {
            drawMipCenteredText(dc, x + getLayoutOffsetX("hebrewDate"), (height.toFloat() * 0.255f).toNumber() + getLayoutOffsetY("hebrewDate"), hebSmall, dateText, secondary);
        }

        if (!statusText.equals("")) {
            var statusFont = AppFonts.getStatusFont();
            if (statusFont == null) {
                statusFont = hebSmall;
            }
            drawMipCenteredText(dc, x + getLayoutOffsetX("status"), (height.toFloat() * 0.345f).toNumber() + getLayoutOffsetY("status"), statusFont, statusText, secondary);
        }

        dc.setColor(primary, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + getLayoutOffsetX("clock"),
            (height.toFloat() * 0.530f).toNumber() + getLayoutOffsetY("clock"),
            getActiveFontForTime(showSeconds, width),
            timeString,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        if (!timesText.equals("")) {
            drawMipCenteredText(dc, x + getLayoutOffsetX("shabbatTimes"), (height.toFloat() * 0.725f).toNumber() + getLayoutOffsetY("shabbatTimes"), AppFonts.getShabbatTimesFont(), timesText, secondary);
        }

        if (!batteryText.equals("")) {
            drawMipCenteredText(dc, x + getLayoutOffsetX("battery"), (height.toFloat() * 0.825f).toNumber() + getLayoutOffsetY("battery"), Graphics.FONT_XTINY, batteryText, secondary);
        }
    }


    function isScreenProtectorEnabled() as Boolean {
        return getToggleValue("screenProtector", true);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var settings = System.getDeviceSettings();
        var clockTime = System.getClockTime();
        var now = Time.now();
        var width = dc.getWidth();
        var height = dc.getHeight();

        var isAmoledLayout = shouldUseAmoledLayout(settings);
        // AOD / burn-in protection layout is driven by manual Shabbat Mode only.
        // Calendar-based Shabbat (isShabbatNow) intentionally does NOT trigger
        // the AOD layout so the app starts in the normal display even on Shabbat.
        var isAod = FORCE_AOD_TEST || (isAmoledLayout && (_isLowPower || isManualShabbatModeEnabled()));
        // Burn-in pixel shift is AMOLED-only and only when the screen protector
        // setting is enabled. When disabled, the display stays static (no shift)
        // but still uses the AMOLED layout.
        var applyBurnInShift = isAod && isScreenProtectorEnabled();
        var shiftX = applyBurnInShift ? getBurnInOffsetX(clockTime, width, height) : 0;
        var shiftY = applyBurnInShift ? getBurnInOffsetY(clockTime, width, height) : 0;
        var useAnalogClock = shouldUseAnalogClockForDevice(settings);
        var centerX = (width / 2) + shiftX + getLayoutOffsetX("clock");
        var centerY = (height / 2) + shiftY + getLayoutOffsetY("clock");

        // Analog mode owns the central circle, so keep it centered.
        // All optional Jewish/Shabbat data is drawn inside the analog face.

        var showSeconds = !isAod && !_isLowPower;
        if (!useAnalogClock) {
            showSeconds = showSeconds && isTimeFormatWithSeconds();
        }

        if (showSeconds != _lastShowSeconds) {
            _lastShowSeconds = showSeconds;
            scheduleNextUpdate();
        }
            
        var timeString = getClockString(clockTime, showSeconds, settings.is24Hour);

        if (!isAmoledLayout) {
            drawMipDigitalFace(dc, clockTime, now, width, height, timeString, showSeconds);
            return;
        }

        if (!useAnalogClock) {
            drawOmer(dc, width, height, now, shiftX, shiftY, isAod);
            drawParasha(dc, width, height, now, shiftX, shiftY);
            drawShabbatModeStatus(dc, width, height, shiftX, shiftY, isAod);
        }

        var progressEntryMoment = null;
        var progressExitMoment = null;
        var progressTimes = _zmanimEngine.getShabbatTimes(now);

        if (progressTimes != null) {
            try {
                progressEntryMoment = progressTimes.entryMoment;
                progressExitMoment = progressTimes.exitMoment;
            } catch (progressEx) {
                progressEntryMoment = null;
                progressExitMoment = null;
            }
        }

        if (shouldDrawShabbatProgressForDevice(settings, useAnalogClock)) {
            try {
                ShabbatProgressRenderer.draw(
                    dc,
                    now,
                    progressEntryMoment,
                    progressExitMoment,
                    centerX + getLayoutOffsetX("progress"),
                    centerY + getLayoutOffsetY("progress"),
                    isAod
                );
            } catch (ex) {
                // Never allow the optional Shabbat progress ring to crash the watch face.
            }
        }

        if (!useAnalogClock) {
            drawShabbatTimes(dc, width, height, now, shiftX, shiftY, isAod);
        }

        if (useAnalogClock) {
            try {
                drawAnalogClock(dc, clockTime, centerX, centerY, width, height, now, isAod, showSeconds);
            } catch (analogEx) {
                dc.setColor(getRenderColor(isAod), Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    centerX,
                    centerY,
                    getActiveFontForTime(showSeconds, width),
                    timeString,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
        } else {
            dc.setColor(getRenderColor(isAod), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centerX,
                centerY,
                getActiveFontForTime(showSeconds, width),
                timeString,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        if (!useAnalogClock) {
            drawHebrewDate(dc, width, height, now, shiftX, shiftY, isAod);
            drawBattery(dc, width, height, shiftX, shiftY, isAod);
        }
    }
}