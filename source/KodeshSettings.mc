import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.Lang;

module KodeshSettings {

    function getValue(key as String) {
        // Phone / Garmin Connect / simulator Application.Properties are the
        // source of truth for user settings. Storage is only a fallback for
        // runtime-only values and legacy keys that are not present in properties.
        try {
            var propertyValue = Properties.getValue(key);
            if (propertyValue != null) {
                return normalizeValueForRead(key, propertyValue);
            }
        } catch (propertyEx) {
        }

        try {
            var storageValue = Storage.getValue(key);
            if (storageValue != null) {
                return normalizeValueForRead(key, storageValue);
            }
        } catch (storageEx) {
        }

        return null;
    }

    function setValue(key as String, value) as Void {
        var propertyValue = value;
        var storageValue = value;

        if (isListSettingKey(key)) {
            propertyValue = numberForChoiceValue(key, value);
            storageValue = stringForNumberChoice(key, propertyValue as Number);
        }

        try {
            Properties.setValue(key, propertyValue);
        } catch (ex) {
        }

        try {
            Storage.setValue(key, storageValue);
        } catch (ex2) {
        }

        clearLocalOverride(key);
    }

    function setLocalValue(key as String, value) as Void {
        // On-watch settings have been removed. Keep this wrapper for any older
        // call sites, but write through the same phone-backed settings path and
        // do not create local overrides.
        setValue(key, value);
    }

    function localOverrideKey(key as String) as String {
        return "localOverride_" + key;
    }

    function hasLocalOverride(key as String) as Boolean {
        try {
            return Storage.getValue(localOverrideKey(key)) == true;
        } catch (ex) {
        }

        return false;
    }

    function clearLocalOverride(key as String) as Void {
        try {
            Storage.setValue(localOverrideKey(key), false);
        } catch (ex) {
        }
    }

    function getString(key as String, defaultValue as String) as String {
        var value = getValue(key);

        if (value == null) {
            return defaultValue;
        }

        try {
            return value as String;
        } catch (ex) {
        }

        return defaultValue;
    }

    function getBool(key as String, defaultValue as Boolean) as Boolean {
        var value = getValue(key);

        if (value == null) {
            return defaultValue;
        }

        return value == true;
    }

    function getNumber(key as String, defaultValue as Number) as Number {
        var value = getValue(key);

        if (value == null) {
            return defaultValue;
        }

        if (value instanceof Number) {
            return value as Number;
        }

        if (value instanceof String) {
            try {
                var num = (value as String).toNumber();
                if (num != null) {
                    return num;
                }
            } catch (stringNumberEx) {
            }
        }

        return defaultValue;
    }

    function getLayoutOffsetX(itemKey as String) as Number {
        return getNumber(itemKey + "X", 0);
    }

    function getLayoutOffsetY(itemKey as String) as Number {
        return getNumber(itemKey + "Y", 0);
    }

    function getPropertyBackedKeys() as Array<String> {
        return [
            "clockStyle", "clockFont", "clockSize", "fontColor", "timeFormat",
            "language", "showParasha", "showHebrewDate", "hebrewDateSize",
            "showOmer", "showBattery", "parashaSize", "showShabbatTimes",
            "shabbatTimesSize", "statusSize", "shabbatProgress", "screenProtector", "location", "endMethod",
            "candleOffset", "preShabbatAlert", "parashaSchedule",
            "isTouch", "touchDisabledConfirmed", "shabbatSpecialMode",
            "clockX", "clockY", "progressX", "progressY", "omerX", "omerY",
            "parashaX", "parashaY", "statusX", "statusY", "hebrewDateX", "hebrewDateY",
            "shabbatTimesX", "shabbatTimesY", "batteryX", "batteryY"
        ] as Array<String>;
    }

    function syncPropertiesToStorage() as Void {
        var keys = getPropertyBackedKeys() as Array<String>;

        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i] as String;
            var propertyValue = null;

            try {
                propertyValue = Properties.getValue(key);
            } catch (propertyEx) {
                propertyValue = null;
            }

            if (propertyValue != null) {
                try {
                    Storage.setValue(key, normalizeValueForRead(key, propertyValue));
                } catch (storageEx) {
                }

                clearLocalOverride(key);
            }
        }
    }

    function initializeMissingStorageFromProperties() as Void {
        // On a fresh install, Storage may be empty while App Properties already
        // contain values from Garmin Connect / CIQ settings. Copy only missing
        // keys so existing watch-menu choices are not overwritten on every start.
        var keys = getPropertyBackedKeys() as Array<String>;

        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i] as String;
            var storageValue = null;

            try {
                storageValue = Storage.getValue(key);
            } catch (storageEx) {
                storageValue = null;
            }

            if (storageValue == null) {
                var propertyValue = null;

                try {
                    propertyValue = Properties.getValue(key);
                } catch (propertyEx) {
                    propertyValue = null;
                }

                if (propertyValue != null) {
                    try {
                        Storage.setValue(key, normalizeValueForRead(key, propertyValue));
                    } catch (setEx) {
                    }
                }
            }
        }
    }

    function isListSettingKey(key as String) as Boolean {
        return key.equals("clockStyle") ||
            key.equals("clockFont") ||
            key.equals("clockSize") ||
            key.equals("fontColor") ||
            key.equals("timeFormat") ||
            key.equals("language") ||
            key.equals("hebrewDateSize") ||
            key.equals("parashaSize") ||
            key.equals("shabbatTimesSize") ||
            key.equals("statusSize") ||
            key.equals("location") ||
            key.equals("endMethod") ||
            key.equals("candleOffset") ||
            key.equals("preShabbatAlert") ||
            key.equals("parashaSchedule");
    }

    function normalizeValueForRead(key as String, value) {
        if (!isListSettingKey(key)) {
            return value;
        }

        if (value instanceof Number || value instanceof Float || value instanceof Long || value instanceof Double) {
            try {
                return stringForNumberChoice(key, value.toNumber());
            } catch (ex) {
            }
        }

        try {
            return normalizeStringChoice(key, value.toString());
        } catch (stringEx) {
        }

        return defaultStringForKey(key);
    }

    function numberForChoiceValue(key as String, value) as Number {
        try {
            return numberForNumberChoice(key, value as Number);
        } catch (numberEx) {
        }

        try {
            return numberForStringChoice(key, value as String);
        } catch (stringEx) {
        }

        return defaultNumberForKey(key);
    }

    function numberForNumberChoice(key as String, value as Number) as Number {
        return numberForStringChoice(key, stringForNumberChoice(key, value));
    }

    function normalizeStringChoice(key as String, value as String) as String {
        return stringForNumberChoice(key, numberForStringChoice(key, value));
    }

    function defaultStringForKey(key as String) as String {
        if (key.equals("clockStyle")) { return "clock_digital"; }
        if (key.equals("clockFont")) { return "clock_system"; }
        if (key.equals("clockSize")) { return "clock_size_36"; }
        if (key.equals("fontColor")) { return "color_white"; }
        if (key.equals("timeFormat")) { return "format_hm"; }
        if (key.equals("language")) { return "lang_he"; }
        if (key.equals("hebrewDateSize")) { return "clock_size_24"; }
        if (key.equals("parashaSize")) { return "clock_size_24"; }
        if (key.equals("shabbatTimesSize")) { return "clock_size_24"; }
        if (key.equals("location")) { return "loc_jerusalem"; }
        if (key.equals("endMethod")) { return "end_geonim"; }
        if (key.equals("candleOffset")) { return "offset_20"; }
        if (key.equals("preShabbatAlert")) { return "alert_15"; }
        if (key.equals("parashaSchedule")) { return "israel"; }
        return "";
    }

    function defaultNumberForKey(key as String) as Number {
        return numberForStringChoice(key, defaultStringForKey(key));
    }

    function isDefaultStringValue(key as String, value) as Boolean {
        if (value == null) {
            return false;
        }

        try {
            var def = defaultStringForKey(key);
            return value.toString().equals(def);
        } catch (ex) {
        }

        return false;
    }

    function numberForStringChoice(key as String, value as String) as Number {
        if (key.equals("clockStyle")) {
            if (value.equals("clock_analog") || value.equals("1")) { return 1; }
            return 0;
        }

        if (key.equals("clockFont")) {
            if (value.equals("clock_varela") || value.equals("clock_varela_36") || value.equals("clock_varela_28") || value.equals("1")) { return 1; }
            if (value.equals("clock_stam") || value.equals("clock_stam_30") || value.equals("2")) { return 2; }
            if (value.equals("clock_simple") || value.equals("clock_simple_28") || value.equals("3")) { return 3; }
            return 0;
        }

        if (key.equals("clockSize") || key.equals("hebrewDateSize") || key.equals("parashaSize") || key.equals("shabbatTimesSize") || key.equals("statusSize")) {
            if (value.equals("clock_size_12") || value.equals("12")) { return 12; }
            if (value.equals("clock_size_18") || value.equals("18")) { return 18; }
            if (value.equals("clock_size_24") || value.equals("clock_size_small") || value.equals("24") || value.equals("22") || value.equals("clock_size_22")) { return 24; }
            if (value.equals("clock_size_28") || value.equals("28") || value.equals("30") || value.equals("clock_size_30")) { return 28; }
            if (value.equals("clock_size_36") || value.equals("clock_size_medium") || value.equals("36")) { return 36; }
            if (value.equals("clock_size_52") || value.equals("clock_size_large") || value.equals("52") || value.equals("44") || value.equals("clock_size_44")) { return 52; }
            if (value.equals("clock_size_68") || value.equals("clock_size_huge") || value.equals("68") || value.equals("60") || value.equals("clock_size_60")) { return 68; }
            if (value.equals("clock_size_84") || value.equals("84") || value.equals("76") || value.equals("clock_size_76")) { return 84; }
            return sizeDefaultNumberForKey(key);
        }

        if (key.equals("fontColor")) {
            if (value.equals("color_gray") || value.equals("1")) { return 1; }
            if (value.equals("color_yellow") || value.equals("2")) { return 2; }
            if (value.equals("color_red") || value.equals("3")) { return 3; }
            if (value.equals("color_green") || value.equals("4")) { return 4; }
            if (value.equals("color_blue") || value.equals("5")) { return 5; }
            if (value.equals("color_orange") || value.equals("6")) { return 6; }
            return 0;
        }

        if (key.equals("timeFormat")) {
            if (value.equals("format_hms") || value.equals("1")) { return 1; }
            return 0;
        }

        if (key.equals("language")) {
            if (value.equals("lang_en") || value.equals("1")) { return 1; }
            return 0;
        }

        if (key.equals("location")) {
            if (value.equals("loc_telaviv") || value.equals("1")) { return 1; }
            if (value.equals("loc_haifa") || value.equals("2")) { return 2; }
            if (value.equals("loc_eilat") || value.equals("3")) { return 3; }
            if (value.equals("loc_gps") || value.equals("4")) { return 4; }
            return 0;
        }

        if (key.equals("endMethod")) {
            if (value.equals("end_rt") || value.equals("1")) { return 1; }
            return 0;
        }

        if (key.equals("candleOffset")) {
            if (value.equals("offset_30") || value.equals("30")) { return 30; }
            if (value.equals("offset_40") || value.equals("40")) { return 40; }
            return 20;
        }

        if (key.equals("preShabbatAlert")) {
            if (value.equals("alert_5") || value.equals("5")) { return 5; }
            if (value.equals("alert_10") || value.equals("10")) { return 10; }
            if (value.equals("alert_15") || value.equals("15")) { return 15; }
            if (value.equals("alert_30") || value.equals("30")) { return 30; }
            if (value.equals("alert_40") || value.equals("40")) { return 40; }
            if (value.equals("alert_60") || value.equals("60")) { return 60; }
            if (value.equals("alert_off") || value.equals("0")) { return 0; }
            return 15;
        }

        if (key.equals("parashaSchedule")) {
            if (value.equals("diaspora") || value.equals("1")) { return 1; }
            return 0;
        }

        return 0;
    }

    function sizeDefaultNumberForKey(key as String) as Number {
        if (key.equals("hebrewDateSize")) { return 24; }
        if (key.equals("parashaSize")) { return 24; }
        if (key.equals("shabbatTimesSize")) { return 24; }
        if (key.equals("statusSize")) { return 8; }
        return 36;
    }

    function stringForNumberChoice(key as String, value as Number) as String {
        if (key.equals("clockStyle")) {
            if (value == 1) { return "clock_analog"; }
            return "clock_digital";
        }

        if (key.equals("clockFont")) {
            if (value == 1) { return "clock_varela"; }
            if (value == 2) { return "clock_stam"; }
            if (value == 3) { return "clock_simple"; }
            return "clock_system";
        }

        if (key.equals("clockSize") || key.equals("hebrewDateSize") || key.equals("parashaSize") || key.equals("shabbatTimesSize") || key.equals("statusSize")) {
            if (value == 12) { return "clock_size_12"; }
            if (value == 18) { return "clock_size_18"; }
            if (value == 24 || value == 22) { return "clock_size_24"; }
            if (value == 28 || value == 30) { return "clock_size_28"; }
            if (value == 36) { return "clock_size_36"; }
            if (value == 52 || value == 44) { return "clock_size_52"; }
            if (value == 68 || value == 60) { return "clock_size_68"; }
            if (value == 84 || value == 76) { return "clock_size_84"; }
            return stringForNumberChoice(key, sizeDefaultNumberForKey(key));
        }

        if (key.equals("fontColor")) {
            if (value == 1) { return "color_gray"; }
            if (value == 2) { return "color_yellow"; }
            if (value == 3) { return "color_red"; }
            if (value == 4) { return "color_green"; }
            if (value == 5) { return "color_blue"; }
            if (value == 6) { return "color_orange"; }
            return "color_white";
        }

        if (key.equals("timeFormat")) {
            if (value == 1) { return "format_hms"; }
            return "format_hm";
        }

        if (key.equals("language")) {
            if (value == 1) { return "lang_en"; }
            return "lang_he";
        }

        if (key.equals("location")) {
            if (value == 1) { return "loc_telaviv"; }
            if (value == 2) { return "loc_haifa"; }
            if (value == 3) { return "loc_eilat"; }
            if (value == 4) { return "loc_gps"; }
            return "loc_jerusalem";
        }

        if (key.equals("endMethod")) {
            if (value == 1) { return "end_rt"; }
            return "end_geonim";
        }

        if (key.equals("candleOffset")) {
            if (value == 30) { return "offset_30"; }
            if (value == 40) { return "offset_40"; }
            return "offset_20";
        }

        if (key.equals("preShabbatAlert")) {
            if (value == 5) { return "alert_5"; }
            if (value == 10) { return "alert_10"; }
            if (value == 30) { return "alert_30"; }
            if (value == 40) { return "alert_40"; }
            if (value == 60) { return "alert_60"; }
            if (value == 0) { return "alert_off"; }
            return "alert_15";
        }

        if (key.equals("parashaSchedule")) {
            if (value == 1) { return "diaspora"; }
            return "israel";
        }

        return "";
    }

    function migrateLegacyStorageToProperties() as Void {
        // Phone-only settings mode: do not copy old Storage display/settings
        // values into Application.Properties. Old local overrides are what made
        // clockFont/clockSize get stuck on System/36.
        var migrated = null;

        try {
            migrated = Storage.getValue("settingsPhoneOnlyV1");
        } catch (ex) {
        }

        if (migrated != null && migrated == true) {
            return;
        }

        clearAllLocalOverrides();

        try {
            Storage.setValue("settingsPhoneOnlyV1", true);
        } catch (setEx) {
        }
    }



    function debugPropertyValue(key as String) as String {
        var str = "ex";
        try {
            var val = Properties.getValue(key);
            str = (val == null) ? "null" : val.toString();
        } catch (propertyEx) {
        }
        return str;
    }

    function debugStorageValue(key as String) as String {
        var str = "ex";
        try {
            var val = Storage.getValue(key);
            str = (val == null) ? "null" : val.toString();
        } catch (storageEx) {
        }
        return str;
    }

    function debugLocalOverrideValue(key as String) as String {
        try {
            if (Storage.getValue(localOverrideKey(key)) == true) {
                return "1";
            }
            return "0";
        } catch (overrideEx) {
        }

        return "ex";
    }

    function debugRawValue(key as String) as String {
        var propertyText = "P=?";
        var storageText = "S=?";
        var overrideText = "L=0";

        try {
            var propertyValue = Properties.getValue(key);
            if (propertyValue != null) {
                propertyText = "P=" + propertyValue.toString();
            } else {
                propertyText = "P=null";
            }
        } catch (propertyEx) {
            propertyText = "P=ex";
        }

        try {
            var storageValue = Storage.getValue(key);
            if (storageValue != null) {
                storageText = "S=" + storageValue.toString();
            } else {
                storageText = "S=null";
            }
        } catch (storageEx) {
            storageText = "S=ex";
        }

        try {
            if (Storage.getValue(localOverrideKey(key)) == true) {
                overrideText = "L=1";
            }
        } catch (overrideEx) {
            overrideText = "L=ex";
        }

        return propertyText + " " + storageText + " " + overrideText;
    }

    function resetAll() as Void {
        setValue("clockStyle", "clock_digital");
        setValue("clockFont", "clock_system");
        setValue("clockSize", "clock_size_36");
        setValue("fontColor", "color_white");
        setValue("timeFormat", "format_hm");

        setValue("language", "lang_he");
        setValue("showParasha", true);
        setValue("showHebrewDate", true);
        setValue("hebrewDateSize", "clock_size_24");
        setValue("showOmer", true);
        setValue("showBattery", false);
        setValue("parashaSize", "clock_size_24");
        setValue("showShabbatTimes", false);
        setValue("shabbatTimesSize", "clock_size_24");
        setValue("shabbatProgress", true);
        setValue("screenProtector", true);

        resetLayoutOffsets();

        setValue("location", "loc_jerusalem");
        setValue("endMethod", "end_geonim");
        setValue("candleOffset", "offset_20");
        setValue("preShabbatAlert", "alert_15");
        setValue("parashaSchedule", "israel");

        setValue("manualShabbatMode", false);
        setValue("isTouch", false);
        setValue("touchDisabledConfirmed", false);
        setValue("shabbatSpecialMode", false);

        clearAllLocalOverrides();

        safeDelete("lastPreShabbatAlertKey");
        safeDelete("preShabbatAlertMessage");
        safeDelete("preShabbatAlertUntil");
        safeDelete("shabbatModeStatusMessage");
        safeDelete("shabbatModeStatusUntil");
        safeDelete("shabbatFrozenGpsLat");
        safeDelete("shabbatFrozenGpsLon");
        safeDelete("hasSeenGuide");
    }

    function resetLayoutOffsets() as Void {
        setValue("clockX", 0);
        setValue("clockY", 0);
        setValue("progressX", 0);
        setValue("progressY", 0);
        setValue("omerX", 0);
        setValue("omerY", 0);
        setValue("parashaX", 0);
        setValue("parashaY", 0);
        setValue("statusX", 0);
        setValue("statusY", 0);
        setValue("hebrewDateX", 0);
        setValue("hebrewDateY", 0);
        setValue("shabbatTimesX", 0);
        setValue("shabbatTimesY", 0);
        setValue("batteryX", 0);
        setValue("batteryY", 0);
    }

    function clearAllLocalOverrides() as Void {
        var keys = getPropertyBackedKeys() as Array<String>;

        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i] as String;
            clearLocalOverride(key);
        }
    }

    function safeDelete(key as String) as Void {
        try {
            Storage.deleteValue(key);
        } catch (ex) {
        }
    }
}
