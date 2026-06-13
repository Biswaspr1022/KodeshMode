import Toybox.Lang;
import Toybox.WatchUi;

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :display_settings) {
            WatchUi.pushView(new Rez.Menus.DisplaySettingsMenu(), new DisplaySettingsDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :shabbat_times) {
            var menu = new Rez.Menus.ShabbatTimesMenu();
            var spIdx = menu.findItemById(:special_mode);

            if (spIdx != -1) {
                var spItem = menu.getItem(spIdx) as WatchUi.ToggleMenuItem;
                spItem.setEnabled(ShabbatMode.isSpecialModeEnabled());
            }

            var touchIdx = menu.findItemById(:touch_disabled_confirmed);

            if (touchIdx != -1) {
                var touchItem = menu.getItem(touchIdx) as WatchUi.ToggleMenuItem;
                touchItem.setEnabled(ShabbatMode.isTouchDisabledConfirmed());
            }

            WatchUi.pushView(menu, new ShabbatTimesDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

class DisplaySettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :clock_settings) {
            WatchUi.pushView(new Rez.Menus.ClockSettingsMenu(), new ClockSettingsDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :additional_content) {
            var menu = new Rez.Menus.AdditionalContentMenu();
            var pIdx = menu.findItemById(:show_parasha);

            if (pIdx != -1) {
                var pItem = menu.getItem(pIdx) as WatchUi.ToggleMenuItem;
                pItem.setEnabled(KodeshSettings.getValue("showParasha") == true);
            }

            var sIdx = menu.findItemById(:shabbat_progress);

            if (sIdx != -1) {
                var sItem = menu.getItem(sIdx) as WatchUi.ToggleMenuItem;
                sItem.setEnabled(KodeshSettings.getValue("shabbatProgress") == true);
            }

            var hIdx = menu.findItemById(:show_hebrew_date);

            if (hIdx != -1) {
                var hItem = menu.getItem(hIdx) as WatchUi.ToggleMenuItem;
                hItem.setEnabled(KodeshSettings.getValue("showHebrewDate") != false);
            }

            var tIdx = menu.findItemById(:show_shabbat_times);

            if (tIdx != -1) {
                var tItem = menu.getItem(tIdx) as WatchUi.ToggleMenuItem;
                tItem.setEnabled(KodeshSettings.getValue("showShabbatTimes") == true);
            }

            var oIdx = menu.findItemById(:show_omer);

            if (oIdx != -1) {
                var oItem = menu.getItem(oIdx) as WatchUi.ToggleMenuItem;
                oItem.setEnabled(KodeshSettings.getValue("showOmer") != false);
            }

            var bIdx = menu.findItemById(:show_battery);

            if (bIdx != -1) {
                var bItem = menu.getItem(bIdx) as WatchUi.ToggleMenuItem;
                bItem.setEnabled(KodeshSettings.getValue("showBattery") == true);
            }

            var prIdx = menu.findItemById(:screen_protector);

            if (prIdx != -1) {
                var prItem = menu.getItem(prIdx) as WatchUi.ToggleMenuItem;
                prItem.setEnabled(KodeshSettings.getValue("screenProtector") != false);
            }

            WatchUi.pushView(menu, new AdditionalContentDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :language_settings) {
            WatchUi.pushView(new Rez.Menus.LanguageMenu(), new SelectionDelegate("language"), WatchUi.SLIDE_LEFT);
        }
    }
}

class ClockSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :clock_style) {
            WatchUi.pushView(new Rez.Menus.ClockStyleMenu(), new SelectionDelegate("clockStyle"), WatchUi.SLIDE_LEFT);
        } else if (id == :clock_font) {
            WatchUi.pushView(new Rez.Menus.ClockFontMenu(), new SelectionDelegate("clockFont"), WatchUi.SLIDE_LEFT);
        } else if (id == :clock_size || id == :font_size || id == :clockSize) {
            WatchUi.pushView(new Rez.Menus.ClockSizeMenu(), new SelectionDelegate("clockSize"), WatchUi.SLIDE_LEFT);
        } else if (id == :font_color) {
            WatchUi.pushView(new Rez.Menus.FontColorMenu(), new SelectionDelegate("fontColor"), WatchUi.SLIDE_LEFT);
        } else if (id == :time_format) {
            WatchUi.pushView(new Rez.Menus.TimeFormatMenu(), new SelectionDelegate("timeFormat"), WatchUi.SLIDE_LEFT);
        }
    }
}

