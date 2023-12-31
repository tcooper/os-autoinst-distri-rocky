use base "installedtest";
use strict;
use testapi;
use utils;
use packagetest;
use cockpit;

sub run {
    my $self = shift;

    my $cockdate = "0";
    # Remove a package, disable repositories and enable test repositories, install the package
    # from that repository to make the system outdated and verify that that package was
    # correctly installed.
    prepare_test_packages;
    verify_installed_packages;

    # Start Cockpit
    start_cockpit(login => 1);
    # Navigate to update screen
    select_cockpit_update();

    # In Rocky it may take quite a while to query for updates
    # and present the Install all updates button.
    # Provide a bit of extra time to match that screen

    # Install the rest of the updates, or any updates
    # that have not been previously installed.
    assert_and_click 'cockpit_updates_all_install';
    my $run = 0;
    # Upstream typically runs openQA against composes which have ISOs with all
    # packages from compose. The only update they apply in this test is usually
    # the acpica-tools package which they installed an empty package for earlier
    # in prepare_test_packages(). We typically are testing with a release ISO
    # and currently production repos. This means we can have a lot more packages
    # to install here and the installation may take quite some time before it's
    # complete and we'll be able to match cockpit_updates_updated needle.
    while ($run < 120) {
        # When Cockpit packages are also included in the updates
        # the user is forced to reconnect, i.e. to restart the Web Application
        # and relog for further interaction. We will check if reconnection is
        # needed and if so, we will restart Firefox and login again. We do
        # *not* need to gain admin privs again, trying to do so will fail.
        #
        last if (check_screen("cockpit_updates_updated"));
        if (check_screen("cockpit_updates_reconnect", 1)) {
            quit_firefox;
            sleep 5;
            start_cockpit(login => 1, admin => 0);
            select_cockpit_update();
            last;

        }
        # Ignore rebooting the system because we want to finish the test instead.
        elsif (check_screen('cockpit_updates_restart_ignore', 1)) {
            assert_and_click 'cockpit_updates_restart_ignore';
            last;
        }
        else {
            sleep 10;
            $run = $run + 1;
        }

        # move the mouse a bit
        mouse_set 100, 100;
        # also click, if we're a VNC client, seems just moving mouse
        # isn't enough to defeat blanking
        mouse_click if (get_var("VNC_CLIENT"));
        mouse_hide;
    }
    # Check that the system is updated
    assert_screen 'cockpit_updates_updated';

    # Switch off Cockpit
    quit_firefox;

    # Wait a couple of seconds for the terminal to settle down, the command was
    # entered incorrectly which resulted in a failure.
    sleep 5;

    # Verify that the test package was updated correctly.
    verify_updated_packages;
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# vim: set sw=4 et:
