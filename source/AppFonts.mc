import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Application.Storage;
import Toybox.Lang;

module AppFonts {
    var mClockFont = null;
    var mClockFontKey as String = "";
    var mHebrewTextFont = null;
    var mHebrewTextFontKey as String = "";
    var mParashaFont = null;
    var mParashaFontKey as String = "";
    var mHebrewDateFont = null;
    var mHebrewDateFontKey as String = "";
    var mShabbatTimesFont = null;
    var mShabbatTimesFontKey as String = "";

    function clearCustomFontCache() as Void {
        mClockFont = null;
        mClockFontKey = "";
        mHebrewTextFont = null;
        mHebrewTextFontKey = "";
        mParashaFont = null;
        mParashaFontKey = "";
        mHebrewDateFont = null;
        mHebrewDateFontKey = "";
        mShabbatTimesFont = null;
        mShabbatTimesFontKey = "";
    }

    function releaseLoadedFonts() as Void {
        clearCustomFontCache();
    }

    function getClockFontMode() as String {
        var value = KodeshSettings.getValue("clockFont");

        if (value == null) {
            return "clock_system";
        }

        var str = value as String;

        if (str.equals("clock_varela") || str.equals("clock_varela_36") || str.equals("clock_varela_28")) {
            return "clock_varela";
        }

        if (str.equals("clock_stam") || str.equals("clock_stam_30")) {
            return "clock_stam";
        }

        if (str.equals("clock_simple") || str.equals("clock_simple_28")) {
            return "clock_simple";
        }

        return "clock_system";
    }

    function setClockFontMode(value as String) as Void {
        KodeshSettings.setValue("clockFont", value);
        clearCustomFontCache();
    }

    function getClockFontLabel() as String {
        var value = getClockFontMode();

        if (value.equals("clock_varela")) { return "Varela"; }
        if (value.equals("clock_stam")) { return "Stam"; }
        if (value.equals("clock_simple")) { return "Simple"; }

        return "System";
    }

    function normalizeClockSize(value as String) as String {
        // Keep only six bitmap font sizes to reduce the compiled PRG size.
        // Legacy values are mapped to the nearest supported size.
        if (value.equals("clock_size_24") || value.equals("24") || value.equals("22") || value.equals("18") || value.equals("clock_size_22") || value.equals("clock_size_18") || value.equals("clock_size_small")) { return "clock_size_24"; }
        if (value.equals("clock_size_28") || value.equals("28") || value.equals("30") || value.equals("clock_size_30")) { return "clock_size_28"; }
        if (value.equals("clock_size_36") || value.equals("36") || value.equals("clock_size_medium")) { return "clock_size_36"; }
        if (value.equals("clock_size_52") || value.equals("52") || value.equals("44") || value.equals("clock_size_44") || value.equals("clock_size_large")) { return "clock_size_52"; }
        if (value.equals("clock_size_68") || value.equals("68") || value.equals("60") || value.equals("clock_size_60") || value.equals("clock_size_huge")) { return "clock_size_68"; }
        if (value.equals("clock_size_84") || value.equals("84") || value.equals("76") || value.equals("clock_size_76")) { return "clock_size_84"; }

        return "clock_size_36";
    }

    function stringFromSettingValue(value) as String {
        if (value == null) {
            return "";
        }

        try {
            return value as String;
        } catch (stringEx) {
        }

        try {
            return (value as Number).format("%d");
        } catch (numberEx) {
        }

        return "";
    }

    function getClockSizeMode() as String {
        var value = KodeshSettings.getValue("clockSize");

        if (value != null) {
            var valueString = stringFromSettingValue(value);
            if (!valueString.equals("")) {
                return normalizeClockSize(valueString);
            }
        }

        var oldFont = KodeshSettings.getValue("clockFont");

        if (oldFont != null) {
            var old = oldFont as String;

            if (old.equals("clock_varela_36") || old.equals("clock_stam_30")) {
                return "clock_size_36";
            }

            if (old.equals("clock_varela_28") || old.equals("clock_simple_28")) {
                return "clock_size_28";
            }
        }

        return "clock_size_36";
    }

    function setClockSizeMode(value as String) as Void {
        KodeshSettings.setValue("clockSize", normalizeClockSize(value));
        clearCustomFontCache();
    }

    function getClockSizeLabel() as String {
        return getSizeLabelForMode(getClockSizeMode());
    }

    function getSizeModeForKey(key as String, defaultValue as String) as String {
        var value = KodeshSettings.getValue(key);

        if (value == null) {
            return normalizeClockSize(defaultValue);
        }

        var valueString = stringFromSettingValue(value);
        if (valueString.equals("")) {
            return normalizeClockSize(defaultValue);
        }

        return normalizeClockSize(valueString);
    }

    function getSizeLabelForMode(value as String) as String {
        var normalized = normalizeClockSize(value);

        if (normalized.equals("clock_size_24")) { return "24"; }
        if (normalized.equals("clock_size_28")) { return "28"; }
        if (normalized.equals("clock_size_36")) { return "36"; }
        if (normalized.equals("clock_size_52")) { return "52"; }
        if (normalized.equals("clock_size_68")) { return "68"; }
        if (normalized.equals("clock_size_84")) { return "84"; }

        return "36";
    }

    function getParashaSizeMode() as String {
        return getSizeModeForKey("parashaSize", "clock_size_24");
    }

    function getParashaSizeLabel() as String {
        return getSizeLabelForMode(getParashaSizeMode());
    }

    function getShabbatTimesSizeMode() as String {
        return getSizeModeForKey("shabbatTimesSize", "clock_size_24");
    }

    function getShabbatTimesSizeLabel() as String {
        return getSizeLabelForMode(getShabbatTimesSizeMode());
    }

    function getHebrewDateSizeMode() as String {
        return getSizeModeForKey("hebrewDateSize", "clock_size_24");
    }

    function getHebrewDateSizeLabel() as String {
        return getSizeLabelForMode(getHebrewDateSizeMode());
    }

    function resourceForFont(family as String, sizeMode as String) {
        var size = normalizeClockSize(sizeMode);

        if (family.equals("stam")) {
            if (size.equals("clock_size_24")) { return WatchUi.loadResource(Rez.Fonts.Stam24); }
            if (size.equals("clock_size_28")) { return WatchUi.loadResource(Rez.Fonts.Stam28); }
            if (size.equals("clock_size_36")) { return WatchUi.loadResource(Rez.Fonts.Stam36); }
            if (size.equals("clock_size_52")) { return WatchUi.loadResource(Rez.Fonts.Stam52); }
            if (size.equals("clock_size_68")) { return WatchUi.loadResource(Rez.Fonts.Stam68); }
            return WatchUi.loadResource(Rez.Fonts.Stam84);
        }

        if (family.equals("simple")) {
            if (size.equals("clock_size_24")) { return WatchUi.loadResource(Rez.Fonts.Simple24); }
            if (size.equals("clock_size_28")) { return WatchUi.loadResource(Rez.Fonts.Simple28); }
            if (size.equals("clock_size_36")) { return WatchUi.loadResource(Rez.Fonts.Simple36); }
            if (size.equals("clock_size_52")) { return WatchUi.loadResource(Rez.Fonts.Simple52); }
            if (size.equals("clock_size_68")) { return WatchUi.loadResource(Rez.Fonts.Simple68); }
            return WatchUi.loadResource(Rez.Fonts.Simple84);
        }

        if (size.equals("clock_size_24")) { return WatchUi.loadResource(Rez.Fonts.Varela24); }
        if (size.equals("clock_size_28")) { return WatchUi.loadResource(Rez.Fonts.Varela28); }
        if (size.equals("clock_size_36")) { return WatchUi.loadResource(Rez.Fonts.Varela36); }
        if (size.equals("clock_size_52")) { return WatchUi.loadResource(Rez.Fonts.Varela52); }
        if (size.equals("clock_size_68")) { return WatchUi.loadResource(Rez.Fonts.Varela68); }
        return WatchUi.loadResource(Rez.Fonts.Varela84);
    }