class SelectionDelegate extends WatchUi.Menu2InputDelegate {
    private var _key as String;

    function initialize(key as String) {
        Menu2InputDelegate.initialize();
        _key = key;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = getValueForId(item.getId());

        if (!value.equals("")) {
            KodeshSettings.setLocalValue(_key, value);

            if (_key.equals("clockFont") || _key.equals("clockSize") || _key.equals("hebrewDateSize") || _key.equals("parashaSize") || _key.equals("shabbatTimesSize")) {
                AppFonts.clearCustomFontCache();
            }
        }

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }

    function getValueForId(id) as String {
        if (id == :clock_digital) { return "clock_digital"; }
        if (id == :clock_analog) { return "clock_analog"; }

        if (id == :clock_system) { return "clock_system"; }
        if (id == :clock_varela) { return "clock_varela"; }
        if (id == :clock_stam) { return "clock_stam"; }
        if (id == :clock_simple) { return "clock_simple"; }

        if (id == :clock_varela_36) { return "clock_varela"; }
        if (id == :clock_varela_28) { return "clock_varela"; }
        if (id == :clock_stam_30) { return "clock_stam"; }
        if (id == :clock_simple_28) { return "clock_simple"; }

        if (id == :clock_size_18) { return "clock_size_18"; }
        if (id == :clock_size_22) { return "clock_size_22"; }
        if (id == :clock_size_24) { return "clock_size_24"; }
        if (id == :clock_size_28) { return "clock_size_28"; }
        if (id == :clock_size_30) { return "clock_size_30"; }
        if (id == :clock_size_36) { return "clock_size_36"; }
        if (id == :clock_size_44) { return "clock_size_44"; }
        if (id == :clock_size_52) { return "clock_size_52"; }
        if (id == :clock_size_60) { return "clock_size_60"; }
        if (id == :clock_size_68) { return "clock_size_68"; }
        if (id == :clock_size_76) { return "clock_size_76"; }
        if (id == :clock_size_84) { return "clock_size_84"; }

        if (id == :hebrew_date_size_18) { return "clock_size_18"; }
        if (id == :hebrew_date_size_22) { return "clock_size_22"; }
        if (id == :hebrew_date_size_24) { return "clock_size_24"; }
        if (id == :hebrew_date_size_28) { return "clock_size_28"; }
        if (id == :hebrew_date_size_30) { return "clock_size_30"; }
        if (id == :hebrew_date_size_36) { return "clock_size_36"; }
        if (id == :hebrew_date_size_44) { return "clock_size_44"; }
        if (id == :hebrew_date_size_52) { return "clock_size_52"; }
        if (id == :hebrew_date_size_60) { return "clock_size_60"; }
        if (id == :hebrew_date_size_68) { return "clock_size_68"; }
        if (id == :hebrew_date_size_76) { return "clock_size_76"; }
        if (id == :hebrew_date_size_84) { return "clock_size_84"; }

        if (id == :font_small) { return "clock_size_22"; }
        if (id == :font_medium) { return "clock_size_36"; }
        if (id == :font_large) { return "clock_size_52"; }
        if (id == :font_huge) { return "clock_size_60"; }

        if (id == :color_white) { return "color_white"; }
        if (id == :color_gray) { return "color_gray"; }
        if (id == :color_yellow) { return "color_yellow"; }
        if (id == :color_red) { return "color_red"; }
        if (id == :color_green) { return "color_green"; }
        if (id == :color_blue) { return "color_blue"; }
        if (id == :color_orange) { return "color_orange"; }
        if (id == :format_hm) { return "format_hm"; }
        if (id == :format_hms) { return "format_hms"; }
        if (id == :lang_en) { return "lang_en"; }
        if (id == :lang_he) { return "lang_he"; }
        if (id == :loc_jerusalem) { return "loc_jerusalem"; }
        if (id == :loc_telaviv) { return "loc_telaviv"; }
        if (id == :loc_haifa) { return "loc_haifa"; }
        if (id == :loc_eilat) { return "loc_eilat"; }
        if (id == :loc_gps) { return "loc_gps"; }
        if (id == :end_geonim) { return "end_geonim"; }
        if (id == :end_rt) { return "end_rt"; }
        if (id == :offset_20) { return "offset_20"; }
        if (id == :offset_30) { return "offset_30"; }
        if (id == :offset_40) { return "offset_40"; }
        if (id == :alert_off) { return "alert_off"; }
        if (id == :alert_5) { return "alert_5"; }
        if (id == :alert_10) { return "alert_10"; }
        if (id == :alert_15) { return "alert_15"; }
        if (id == :alert_60) { return "alert_60"; }
        if (id == :alert_40) { return "alert_40"; }
        if (id == :alert_30) { return "alert_30"; }
        if (id == :israel) { return "israel"; }
        if (id == :diaspora) { return "diaspora"; }
        return "";
    }
}

class AdditionalContentDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (item instanceof WatchUi.ToggleMenuItem) {
            var isEnabled = item.isEnabled();

            if (id == :show_parasha) {
                KodeshSettings.setLocalValue("showParasha", isEnabled);
            } else if (id == :shabbat_progress) {
                KodeshSettings.setLocalValue("shabbatProgress", isEnabled);
            } else if (id == :show_hebrew_date) {
                KodeshSettings.setLocalValue("showHebrewDate", isEnabled);
            } else if (id == :show_shabbat_times) {
                KodeshSettings.setLocalValue("showShabbatTimes", isEnabled);
            } else if (id == :show_omer) {
                KodeshSettings.setLocalValue("showOmer", isEnabled);
            } else if (id == :show_battery) {
                KodeshSettings.setLocalValue("showBattery", isEnabled);
            } else if (id == :screen_protector) {
                KodeshSettings.setLocalValue("screenProtector", isEnabled);
            }

            WatchUi.requestUpdate();
            return;
        }

        if (id == :hebrew_date_size) {
            WatchUi.pushView(new Rez.Menus.HebrewDateSizeMenu(), new SelectionDelegate("hebrewDateSize"), WatchUi.SLIDE_LEFT);
        } else if (id == :parasha_size) {
            WatchUi.pushView(new Rez.Menus.ParashaSizeMenu(), new SelectionDelegate("parashaSize"), WatchUi.SLIDE_LEFT);
        } else if (id == :shabbat_times_size) {
            WatchUi.pushView(new Rez.Menus.ShabbatTimesSizeMenu(), new SelectionDelegate("shabbatTimesSize"), WatchUi.SLIDE_LEFT);
        }
    }
}

class ShabbatTimesDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (item instanceof WatchUi.ToggleMenuItem && id == :special_mode) {
            var toggleItem = item as WatchUi.ToggleMenuItem;
            ShabbatMode.setSpecialModeEnabled(toggleItem.isEnabled());
            WatchUi.requestUpdate();
            return;
        }

        if (item instanceof WatchUi.ToggleMenuItem && id == :touch_disabled_confirmed) {
            var touchToggle = item as WatchUi.ToggleMenuItem;
            ShabbatMode.setTouchDisabledConfirmed(touchToggle.isEnabled());
            WatchUi.requestUpdate();
            return;
        }

        if (id == :location_settings) {
            WatchUi.pushView(new Rez.Menus.LocationMenu(), new SelectionDelegate("location"), WatchUi.SLIDE_LEFT);
        } else if (id == :shabbat_end_method) {
            WatchUi.pushView(new Rez.Menus.EndMethodMenu(), new SelectionDelegate("endMethod"), WatchUi.SLIDE_LEFT);
        } else if (id == :candle_offset) {
            WatchUi.pushView(new Rez.Menus.CandleOffsetMenu(), new SelectionDelegate("candleOffset"), WatchUi.SLIDE_LEFT);
        } else if (id == :pre_shabbat_alert) {
            WatchUi.pushView(new Rez.Menus.PreShabbatAlertMenu(), new SelectionDelegate("preShabbatAlert"), WatchUi.SLIDE_LEFT);
        } else if (id == :parasha_schedule) {
            WatchUi.pushView(new Rez.Menus.ParashaScheduleMenu(), new SelectionDelegate("parashaSchedule"), WatchUi.SLIDE_LEFT);
        }
    }
}
