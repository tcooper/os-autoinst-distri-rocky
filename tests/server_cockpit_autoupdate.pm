use base "installedtest";
use strict;
use testapi;
use utils;
use packagetest;
use cockpit;

sub run {
    my $self=shift;
    bypass_1691487;

    # Start Cockpit
    start_cockpit(1);

    # Navigate to the Update screen
    select_cockpit_update();

    # FIXME Workaround for RHBZ #1765685 - remove when it's fixed
    sleep 15;

    # Switch on automatic updates
    assert_and_click 'cockpit_updates_auto', '', 120;
    assert_and_click 'cockpit_updates_dnf_install', '', 120;
    assert_screen 'cockpit_updates_auto_on';

    # Check the default automatic settings Everyday at 6 o'clock.
    assert_screen 'autoupdate_planned_day';
    assert_screen 'autoupdate_planned_time';

    # Quit Cockpit
    send_key "ctrl-q";
    sleep 3;

    # Check that the dnf-automatic service has started
    assert_script_run "systemctl is-active dnf-automatic-install.timer";

    # Check that it is scheduled correctly
    validate_script_output "systemctl show dnf-automatic-install.timer | grep TimersCalendar", sub {$_ =~ "06:00:00" };
}

sub test_flags {
    return { always_rolllback => 1 };
}

1;

# vim: set sw=4 et:
