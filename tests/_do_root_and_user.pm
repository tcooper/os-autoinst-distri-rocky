use base "anacondatest";
use strict;
use testapi;
use anaconda;
use utils;

sub _set_root_password {
    # can also hit a transition animation
    wait_still_screen 2;
    my $root_password = get_var("ROOT_PASSWORD", "weakpassword");
    assert_and_click "anaconda_install_root_password";
    # we have to click 'enable root account' before typing the
    #password
    assert_and_click "anaconda_install_root_password_screen";
    # wait out animation
    wait_still_screen 2;
    desktop_switch_layout("ascii", "anaconda") if (get_var("SWITCHED_LAYOUT"));
    # these screens seems insanely subject to typing errors, so
    # type super safely. This doesn't really slow the test down
    # as we still get done before the install process is complete.
    type_very_safely $root_password;
    wait_screen_change { send_key "tab"; };
    type_very_safely $root_password;
    # Another screen to test identification on
    my $identification = get_var('IDENTIFICATION');
    if ($identification eq 'true') {
        check_top_bar();
        # we don't check version or pre-release because here those
        # texts appear on the banner which makes the needling
        # complex and fragile (banner is different between variants,
        # and has a gradient so for RTL languages the background color
        # differs; pre-release text is also translated)
    }
    assert_and_click "anaconda_spoke_done";
    # exiting this screen can take a while, so check for the hub
    assert_screen "anaconda_main_hub", 60;
}

sub _set_root_password_webui {
    my $root_password = get_var("ROOT_PASSWORD", "weakpassword");
    # hit tab till we can see the button, it may be off screen
    send_key_until_needlematch("anaconda_webui_allow_root", "tab", 3, 3);
    # Click the radio button, then get focus and fill the fields.
    assert_and_click("anaconda_webui_allow_root");
    sleep(1);
    type_very_safely($root_password);
    for (1 .. 2) {
        send_key("tab");
        sleep(1);
    }
    type_very_safely($root_password);
}

sub run {
    my $self = shift;
    # check whether user and root password creation are suppressed,
    # as they may be. if the 'begin installation' button is present
    # and active, they must be suppressed. we use assert_screen not
    # check_screen just to make it faster
    assert_screen [
        'anaconda_install_user_creation',
        'anaconda_webui_no_local_account',
        'anaconda_webui_begin_installation',
        'anaconda_main_hub_begin_installation'
    ];
    if (match_has_tag('anaconda_webui_begin_installation') || match_has_tag('anaconda_main_hub_begin_installation')) {
        set_var('INSTALLER_NO_ROOT', '1');
        set_var('INSTALL_NO_USER', '1');
    }
    my $nouser = (get_var("USER_LOGIN", '') eq 'false' || get_var("INSTALL_NO_USER"));
    my $noroot = get_var("INSTALLER_NO_ROOT");
    return if ($nouser && $noroot);
    if (get_var("_ANACONDA_WEBUI")) {
        if ($nouser) {
            assert_and_click 'anaconda_webui_no_local_account';
        }
        else {
            webui_create_user();
        }
        _set_root_password_webui() unless ($noroot);
        assert_and_click("anaconda_webui_next");
    }
    else {
        _set_root_password() unless ($noroot);
        # Set user details, unless the test is configured not to create one
        unless ($nouser) {
            # Wait out animation
            wait_still_screen 8;
            anaconda_create_user();
        }
    }
    # Check username (and hence keyboard layout) if non-English
    if (get_var('LANGUAGE')) {
        assert_screen "anaconda_install_user_created";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
