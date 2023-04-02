use base "installedtest";
use strict;
use testapi;
use utils;

sub run {
    # create a mount point for the ISO
    assert_script_run "mkdir -p /mnt/iso";
    # mount the ISO there
    assert_script_run "mount /dev/cdrom /mnt/iso";

    # install check script dependencies
    assert_script_run "dnf -y install coreutils curl dnf isomd5sum python3 rpm util-linux";

    # download the check script
    assert_script_run "curl -o /usr/local/bin/potential_conflict.py https://raw.githubusercontent.com/tcooper/rocky-linux-testing/qa-testcase-boxes/qa-testcase-boxes/testcase-mediacheck/scripts/potential_conflict.py";

    # run the check
    assert_script_run "python3 /usr/local/bin/potential_conflict.py --repofrompath AppStream,/mnt/iso/AppStream --repoid AppStream --repofrompath BaseOS,/mnt/iso/BaseOS --repoid BaseOS";
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
