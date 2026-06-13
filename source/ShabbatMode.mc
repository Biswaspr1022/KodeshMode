import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Sensor;
import Toybox.Position;
import Toybox.WatchUi;

module ShabbatMode {
    const KEY_ENABLED = "manualShabbatMode";
    const KEY_SPECIAL_MODE = "shabbatSpecialMode";
    const KEY_IS_TOUCH = "isTouch";
    const KEY_TOUCH_DISABLED_CONFIRMED = "touchDisabledConfirmed";
    const KEY_STATUS_MESSAGE = "shabbatModeStatusMessage";
    const KEY_STATUS_UNTIL = "shabbatModeStatusUntil";
    const KEY_LAST_GPS_LAT = "lastGpsLat";
    const KEY_LAST_GPS_LON = "lastGpsLon";
    const KEY_FROZEN_GPS_LAT = "shabbatFrozenGpsLat";
    const KEY_FROZEN_GPS_LON = "shabbatFrozenGpsLon";
    const STATUS_DURATION_MS = 5000;
    const GPS_REQUEST_INTERVAL_MS = 60000;
    var _lastGpsRequestTimer as Number = 0;

    function loadTextResource(id) as String {
        try {
            return WatchUi.loadResource(id) as String;
        } catch (ex) {
        }

        return "";
    }

    class CoordinatePair {
        var lat as Float;
        var lon as Float;

        function initialize(aLat as Float, aLon as Float) {
            lat = aLat;
            lon = aLon;
        }
    }

    function isEnabled() as Boolean {
        return KodeshSettings.getBool(KEY_ENABLED, false);
    }

    function isSpecialModeEnabled() as Boolean {
        return KodeshSettings.getBool(KEY_SPECIAL_MODE, false);
    }

    function setSpecialModeEnabled(enabled as Boolean) as Void {
        KodeshSettings.setValue(KEY_SPECIAL_MODE, enabled);
    }

    function isHebrew() as Boolean {
        var lang = KodeshSettings.getValue("language");
        return lang == null || (lang as String).equals("lang_he");
    }

    function shabbatModeOffText() as String {
        if (isHebrew()) {
            return loadTextResource(Rez.Strings.TextShabbatModeOff) + "\nכדי להפעיל לחץ GPS";
        }
        return "Shabbat Mode off\nPress GPS to activate";
    }

    function touchOffRequiredText() as String {
        if (isHebrew()) {
            return loadTextResource(Rez.Strings.TextTouchOffRequired);
        }
        return "Turn touch off first";
    }

    function settingsOnPhoneText() as String {
        if (isHebrew()) {
            return loadTextResource(Rez.Strings.TextSettingsOnPhone);
        }
        return "Settings are on the phone";
    }

    // User-defined touch profile. Garmin does not expose a reliable, universal
    // runtime touch-lock state for every CIQ device profile, so the app setting
    // controls whether touch protection is required for this watch.
    function isTouch() as Boolean {
        return KodeshSettings.getBool(KEY_IS_TOUCH, false);
    }

    function isTouchDisabledConfirmed() as Boolean {
        return KodeshSettings.getBool(KEY_TOUCH_DISABLED_CONFIRMED, false);
    }

    function setTouchDisabledConfirmed(enabled as Boolean) as Void {
        KodeshSettings.setValue(KEY_TOUCH_DISABLED_CONFIRMED, enabled);
    }

    function deviceHasTouchScreen(settings) as Boolean {
        try {
            if (settings == null) {
                return false;
            }

            if (settings has :hasTouchScreen) {
                return settings.hasTouchScreen == true;
            }
            if (settings has :isTouchScreen) {
                return settings.isTouchScreen == true;
            }
            if (settings has :touchScreen) {
                return settings.touchScreen == true;
            }
            if (settings has :touchscreen) {
                return settings.touchscreen == true;
            }
            if (settings has :supportsTouch) {
                return settings.supportsTouch == true;
            }
        } catch (ex) {
        }

        return false;
    }

    function deviceReportsTouchDisabled(settings) as Boolean {
        try {
            if (settings == null) {
                return false;
            }

            if (settings has :touchScreenEnabled) {
                return settings.touchScreenEnabled == false;
            }
            if (settings has :touchscreenEnabled) {
                return settings.touchscreenEnabled == false;
            }
            if (settings has :touchEnabled) {
                return settings.touchEnabled == false;
            }
            if (settings has :isTouchEnabled) {
                return settings.isTouchEnabled == false;
            }
        } catch (ex) {
        }

        return false;
    }

    function canUseTouchForShabbat(settings) as Boolean {
        if (!isTouch()) {
            return true;
        }

        if (deviceReportsTouchDisabled(settings)) {
            return true;
        }

        // When Is Touch is enabled in the phone settings, the user must also
        // confirm from the phone settings that touch has been disabled.
        return isTouchDisabledConfirmed();
    }

    function setStatus(message as String) as Void {
        Storage.setValue(KEY_STATUS_MESSAGE, message);
        Storage.setValue(KEY_STATUS_UNTIL, System.getTimer() + STATUS_DURATION_MS);
    }

