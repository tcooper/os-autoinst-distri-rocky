use base "anacondatest";
use strict;
use testapi;
use anaconda;
use utils;

sub run {
    my $self = shift;
    my $webui = get_var("_ANACONDA_WEBUI");
    my $desktop = get_var("DESKTOP");

    # Begin installation
    # Sometimes, the 'slide in from the top' animation messes with
    # this - by the time we click the button isn't where it was any
    # more. So we'll retry a few times until the button goes away
    assert_screen ["anaconda_main_hub_begin_installation", "anaconda_webui_begin_installation"], 90;
    wait_still_screen 3;
    my $tries = 5;
    while ($tries) {
        $tries--;
        click_lastmatch;
        wait_still_screen 2;
        last unless (check_screen ["anaconda_main_hub_begin_installation", "anaconda_webui_begin_installation"]);
    }

    # If we want to test identification we will do it
    # on several places in this procedure, such as
    # on this screen and also on password creation screens
    # etc.
    my $identification = get_var('IDENTIFICATION');
    my $branched = get_var('VERSION');
    if ($identification eq 'true' or ($branched ne "Rawhide" && lc($branched) ne "eln")) {
        check_left_bar() unless ($webui);
        check_prerelease();
        check_version();
    }

    # Wait for install to end. Give Rawhide a bit longer, in case
    # we're on a debug kernel, debug kernel installs are really slow.
    my $timeout = 1800;
    my $version = lc(get_var('VERSION'));
    if ($version eq "rawhide" || lc(get_var('DISTRI')) eq "rocky") {
        $timeout = 4800;
    }

    # workstation especially has an unfortunate habit of kicking in
    # the screensaver during install...
    my $interval = 60;
    while ($timeout > 0) {
        die "Error encountered!" if (check_screen "anaconda_error_report");
        # move the mouse a bit
        mouse_set 100, 100;
        # also click, if we're a RDP client, seems just moving mouse
        # isn't enough to defeat blanking
        mouse_click if (get_var("RDP_CLIENT"));
        mouse_hide;
        last if (check_screen "anaconda_install_done", $interval);
        $timeout -= $interval;
    }
    assert_screen "anaconda_install_done";

    # wait for transition to complete so we don't click in the sidebar
    wait_still_screen 3;

    # if this is a live install, let's go ahead and quit the installer
    # in all cases, just to make sure quitting doesn't crash etc.
    if (get_var('LIVE')) {
        # not on Workstation with webUI, as it immediately reboots
        assert_and_click "anaconda_install_done" unless ($webui && $desktop eq "gnome");
    }

    # there are various things we might have to do at a console here
    # before we actually reboot. let's figure them all out first...
    my @actions;
    push(@actions, 'consoletty0') if (get_var("ARCH") eq "aarch64");
    push(@actions, 'abrt') if (get_var("ABRT", '') eq "system");
    push(@actions, 'rootpw') if (get_var("INSTALLER_NO_ROOT"));
    push(@actions, 'usbhalt') if (get_var("USBBOOT"));
    push(@actions, 'stagingrepos') if (get_var("DNF_CONTENTDIR"));
    push(@actions, 'releasever') if (get_var("DNF_RELEASEVER"));

    # memcheck test doesn't need to reboot at all. Rebooting from GUI
    # for lives is unreliable. And if we're already doing something
    # else at a console, we may as well reboot from there too
    push(@actions, 'reboot') if (!get_var("MEMCHECK") && (get_var("LIVE") || @actions));

    # our approach for taking all these actions doesn't work on RDP
    # installs, fortunately we don't need any of them in that case
    # yet, so for now let's just flush the list here if we're RDP
    @actions = () if (get_var("RDP_CLIENT"));

    # If we have no actions, let's just go ahead and reboot now,
    # unless this is memcheck
    unless (@actions) {
        unless (get_var("MEMCHECK")) {
            assert_and_click "anaconda_install_done";
        }
        return undef;
    }

    # OK, if we're here, we got actions, so head to a console. Switch
    # to console after liveinst sometimes takes a while, so 30 secs
    $self->root_console(timeout => 30);
    if (get_var("LIVE") && (get_var("LAYOUT") eq "french" || get_var("LANGUAGE") eq "japanese")) {
        console_loadkeys_us;
    }

    # this is something a couple of actions may need to know
    my $mount = "/mnt/sysimage";
    if (get_var("CANNED")) {
        # finding the actual host system root is fun for ostree...
        $mount = "/mnt/sysimage/ostree/deploy/fedora*/deploy/*.?";
    }
    if (grep { $_ eq 'consoletty0' } @actions) {
        # somehow, by this point, localized keyboard layout has been
        # loaded for this tty, so for French and Arabic at least we
        # need to load the 'us' layout again for the next command to
        # be typed correctly
        console_loadkeys_us;
        # https://bugzilla.redhat.com/show_bug.cgi?id=1661288 results
        # in boot messages going to serial console on aarch64, we need
        # them on tty0. We also need 'quiet' so we don't get kernel
        # messages, which screw up some needles
        assert_script_run 'sed -i -e "s,\(GRUB_CMDLINE_LINUX.*\)\",\1 console=tty0 quiet\",g" ' . $mount . '/etc/default/grub';
        # regenerate the bootloader config
        assert_script_run "chroot $mount grub2-mkconfig -o /boot/grub2/grub.cfg";
    }
    if (grep { $_ eq 'abrt' } @actions) {
        # Chroot in the newly installed system and switch on ABRT systemwide
        assert_script_run "chroot $mount abrt-auto-reporting 1";
    }
    if (grep { $_ eq 'rootpw' } @actions) {
        my $root_password = get_var("ROOT_PASSWORD") || "weakpassword";
        # this seems to have started to fail periodically with "failure while
        # writing changes to /etc/shadow" on 2023-09-01, attempt to work
        # around that
        my $count = 5;
        while ($count) {
            last unless (script_run "echo 'root:$root_password' | chpasswd -R $mount");
            die "setting root password failed five time!" unless ($count);
            $count -= 1;
        }
        # fix SELinux context on /etc/shadow to avoid denials later
        script_run "chroot $mount restorecon -v /etc/shadow";
    }
    if (grep { $_ eq 'noplymouth' } @actions) {
        assert_script_run "chroot $mount dnf -y remove plymouth";
    }

    if (grep { $_ eq 'stagingrepos' } @actions) {
        if (get_version_major() < 9) {
            assert_script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s,^#\(baseurl=http[s]*://\),\1,g" ' . $mount . '/etc/yum.repos.d/Rocky-BaseOS.repo';
            assert_script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s,^#\(baseurl=http[s]*://\),\1,g" ' . $mount . '/etc/yum.repos.d/Rocky-AppStream.repo';
            assert_script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s,^#\(baseurl=http[s]*://\),\1,g" ' . $mount . '/etc/yum.repos.d/Rocky-Extras.repo';
            assert_script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s,^#\(baseurl=http[s]*://\),\1,g" ' . $mount . '/etc/yum.repos.d/Rocky-Devel.repo';
        } else {
            script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s/^#baseurl/baseurl/g" ' . $mount . '/etc/yum.repos.d/rocky.repo';
            script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s/^#baseurl/baseurl/g" ' . $mount . '/etc/yum.repos.d/rocky-addons.repo';
            script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s/^#baseurl/baseurl/g" ' . $mount . '/etc/yum.repos.d/rocky-devel.repo';
            script_run 'sed -i -e "s/^mirrorlist/#mirrorlist/g;s/^#baseurl/baseurl/g" ' . $mount . '/etc/yum.repos.d/rocky-extras.repo';
        }
        assert_script_run 'printf "stg/rocky\n" > ' . $mount . '/etc/dnf/vars/contentdir';
    }
    if (grep { $_ eq 'releasever' } @actions) {
        assert_script_run 'printf "%s\n" "' . get_var("DNF_RELEASEVER") . '" > ' . $mount . '/etc/dnf/vars/releasever';
    }

    if (grep { $_ eq 'usbhalt' } @actions) {
        # halt the system cleanly to ensure install is complete
        type_string "systemctl halt\n";
        wait_still_screen 5;
        # disconnect the USB stick
        disconnect_usb;
        # reboot via ACPI
        power "reset";
        return;
    }
    type_string "reboot\n" if (grep { $_ eq 'reboot' } @actions);
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
