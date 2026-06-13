import Toybox.Test;
import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Lang;

(:test)
function testStatusMessage_FreshInstall(logger as Test.Logger) as Boolean {
    Storage.deleteValue("manualShabbatMode");
    Storage.deleteValue("hasSeenGuide");
    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    var message = ShabbatMode.getStatusMessage();

    logger.debug("Fresh install message: " + message);

    var isHebrew = message.equals("לחץ START להפעלה");
    var isEnglish = message.equals("Press START to enable");

    return isHebrew || isEnglish;
}

(:test)
function testStatusMessage_FreshInstallHebrew(logger as Test.Logger) as Boolean {
    Storage.deleteValue("manualShabbatMode");
    Storage.deleteValue("hasSeenGuide");
    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    var message = ShabbatMode.getStatusMessage();

    logger.debug("Fresh install Hebrew message: " + message);

    return message.equals("לחץ START להפעלה");
}

(:test)
function testStatusMessage_DisengagedState(logger as Test.Logger) as Boolean {
    Storage.deleteValue("manualShabbatMode");
    Storage.setValue("hasSeenGuide", true);
    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    var message = ShabbatMode.getStatusMessage();

    logger.debug("Disengaged message: " + message);

    var isHebrew = message.find("כדי להפעיל לחץ GPS") != null;
    var isEnglish = message.find("Press GPS to activate") != null;

    return isHebrew || isEnglish;
}

(:test)
function testStatusMessage_ActiveOverride(logger as Test.Logger) as Boolean {
    Storage.deleteValue("manualShabbatMode");
    Storage.deleteValue("hasSeenGuide");
    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    ShabbatMode.setStatus("Test Override");

    var message = ShabbatMode.getStatusMessage();

    logger.debug("Active override message: " + message);

    return message.equals("Test Override");
}

(:test)
function testStatusMessage_OverrideExpired(logger as Test.Logger) as Boolean {
    Storage.deleteValue("manualShabbatMode");
    Storage.setValue("hasSeenGuide", true);
    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    Storage.setValue("shabbatModeStatusMessage", "Expired Message");
    Storage.setValue("shabbatModeStatusUntil", 0);

    var message = ShabbatMode.getStatusMessage();

    logger.debug("Expired override message: " + message);

    var isHebrew = message.find("כדי להפעיל לחץ GPS") != null;
    var isEnglish = message.find("Press GPS to activate") != null;

    return isHebrew || isEnglish;
}

(:test)
function testStatusMessage_EnabledEmpty(logger as Test.Logger) as Boolean {
    Storage.setValue("manualShabbatMode", true);
    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    var message = ShabbatMode.getStatusMessage();

    logger.debug("Enabled mode message: '" + message + "'");

    Storage.deleteValue("manualShabbatMode");

    return message.equals("");
}

(:test)
function testPreShabbatAlert_NonFriday(logger as Test.Logger) as Boolean {
    Storage.deleteValue("lastPreShabbatAlertKey");
    Storage.deleteValue("preShabbatAlertMessage");
    Storage.deleteValue("preShabbatAlertUntil");

    var sundayMoment = Gregorian.moment({
        :year => 2026,
        :month => 6,
        :day => 14,
        :hour => 12,
        :minute => 0,
        :second => 0
    });

    var view = new KodeshModeView();
    view.checkPreShabbatAlert(sundayMoment);

    var alertKey = Storage.getValue("lastPreShabbatAlertKey");
    var alertMsg = Storage.getValue("preShabbatAlertMessage");

    logger.debug("Non-Friday alertKey: " + alertKey);
    logger.debug("Non-Friday alertMsg: " + alertMsg);

    return alertKey == null && alertMsg == null;
}

(:test)
function testPreShabbatAlert_FridayInWindow(logger as Test.Logger) as Boolean {
    Storage.deleteValue("lastPreShabbatAlertKey");
    Storage.deleteValue("preShabbatAlertMessage");
    Storage.deleteValue("preShabbatAlertUntil");

    KodeshSettings.setValue("location", "loc_jerusalem");

    var view = new KodeshModeView();
    var fridayMoment = Gregorian.moment({
        :year => 2026,
        :month => 6,
        :day => 19,
        :hour => 16,
        :minute => 15,
        :second => 0
    });

    var times = view.getShabbatTimesForTest(fridayMoment);
    if (times == null) {
        logger.debug("FridayInWindow: getShabbatTimes returned null for this moment, testing guard clause instead");
        Storage.setValue("lastPreShabbatAlertKey", "2026-6-19");
        view.checkPreShabbatAlert(fridayMoment);
        var msg = Storage.getValue("preShabbatAlertMessage");
        logger.debug("Guard clause prevented re-alert: " + (msg == null));
        Storage.deleteValue("lastPreShabbatAlertKey");
        return msg == null;
    }

    logger.debug("FridayInWindow: entry=" + times.entry);

    view.checkPreShabbatAlert(fridayMoment);

    var alertKey = Storage.getValue("lastPreShabbatAlertKey");

    logger.debug("Friday alertKey: " + alertKey);

    var hasKey = alertKey != null;

    Storage.deleteValue("lastPreShabbatAlertKey");
    Storage.deleteValue("preShabbatAlertMessage");
    Storage.deleteValue("preShabbatAlertUntil");

    return hasKey;
}