    function getStatusMessage() as String {
        var message = Storage.getValue(KEY_STATUS_MESSAGE);
        var until = Storage.getValue(KEY_STATUS_UNTIL);

        if (message != null && until != null && System.getTimer() <= (until as Number)) {
            return message as String;
        }

        if (!isEnabled()) {
            if (Storage.getValue("hasSeenGuide") == null) {
                if (isHebrew()) {
                    return "לחץ START להפעלה";
                }
                return "Press START to enable";
            }
            return shabbatModeOffText();
        }

        return "";
    }

    function clearStatus() as Void {
        Storage.deleteValue(KEY_STATUS_MESSAGE);
        Storage.deleteValue(KEY_STATUS_UNTIL);
    }

    function isGpsLocationSelected() as Boolean {
        var loc = KodeshSettings.getValue("location");
        return loc != null && (loc as String).equals("loc_gps");
    }

    function saveLastGpsCoordinates(lat as Float, lon as Float) as Void {
        Storage.setValue(KEY_LAST_GPS_LAT, lat);
        Storage.setValue(KEY_LAST_GPS_LON, lon);
    }

    function getStoredCoordinatePair(latKey as String, lonKey as String) {
        var latValue = Storage.getValue(latKey);
        var lonValue = Storage.getValue(lonKey);

        if (latValue == null || lonValue == null) {
            return null;
        }

        var lat = (latValue as Number).toFloat();
        var lon = (lonValue as Number).toFloat();
        return new CoordinatePair(lat, lon);
    }

    function getLastGpsCoordinates() {
        return getStoredCoordinatePair(KEY_LAST_GPS_LAT, KEY_LAST_GPS_LON);
    }

    function getFrozenGpsCoordinates() {
        return getStoredCoordinatePair(KEY_FROZEN_GPS_LAT, KEY_FROZEN_GPS_LON);
    }

    function readCurrentGpsAndRemember() as Boolean {
        try {
            var info = Position.getInfo();

            if (info == null || info.position == null) {
                return false;
            }

            var rawDeg = info.position.toDegrees();

            var deg = rawDeg as Array<Number>;
            if (deg.size() < 2) {
                return false;
            }

            var lat = (deg[0] as Number).toFloat();
            var lon = (deg[1] as Number).toFloat();
            saveLastGpsCoordinates(lat, lon);
            return true;
        } catch (ex) {
        }

        return false;
    }


    function requestGpsUpdate() as Void {
        // Compatibility wrapper used by ZmanimEngine.
        // On some targets, module-level method(:callback) is not supported,
        // so we keep this production-safe: read cached GPS info only and throttle it.
        try {
            var nowTimer = System.getTimer();
            if (_lastGpsRequestTimer > 0 && (nowTimer - _lastGpsRequestTimer) < GPS_REQUEST_INTERVAL_MS) {
                return;
            }
            _lastGpsRequestTimer = nowTimer;
        } catch (ex) {
        }

        readCurrentGpsAndRemember();
    }

    function freezeLastGpsLocation() as Boolean {
        if (!isGpsLocationSelected()) {
            return true;
        }

        readCurrentGpsAndRemember();
        var coords = getLastGpsCoordinates();

        if (coords == null) {
            setStatus("No saved GPS fix");
            return false;
        }

        Storage.setValue(KEY_FROZEN_GPS_LAT, coords.lat);
        Storage.setValue(KEY_FROZEN_GPS_LON, coords.lon);
        return true;
    }

    function disableAppOwnedSensors() as Void {
        try {
            Sensor.setEnabledSensors([]);
        } catch (ex) {
        }

        try {
            Sensor.enableSensorEvents(null);
        } catch (ex2) {
        }

        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        } catch (ex3) {
        }
    }

    function canEnable() as Boolean {
        var settings = System.getDeviceSettings();

        // Touch is a hard Shabbat guard. Special Mode bypasses activity/
        // connection checks, but it does not bypass touch-screen protection.
        if (!canUseTouchForShabbat(settings)) {
            setStatus(touchOffRequiredText());
            return false;
        }

        if (isSpecialModeEnabled()) {
            return true;
        }

        if (settings has :activityTrackingOn && settings.activityTrackingOn) {
            setStatus("Turn Activity Tracking off");
            return false;
        }

        if (settings has :phoneConnected && settings.phoneConnected) {
            setStatus("Turn Bluetooth off");
            return false;
        }

        if (settings has :connectionAvailable && settings.connectionAvailable) {
            setStatus("Turn connections off");
            return false;
        }

        return true;
    }

    function enable() as Boolean {
        if (!freezeLastGpsLocation()) {
            KodeshSettings.setValue(KEY_ENABLED, false);
            return false;
        }

        if (!canEnable()) {
            KodeshSettings.setValue(KEY_ENABLED, false);
            return false;
        }

        if (!isSpecialModeEnabled()) {
            disableAppOwnedSensors();
        }

        KodeshSettings.setValue(KEY_ENABLED, true);
        Storage.setValue("hasSeenGuide", true);
        clearStatus();
        return true;
    }

    function disable() as Boolean {
        KodeshSettings.setValue(KEY_ENABLED, false);
        setStatus(shabbatModeOffText());
        return true;
    }
}
