use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    my $user = get_var("USER_LOGIN", "test");

    # Switch to console
    $self->root_console(tty => 3);

    # Install clocks and ExtremeTuxRacer with flatpak
    # NOTE: This will trigger an authentication (perhaps 2x) in desktop_vt()
    assert_script_run("flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo");
    assert_script_run('flatpak install -y net.sourceforge.ExtremeTuxRacer', timeout => 300);
    assert_script_run "flatpak install -y flathub org.gnome.clocks", 300;
    assert_script_run("curl -O " . autoinst_url . "/data/video.ogv", timeout => 120);
    assert_script_run("mv video.ogv /home/$user/Videos/");
    script_run("chown $user:$user /home/$user/Videos/video.ogv");

    # In Rocky 9 and 10 there may be an issue starting Gnome flatpak applications.
    # This is a workaround to update the Gnome environment (see below) that requires logout/login
    # to be effective.
    # https://discussion.fedoraproject.org/t/gnome-flatpaks-apps-are-crashing-or-not-opening/133653/26
    if (get_var("DISTRI") eq "rocky")
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
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
