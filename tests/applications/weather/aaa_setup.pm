use base "installedtest";
use strict;
use testapi;
use utils;

# This script will start the Gnome Weather application and save
# the image for all subsequent tests.

sub run {
    my $self = shift;

    # Install Weather with flatpak
    # NOTE: This will trigger an authentication (perhaps 2x) in desktop_vt()
    $self->root_console(tty => 3);
    assert_script_run("flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo");
    assert_script_run "flatpak install -y flathub org.gnome.Weather", 300;

    # In Rocky 9 there may be an issue starting Gnome flatpak applications.
    # This is a workaround to update the Gnome environment (see below) that requires logout/login
    # to be effective.
    # https://discussion.fedoraproject.org/t/gnome-flatpaks-apps-are-crashing-or-not-opening/133653/26
    if (get_var("DISTRI") eq "rocky" && (get_version_major() < 10))
    {
        my $password = get_var("USER_PASSWORD", "weakpassword");
        assert_script_run('echo "GSK_RENDERER=ngl" >> /etc/environment');

        # Cause systemd-logind to terminate idle sessions
        assert_script_run('echo "StopIdleSessionSec=30" >> /etc/systemd/logind.conf');

        # Return back
        desktop_vt();

        # Logout to use updated environment
        assert_and_click "system_menu_button";
        assert_and_click "leave_button";
        assert_and_click "log_out_entry";
        assert_and_click "log_out_confirm";

        # Wait to ensure time for systemd-logind to tear down user env (see above)
        sleep 45;

        # Move the mouse somewhere it won't highlight the match areas
        wait_still_screen 5;
        mouse_set(300, 800);
        mouse_hide;

        # Login to use updated environment
        if (get_version_major() > 8) {
            send_key_until_needlematch("graphical_login_test_user_highlighted", "tab", 5);
            assert_screen "graphical_login_test_user_highlighted";
        }
        send_key_until_needlematch("graphical_login_input", "ret", 3, 5);
        assert_screen "graphical_login_input";
        # seems like we often double-type on aarch64 if we start right
        # away
        wait_still_screen 5;
        type_very_safely $password;
        send_key "ret";
        wait_still_screen 3;

        # Switch to the console
        $self->root_console(tty => 3);
    }

    # Return back
    desktop_vt();

    # Set the update notification timestamp
    set_update_notification_timestamp();

    if (get_var("DISTRI") eq "rocky" && (get_version_major() < 10))
    {
        # Start the Application
        # We need to do extra checking, therefore we want to start simple
        # and not use the menu_launch_type, so we do the checks manually.
        menu_launch_type("weather");

        assert_screen ["apps_run_weather", "grant_access"];
        # sometimes we match apps_run_weather for a split second before
        # grant_access appears, so handle that
        wait_still_screen 3;
        assert_screen ['apps_run_weather', 'grant_access'];

        # give access rights if asked
        if (match_has_tag 'grant_access') {
            click_lastmatch;
            assert_screen 'apps_run_weather';
        }
    }

    # Workaround issue in Rocky 10 where Weather cannot be started
    # with the launcher but can be started with the flatpak cli command
    if (get_var("DISTRI") eq "rocky" && (get_version_major() > 9))
    {
        # Run a command using the command dialogue
        send_key('alt-f2');
        wait_still_screen(2);
        type_very_safely("flatpak run org.gnome.Weather\n");
    }

    # Make it fill the entire window.
    send_key("super-up");
    wait_still_screen(2);

    # Search for the city, different from the default one
    # as the default one can differ between zones.
    if (check_screen("weather_search_city")) {
        click_lastmatch;
    }
    type_very_safely("Edinburgh");
    assert_and_click("weather_select_city");

    # check we wind up on the hourly view, then let things settle
    # before snapshotting
    assert_screen("weather_report_hourly");
    wait_still_screen 3;
}

sub test_flags {
    # If this test fails, there is no need to continue.
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