    function getSystemClockFontForSize(sizeMode as String) {
        var size = normalizeClockSize(sizeMode);

        // Garmin built-in system fonts have only a few real sizes. For large
        // clock sizes, switch to generated Varela resources so the selected
        // size is visibly different.
        if (size.equals("clock_size_36") ||
            size.equals("clock_size_52") ||
            size.equals("clock_size_68") ||
            size.equals("clock_size_84")) {
            return getRoleFont("clock", "varela", size);
        }

        if (size.equals("clock_size_24")) {
            return Graphics.FONT_SMALL;
        }

        if (size.equals("clock_size_28")) {
            return Graphics.FONT_MEDIUM;
        }

        return Graphics.FONT_NUMBER_MEDIUM;
    }

    function getRoleFont(role as String, family as String, sizeMode as String) {
        var key = role + ":" + family + ":" + normalizeClockSize(sizeMode);

        if (role.equals("clock")) {
            if (mClockFont != null && mClockFontKey.equals(key)) { return mClockFont; }
            mClockFont = null;
            mClockFontKey = key;
            mClockFont = resourceForFont(family, sizeMode);
            return mClockFont;
        }

        if (role.equals("hebrewText")) {
            if (mHebrewTextFont != null && mHebrewTextFontKey.equals(key)) { return mHebrewTextFont; }
            mHebrewTextFont = null;
            mHebrewTextFontKey = key;
            mHebrewTextFont = resourceForFont(family, sizeMode);
            return mHebrewTextFont;
        }

        if (role.equals("parasha")) {
            if (mParashaFont != null && mParashaFontKey.equals(key)) { return mParashaFont; }
            mParashaFont = null;
            mParashaFontKey = key;
            mParashaFont = resourceForFont(family, sizeMode);
            return mParashaFont;
        }

        if (role.equals("hebrewDate")) {
            if (mHebrewDateFont != null && mHebrewDateFontKey.equals(key)) { return mHebrewDateFont; }
            mHebrewDateFont = null;
            mHebrewDateFontKey = key;
            mHebrewDateFont = resourceForFont(family, sizeMode);
            return mHebrewDateFont;
        }

        if (mShabbatTimesFont != null && mShabbatTimesFontKey.equals(key)) { return mShabbatTimesFont; }
        mShabbatTimesFont = null;
        mShabbatTimesFontKey = key;
        mShabbatTimesFont = resourceForFont(family, sizeMode);
        return mShabbatTimesFont;
    }

    function getCustomFontForFamilyAndSize(family as String, sizeMode as String) {
        return getRoleFont("clock", family, sizeMode);
    }

    function getFontForClockFamily(family as String, sizeMode as String) {
        if (family.equals("clock_system")) {
            return getSystemClockFontForSize(sizeMode);
        }

        var fam = "varela";
        if (family.equals("clock_stam")) { fam = "stam"; }
        else if (family.equals("clock_simple")) { fam = "simple"; }

        return getRoleFont("clock", fam, sizeMode);
    }

    function getVarelaFontForSize(sizeMode as String) {
        return getRoleFont("hebrewText", "varela", sizeMode);
    }

    function getParashaFont() {
        return getRoleFont("parasha", "varela", getParashaSizeMode());
    }

    function getShabbatTimesFont() {
        return getRoleFont("shabbatTimes", "varela", getShabbatTimesSizeMode());
    }

    function getHebrewDateFont() {
        return getRoleFont("hebrewDate", "varela", getHebrewDateSizeMode());
    }

    function getHebrewTextFont() {
        return getRoleFont("hebrewText", "varela", getHebrewDateSizeMode());
    }

    function getClockFont() {
        var fontMode = getClockFontMode();
        var sizeMode = getClockSizeMode();

        if (fontMode.equals("clock_system")) {
            return getSystemClockFontForSize(sizeMode);
        }

        if (fontMode.equals("clock_stam")) {
            return getRoleFont("clock", "stam", sizeMode);
        }

        if (fontMode.equals("clock_simple")) {
            return getRoleFont("clock", "simple", sizeMode);
        }

        return getRoleFont("clock", "varela", sizeMode);
    }
}