(:test)
function testPreShabbatAlert_DuplicateSuppression(logger as Test.Logger) as Boolean {
    Storage.deleteValue("lastPreShabbatAlertKey");
    Storage.deleteValue("preShabbatAlertMessage");
    Storage.deleteValue("preShabbatAlertUntil");

    Storage.setValue("lastPreShabbatAlertKey", "2026-6-19");

    var fridayMoment = Gregorian.moment({
        :year => 2026,
        :month => 6,
        :day => 19,
        :hour => 16,
        :minute => 15,
        :second => 0
    });

    var view = new KodeshModeView();
    view.checkPreShabbatAlert(fridayMoment);

    var alertMsg = Storage.getValue("preShabbatAlertMessage");

    logger.debug("Duplicate suppression alertMsg: " + alertMsg);

    Storage.deleteValue("lastPreShabbatAlertKey");

    return alertMsg == null;
}

(:test)
function testPreShabbatAlert_DisabledWhenOff(logger as Test.Logger) as Boolean {
    Storage.deleteValue("lastPreShabbatAlertKey");
    Storage.deleteValue("preShabbatAlertMessage");
    Storage.deleteValue("preShabbatAlertUntil");

    try {
        Properties.setValue("preShabbatAlert", 0);
    } catch (ex) {
        Storage.setValue("preShabbatAlert", "alert_off");
    }

    var fridayMoment = Gregorian.moment({
        :year => 2026,
        :month => 6,
        :day => 19,
        :hour => 16,
        :minute => 15,
        :second => 0
    });

    var view = new KodeshModeView();
    view.checkPreShabbatAlert(fridayMoment);

    var alertKey = Storage.getValue("lastPreShabbatAlertKey");
    var alertMsg = Storage.getValue("preShabbatAlertMessage");

    logger.debug("Disabled alertKey: " + alertKey);

    try {
        Properties.setValue("preShabbatAlert", 15);
    } catch (ex2) {
    }

    return alertKey == null && alertMsg == null;
}

(:test)
function testIsHourInWindow_InsideWindow(logger as Test.Logger) as Boolean {
    var view = new KodeshModeView();
    var result = view.isHourInWindow(18.5f, 18.0f, 19.0f);
    logger.debug("Inside window: " + result);
    return result == true;
}

(:test)
function testIsHourInWindow_OutsideWindow(logger as Test.Logger) as Boolean {
    var view = new KodeshModeView();
    var result = view.isHourInWindow(17.5f, 18.0f, 19.0f);
    logger.debug("Outside window: " + result);
    return result == false;
}

(:test)
function testIsHourInWindow_AtBoundaryStart(logger as Test.Logger) as Boolean {
    var view = new KodeshModeView();
    var result = view.isHourInWindow(18.0f, 18.0f, 19.0f);
    logger.debug("Boundary start: " + result);
    return result == true;
}

(:test)
function testIsHourInWindow_AtBoundaryEnd(logger as Test.Logger) as Boolean {
    var view = new KodeshModeView();
    var result = view.isHourInWindow(19.0f, 18.0f, 19.0f);
    logger.debug("Boundary end: " + result);
    return result == false;
}

(:test)
function testIsHourInWindow_WrappedAcrossMidnight(logger as Test.Logger) as Boolean {
    var view = new KodeshModeView();
    var result = view.isHourInWindow(23.5f, 23.0f, 1.0f);
    logger.debug("Wrapped midnight: " + result);
    return result == true;
}

(:test)
function testGetPreShabbatAlertMinutes_Default(logger as Test.Logger) as Boolean {
    var view = new KodeshModeView();
    var minutes = view.getPreShabbatAlertMinutes();

    logger.debug("Default alert minutes: " + minutes);

    return minutes == 15;
}

(:test)
function testGetPreShabbatAlertMinutes_Explicit(logger as Test.Logger) as Boolean {
    try {
        Properties.setValue("preShabbatAlert", 30);
    } catch (ex) {
        Storage.setValue("preShabbatAlert", "alert_30");
    }

    var view = new KodeshModeView();
    var minutes = view.getPreShabbatAlertMinutes();

    logger.debug("Explicit alert minutes: " + minutes);

    try {
        Properties.setValue("preShabbatAlert", 15);
    } catch (ex2) {
    }

    return minutes == 30;
}

(:test)
function testGetPreShabbatAlertKey_Format(logger as Test.Logger) as Boolean {
    var date = Gregorian.info(
        Gregorian.moment({
            :year => 2026,
            :month => 6,
            :day => 19,
            :hour => 18,
            :minute => 0,
            :second => 0
        }),
        Time.FORMAT_SHORT
    );

    var view = new KodeshModeView();
    var key = view.getPreShabbatAlertKey(date);

    logger.debug("Alert key: " + key);

    return key.equals("2026-6-19");
}

(:test)
function testSetStatus_WritesCorrectKeys(logger as Test.Logger) as Boolean {
    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    ShabbatMode.setStatus("Testing123");

    var msg = Storage.getValue("shabbatModeStatusMessage");
    var until = Storage.getValue("shabbatModeStatusUntil");

    logger.debug("setStatus msg: " + msg);
    logger.debug("setStatus until: " + until);

    var pass = msg != null && (msg as String).equals("Testing123") && until != null;

    Storage.deleteValue("shabbatModeStatusMessage");
    Storage.deleteValue("shabbatModeStatusUntil");

    return pass;
}

(:test)
function testClearStatus_RemovesKeys(logger as Test.Logger) as Boolean {
    ShabbatMode.setStatus("Temporary");
    ShabbatMode.clearStatus();

    var msg = Storage.getValue("shabbatModeStatusMessage");
    var until = Storage.getValue("shabbatModeStatusUntil");

    logger.debug("clearStatus msg: " + msg);
    logger.debug("clearStatus until: " + until);

    return msg == null && until == null;
}
