#!/usr/bin/env perl

# Copyright 2025 Stefan Blachmann
# Published under the same GPL license as Debian
# GPL v2? v3? TODO

use strict;
use warnings;
use utf8;
use open ':encoding(utf8)';
binmode(STDOUT, ":utf8");
use feature 'unicode_strings';
use Getopt::Long;
use Data::Dumper;
use Cwd;
use POSIX ":sys_wait_h";









my $os_ubuntu = 1;









my $mntprefix = '/mnt';

# I don't really understand the zed launch/stop thing in ehe example
# these seem to change zfs properties to force cache update
# but do not reset to original afterward
# so this switch to be able to show/debug
my $zedhandlingconfusesme = 'defined';

# As I always seem to get "cannot resolve path '<vdev_path>'" errors,
# no matter whether using symlink (/by-id) or direct path (sdX) for the 2nd and
# subsequent vdev in zpool create, I do this via attach.
# to reproduce/debug this there is the flag.
# Set it to zero to use  zpool create with multiple mirrored vdevs
# my $use_zpool_attach = 1;
my $use_zpool_attach = 0;

# still necessary?
# Tried forcezpoolcreate because of some notice that the pool
# was not created because disk was not empty or sth like that
my $forcezpoolcreate = ' -f';

# sometimes no WWN link is in /dev/disk/by-id
# my $dontusewwn = 1;
# my $useuuid = 1;
# sometimes even no ata link is in /dev/disk/by-id, after partprobe
# so use sdX
# my $usesdX = 1;
my $diskbyid = 'disk/by-id/';
# my $diskbyid = '';



my $myname = 'debianonzfsinst.pl';
my $tmpfile = "/tmp/$myname.tmp";
my $file_secondstage_bootstrap = '/root/' . $myname . '_secondstagebootstrap';
my $boot2;
my $secondstage = 0;
my $thirdstage = 0;
my $file_firststage = '/root/' . $myname . '_firststage';
my $file_secondstage = '/root/' . $myname . '_secondstage';

my $cmd3;

my $file_etc_fstab = '/etc/fstab';

my $sysmod = '_sysmod_';
my $modini = '_modini_';

my $_write_etcchosts_ = '_write_etcchosts_';

my $appendtofstab; # contains text to append to fstab
my $_appendtofstab_ = '_appendtofstab_';

my $etcsysctldlocalconffntmp = '/root/etcsysctldlocalconf';
my $etcsysctldlocalconffn = '/etc/sysctl.d/local.conf';

my $file_import_bpool_service = '/etc/systemd/system/zfs-import-bpool.service';
# my $filecontents_import_bpool_service =
# '[Unit]
# DefaultDependencies=no
# Before=zfs-import-scan.service
# Before=zfs-import-cache.service
#
# [Service]
# Type=oneshot
# RemainAfterExit=yes
# ExecStart=/sbin/zpool import -N -o cachefile=none ' . $bootpool . '
# # Work-around to preserve zpool cache:
# ExecStartPre=-/bin/mv /etc/zfs/zpool.cache /etc/zfs/preboot_zpool.cache
# ExecStartPost=-/bin/mv /etc/zfs/preboot_zpool.cache /etc/zfs/zpool.cache
#
# [Install]
# WantedBy=zfs-import.target
#
# ';
my $_writefile_import_bpool_service_ = '_writefile_import_bpool_service_';

my $zedcachedir = '/etc/zfs/zfs-list.cache';
# my $zedcachebpool = "$zedcachedir/$bootpool";
# my $zedcacherpool = "$zedcachedir/$rootpool";
# my $zedcachebpool;
# my $zedcacherpool;

# my $_fillzedcache_ = '_fillzedcache_';

my $_unmountzfs_ = '_unmountzfs_';




# TODO
# https://askubuntu.com/questions/1470073/disable-on-board-vga-unknown-display
# blacklist onboard mga if necessary
my $blacklistfiletxt = 'blacklist mgag200
';
my $fn_blacklist = '/etc/modprobe.d/blacklist.conf';

	my $etchosts =
# '# /etc/hosts
# ::1		localhost localhost.my.domain
# 127.0.0.1		localhost localhost.my.domain
'

# router
10.0.0.1		gate

# Office net
10.0.10.1		officegate
10.0.10.10		lelo
10.0.10.14		zippy
10.0.10.15		think
10.0.10.19		tester
10.0.10.20		kyo

# Retro net
10.0.20.1		retrogate

# Test net
10.0.30.1		testgate

# Wifi net
10.0.50.1		wifigate

# Private net
10.0.70.1		privategate
10.0.70.10		tv

# WWW net
10.0.80.1		wwwgate
10.0.80.100		develop develop.dummy.dummy
10.0.80.200		a b.info
10.0.80.201		c d.info
';


##############################################################################
##############################################################################

##############################################################################
####################
####################	<modulename> START
####################
##############################################################################

##############################################################################
####################
####################	<modulename> END
####################
##############################################################################






sub logconsole
{
	my $s = shift;
	print $s;
}







##############################################################################
####################
####################	getinterfs START
####################
##############################################################################


# Configure the network interface:
# Constants
# 	my $ifvar_isactive = 'ifvar_isactive';
my $ifvar_vendor = 'ifvar_vendor';
my $ifvar_model = 'ifvar_model';
my $ifvar_nocarrier = 'ifvar_nocarrier';
my $ifvar_ip4 = 'ifvar_ip4';
# Global
my $intfs = ();
my $intfsh = \$intfs;

sub getinterfs
{
	my $ipaddrlist = `ip addr list`;

	my @ipl = split(/\n/, $ipaddrlist);
	my $thisif;

	foreach (@ipl) {
# print(" line: '$_'\n");
		my ($ifno, $ifname) = /^(\d+):\s+([a-z_0-9]+):/;

		if (defined $ifno and defined $ifname) {
			next if ($ifname eq 'lo');
			$thisif = $ifname;
			if (/NO-CARRIER/) {
# print("    NOCARRIER\n");
				$$$intfsh{$ifname}->{$ifvar_nocarrier} = '';
			}
			# get more details
			my $ifdetails = `udevadm info /sys/class/net/$thisif`;

			my ($ifvendor) = $ifdetails =~ /^E: ID_VENDOR_FROM_DATABASE=(.*)$/m;
			my ($ifmodel) = $ifdetails =~ /^E: ID_MODEL_FROM_DATABASE=(.*)$/m;
			if (defined $ifvendor and defined $ifmodel) {
# print("    IFMODEL if: '$thisif' '$ifvendor' '$ifmodel'\n");
				$$$intfsh{$ifname}->{$ifvar_vendor} = $ifvendor;
				$$$intfsh{$ifname}->{$ifvar_model} = $ifmodel;
			}
		} else {
			next if (not defined $thisif);

			# connected? eg inet/inet6 present?

			my ($ip4) = /^\s+inet ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2})/m;
			if (defined $ip4) {
# print("    INET if: '$thisif' '$ip4'\n");
				$$$intfsh{$thisif}->{$ifvar_ip4} = $ip4;
			}
		}
	}
}



# getinterfs();
#
# my $m = '';
# foreach (keys %$$intfsh) {
# 	my $ifname = $_;
# 	$m .= "$_: " .
# 			$$$intfsh{$ifname}->{$ifvar_vendor} . ' ' .
# 			$$$intfsh{$ifname}->{$ifvar_model};
# 	$m .= (exists $$$intfsh{$ifname}->{$ifvar_nocarrier})
# 			? ''
# 			: ' [Wire Connected]';
# 	$m .= (exists $$$intfsh{$ifname}->{$ifvar_ip4})
# 			? (' [Online: ' . $$$intfsh{$ifname}->{$ifvar_ip4} . ']')
# 			: '';
# 	$m .= " \n";
# }
#
# print "$m\n";



##############################################################################
####################
####################	getinterfs END
####################
##############################################################################




##############################################################################
####################
####################	file functions START
####################
##############################################################################

sub getdirfiles {
    my $dname = shift;

    opendir DIR, $dname or die; # "cannot open dir $dname: $!";
    my @dir = readdir DIR;
    closedir DIR;
    return @dir;
}

# string read_a_file( string filename)
# returns a reference to the text
sub read_a_file
{
    my $fn = shift;
    local $/ = undef;
    open FILE, $fn or return undef;
    my $text = <FILE>;
    close FILE or return undef;
    return \$text;
}

# int xwrite_a_file( string filename, stringref text, mode {write|append})
sub xwrite_a_file
{
    my $fn = shift;
    my $tx = shift;
    my $m = shift;
    my $mode;
    if ($m eq 'write') {
        $mode = '>';
    } elsif ($m eq 'append') {
        $mode = '>>';
    } else {
        die "'$m'";
    }
    open my $file, $mode, $fn or return -1;
    print $file $$tx or return -2;
    close $file or return -3;
    return 0;
}

# int append_a_file( string filename, stringref text)
# sub append_a_file
# {
#     my $fn = shift;
#     my $tx = shift;
#
#     # read the file to verify that it ends with a newline
#     my $filetx = read_a_file( $fn);
#     if (defined $filetx) {
#         if (not ($$filetx =~ /\n$/s)) {
#             $$filetx .= "\n";    # insert newline
#         }
#     } else {
#         my $tmps = '';
#         $filetx = \$tmps;
#     }
#     $$filetx .= $$tx;
#     logconsole( "append_a_file( $fn)\n");
#     return xwrite_a_file( $fn, $filetx, 'write');
# }

sub append_a_file
{
    my $fn = shift;
    my $tx = shift;

    # read the file to verify that it ends with a newline
    my $filetx = read_a_file( $fn);
    if (defined $filetx) {
        if (not ($$filetx =~ /\n$/s)) {
            $$tx = "\n" . $$tx;    # insert newline
        }
   }
    logconsole( "append_a_file( $fn)\n");
    return xwrite_a_file( $fn, $tx, 'append');
}

# int write_a_file( string filename, stringref text)
sub write_a_file
{
    my $fn = shift;
    my $tx = shift;
    logconsole( "write_a_file( $fn)\n");
    return xwrite_a_file( $fn, $tx, 'write');
}



##############################################################################
####################
####################	file functions END
####################
##############################################################################



##############################################################################
####################
####################	utility functions START
####################
##############################################################################


############################################################
####################    utility functions
############################################################

sub isnumin {
  my $aref = shift;
  my $num = shift;
  my $isin = 0;
  foreach (@$aref) {
    next if ($_ == $num);
    $isin = 1;
  }
  return $isin;
}


##############################################################################
####################
####################	utility functions END
####################
##############################################################################



##############################################################################
####################
####################	getdrives START
####################
##############################################################################

############################################################
####################    disk lookup subroutine(s)
############################################################

my $availdrivesh = ();
my $availdrives = \$availdrivesh;

sub isanywhere
{
	my $prognam = shift;

	my $whereis = `whereis $prognam`;

	if ($whereis =~ /^$prognam:\s+$/) {
		return 0;
	}
	return 1;
}


sub getdrivesinfo
{
	my $drive_model = 'drive_model';
	my $drive_size = 'drive_size';
	my $drive_sizeunit = 'drive_sizeunit';
	my $drive_partschema = 'drive_partschema';
	my $drive_partitions = 'drive_partitions';
	my $drive_partitions_size = 'drive_partitions_size';
	my $drive_partitions_type = 'drive_partitions_type';

	my $drivesh = ();
	my $driveslist = \$drivesh;

	my $bootdev;
	my $bootpart;

	my $bootmount = `findmnt /`;
	($bootdev, $bootpart) = $bootmount =~ /\/\s+\/dev\/(\w+)(\d+)/s;
# print "Booted from device '$bootdev', part '$bootpart'\n";

	{
		my $fdiskl = `fdisk -l`;
		my $thisdisk;
		my @fdiskln = split( /\n/, $fdiskl);
		foreach (@fdiskln) {
			if ( /Disk \/dev\/(\w+): ([01-9.]+) (\w)iB/ ) {
				$thisdisk = $1;
				$$$driveslist{$thisdisk}->{$drive_size} = $2;
				$$$driveslist{$thisdisk}->{$drive_sizeunit} = $3;
				next;
			}
			if (/Disk model\: (.*)\s+/) {
				$$$driveslist{$thisdisk}->{$drive_model} = $1;
				next;
			}
			if (/Disklabel type\: (.*)/) {
				$$$driveslist{$thisdisk}->{$drive_partschema} = $1;
# print "Found $1 schema\n";

				next;
			}

			# chop trailing spaces
			if (exists $$$driveslist{$thisdisk}->{$drive_model}) {
				$$$driveslist{$thisdisk}->{$drive_model} =~ s/\s+$//;
			}


			if (defined $thisdisk) {
# print "---> CHECKING $thisdisk: '$_'\n";
				if ( /^\/dev\/$thisdisk\d+\s/ ) {
					# it is a partition entry line
					if ( /^\/dev\/$thisdisk\d+\s+/ ) {
						my $partno;
						my $partsize;
						my $parttyp;
						if ($$$driveslist{$thisdisk}->{$drive_partschema} eq 'dos') {
							($partno, $partsize, $parttyp) =
								/^\/dev\/$thisdisk(\d+)\s+(?:\*\s+)?\d+\s+\d+\s+\d+\s+([01-9.KMGT]+)\s+\d+\s+(.*)/;
# print "MBR schema\n";
						} elsif ($$$driveslist{$thisdisk}->{$drive_partschema} eq 'gpt') {
							($partno, $partsize, $parttyp) =
								/^\/dev\/$thisdisk(\d+)\s+\d+\s+\d+\s+\d+\s+([01-9.KMGT]+)\s+(.*)/;
# print "GPT schema\n";
						}

						if (not defined $partno or
							not defined $partsize or
							not defined $parttyp )
						{
# print "Not matched\n";
							next;
						}

# if (defined $partno) {
# 	print "---> partno: '$partno'\n";
# }
# if (defined $partsize) {
# 	print "---> partsize: '$partsize'\n";
# }
# if (defined $parttyp) {
# 	print "---> parttyp: '$parttyp'\n";
# }
						$$$driveslist{$thisdisk}->{$drive_partitions}->{$partno}->{$drive_partitions_size} = $partsize;
						$$$driveslist{$thisdisk}->{$drive_partitions}->{$partno}->{$drive_partitions_type} = $parttyp;
					}
				}
			}
		}
	}

	foreach (sort keys %$$driveslist) {
		my $drv = $_;

		# skip boot device
		if (defined $bootdev) {
			# no real bootdev on live, needs new/correct search RE
			next if ($_ eq $bootdev);
		}
		# skip loop device
		next if (/^loop*/);

		my $m = "/dev/$_ " . $$$driveslist{$_}->{$drive_size} .
					$$$driveslist{$_}->{$drive_sizeunit};
		if (exists $$$driveslist{$_}->{$drive_model}) {
			$m .= ' ' . $$$driveslist{$_}->{$drive_model};
		}

		my $pm;
		if (exists $$$driveslist{$_}->{$drive_partschema}) {
			if ($$$driveslist{$_}->{$drive_partschema} eq 'gpt') {
# 				$pm = ' [GPT:';
				$pm = 'GPT:';
			} else {
# 				$pm = ' [MBR:';
				$pm = 'MBR:';
			}
			if (exists $$$driveslist{$_}->{$drive_partitions}) {
				my $partshr = \\%{$$$driveslist{$_}->{$drive_partitions}};
# 				my $notfirstpart;
				foreach (sort keys %$$partshr) {
					# $_ == part no
# 					if (defined $notfirstpart) {
# 						$pm .= ',';
# 					}
					$pm .= " $_-" .
							$$$partshr{$_}->{$drive_partitions_type} . ' (' .
							$$$partshr{$_}->{$drive_partitions_size} . ')';
# 					$notfirstpart = 1;
					# in case of ZFS tell pool name, too
					# but only if ZFS utils are installed
					if (isanywhere('zdb')) {
						if ($$$partshr{$_}->{$drive_partitions_type} =~ /zfs|ZFS/) {
							my $zdb = `zdb -l $_$drv`;
							my $zpooln = $zdb =~ /^\s+name:\s+'([a-zA-Z0-9_]+)'/m;
							if (defined $zpooln) {
								$pm .= " pool '$zpooln'";
							}
						}
					}
				}
			} else {
				$pm .= " no partitions";
			}
# 			$pm .= ']';

		} else {
			# unpartitioned drive
			if (isanywhere('zdb')) {
				# check with zdb for dangerously dedicated drive, before declaring empty
				my $zdb = `zdb -l $_`;
				# name line present?
				my $zpooln = $zdb =~ /^\s+name:\s+'([a-zA-Z0-9_]+)'/m;
				if (defined $zpooln) {
					$pm = "Dangerously dedicated pool (without partition table): '$zpooln'";
				}
			} else {
				$pm = 'No partition table. Not checked for dedicated ZFS drive!';
			}
		}

		if (defined $pm) {
			$m .= " [$pm]";
		}
# print $m . "\n";
		$$$availdrives{$drv} = $m;
	}
}


# convert sda, b, c... to /disk/by-id idents
sub getdrivewwnid
{
	my $thedrv = shift;

	my $devdiskbyid = `ls -l /dev/disk/by-id`;
	my @idlines = split( /\n/, $devdiskbyid);
	my $id_ata;
	my $id_md_name;
	my $id_md_uuid;
	my $id_scsi;
	my $id_wwn;
	my $id_usb;
	foreach (@idlines) {
		#
		my ($devuuidlink, $dev) =
			/^
				[^ ]+\s+			# perms
				\d+\s				# count
				[^ ]+\s+			# u
				[^ ]+\s+			# g
				\d{1,2}\s			# dd
				[a-zA-Z]{3}\s		# mm
				\d{1,2}\s			# yy
				\d{1,2}:\d{2}\s		# time
				([^ ]+)\s
				->\s
				([^ ]+)
			$/x;

		next if (not defined $dev or not defined $devuuidlink);
		# remove '../../'
		$dev = substr( $dev,6);
		next if ($dev ne $thedrv);

		my $typ = substr( $devuuidlink,0,4);
		if ($typ eq 'wwn-') {
			$id_wwn = $devuuidlink;
		} elsif ($typ eq 'ata-') {
			$id_ata = $devuuidlink;
		} elsif ($typ eq 'md-u') {
			$id_md_uuid = $devuuidlink;
		} elsif ($typ eq 'md-n') {
			$id_md_name = $devuuidlink;
		} elsif ($typ eq 'scsi') {
			$id_scsi = $devuuidlink;
		} elsif ($typ eq 'usb-') {
			$id_usb = $devuuidlink;
		} else {
			die;
		}

# 		print "$dev: $typ: $devuuidlink\n";
	}


	my $r;
	if (defined $id_wwn) {
		$r = $id_wwn;
	} elsif (defined $id_scsi) {
		$r = $id_scsi;
	} elsif (defined $id_ata) {
		$r = $id_ata;
	} elsif (defined $id_md_uuid) {
		$r = $id_md_uuid;
	} elsif (defined $id_md_name) {
		$r = $id_md_name;
	} elsif (defined $id_usb) {
		$r = $id_usb;
	} else {
		die;
	}


# 	/^.+?\s+(ata[a-zA-Z_0-9:-]+)\s+\-\>\s+\.\.\/\.\.\/$drive$/m;
#
# # 	my ($thiswwnid) = $devdiskbyid =~ /^.+?\s+([a-zA-Z_0-9:-]+)\s+\-\>\s+\.\.\/\.\.\/$drive$/m;
#
# 	my $thiswwnid;
# 	# search for wwn first
# 	# then for usb, last for ata
# 	if (not $dontusewwn) {
# 		($thiswwnid) = $devdiskbyid =~ /^.+?\s+(wwn[a-zA-Z_0-9:-]+)\s+\-\>\s+\.\.\/\.\.\/$drive$/m;
# 	} elsif ($useuuid) {}
#
#
#
	return $r;

}

##############################################################################
####################
####################	getdrives END
####################
##############################################################################






##############################################################################
####################
####################	dialog_subroutines START
####################
##############################################################################



############################################################
####################    dialog subroutines
############################################################



sub getcheckform
{
    my $itemlist = shift;   # ref hash (id => description text)
    my $itemseq = shift;    # ref list (sequence items are to be listed)
    my $backtitle = shift;
    my $title = shift;
    my $checklisttext = shift;
    my $dimensions = shift; #  string "formheight formwidth listheight"
    my $selections = shift; # ref hash filled on return (selected ids exist as keys)
    my $itemenable = shift; # optional: undef or ref hash (id => on|off)
    my $defaultonoff = shift; # optional: undef or either string on|off


    my $sy = "dialog --backtitle '$backtitle' --title '$title' --clear --checklist '$checklisttext' $dimensions";

    foreach (@{$itemseq}) {
        # %itemlist items need not to be in @itemseq,
        # because @itemseq serves as general sequence definition
        if (exists ${$itemlist}{$_}) {
            if (defined $itemenable) {
                $sy .= " $_ '${$itemlist}{$_}' ${$itemenable}{$_}";
            } elsif (defined $defaultonoff) {
                $sy .= " $_ '${$itemlist}{$_}' $defaultonoff";
            } else {
                $sy .= " $_ '${$itemlist}{$_}' off";
            }
        }
    }
    $sy .= " 2>$tmpfile";

    my $r = callsystem( $sy);
    die "Exited by pressing \"ESC\"\n" if ($r == 255);
    die "Exited by selecting \"Cancel\"\n" if ($r == 1);
    die "Exited because of unknown dialog return code '$r'\n" if ($r);

    my $rref = read_a_file( $tmpfile);
    unlink( $tmpfile);
    {
        my @selitems = split( ' ', $$rref);
        foreach (@selitems) {
            ${$selections}{ $_} = 'i';
        }
    }
}

sub getradioform
{
    my $itemlist = shift;   # ref hash (id => description text)
    my $itemseq = shift;    # ref list (sequence items are to be listed)
    my $backtitle = shift;
    my $title = shift;
    my $radiolisttext = shift;
    my $dimensions = shift; #  string "formheight formwidth listheight"
    my $selection = shift;  # ref string filled on return (selected tag)
    my $itemdefault = shift; # optional: ref str with the item tag to be activated by default

    my $sy = "dialog --backtitle '$backtitle' --title '$title' --clear --radiolist '$radiolisttext' $dimensions";
    my $firstdone = 0;
    foreach (@{$itemseq}) {
print "getradioform: item '$_'\n";

        # %itemlist items need not to be in @itemseq,
        # because @itemseq serves as general sequence definition
        if (exists ${$itemlist}{$_}) {
            my $onoff;
            if (defined $itemdefault) {
                $onoff = ($_ eq $$itemdefault)
                            ? 'on'
                            : 'off';
            } else {
                if (not $firstdone) {
                    $onoff = 'on';
                    $firstdone = 1;
                } else {
                    $onoff = 'off';
                }
            }
            $sy .= " $_ '${$itemlist}{$_}' $onoff";
        }
    }
    $sy .= " 2>$tmpfile";

    my $r = callsystem( $sy);
    die "Exited by pressing \"ESC\"\n" if ($r == 255);
    die "Exited by selecting \"Cancel\"\n" if ($r == 1);
    die "Exited because of unknown dialog return code '$r'\n" if ($r);

    my $rref = read_a_file( $tmpfile);
    unlink( $tmpfile);
    $$selection = $$rref;
}

sub inputbox
{
    my $backtitle = shift;
    my $title = shift;
    my $text = shift;
    my $dimensions = shift;
    my $presetval = shift;

    my $sy = "dialog --backtitle '$backtitle' --title '$title' --clear --inputbox '$text' $dimensions '$presetval'";

    my $r = callsystem( "$sy 2>$tmpfile");
    my $rref = read_a_file( $tmpfile);
    unlink( $tmpfile);
    return $$rref;
}

sub yesno
{
    my $backtitle = shift;
    my $title = shift;
    my $text = shift;
    my $dimensions = shift; #  string "height width"

    my $sy = "dialog --backtitle '$backtitle' --title '$title' --clear --yesno '$text' $dimensions";
    my $r = callsystem( $sy);

# TODO find out what is wrong!
# logconsole( "yesno: dialog returned '$r'\n");
# sometimes dialog-yesno returns 2 (Help) instead of 0 (OK) ?!?
if ($r == 2) {
    $r = 0;
}

    return (($r) ? 0 : 1);
}

sub msgbox
{
    my $backtitle = shift;
    my $title = shift;
    my $text = shift;
    my $dimensions = shift; #  string "height width"

    my $sy = "dialog --backtitle '$backtitle' --title '$title' --clear --msgbox '$text' $dimensions";

    callsystem( $sy);
}


##############################################################################
####################
####################	dialog_subroutines END
####################
##############################################################################



############################################################
####################    utility part: fill zed

############################################################


sub removemnts
{
	my $fn = shift;
	my $tx = read_a_file($fn);
	die( "Failed to read $fn\n") if (not defined $tx);
	$$tx =~ s/\/mnt//mg;
	my $r = write_a_file($fn, $tx);
	die( "Failed to write $fn\n") if ($r);
}

# sub do_fillzedcache
# {
# 	my $max_retries = 5;
# 	my $fail = 1;
#
# # 	my $zedcommand = 'zed -F';
# 	my $zedcommand = 'zed';
#
# 	my $er = '';
# 	my $stdouttxr;
# 	my $stderrtxr;
# 	my $tmpfilebasepath = '/tmp/';
# 	my $workdir = undef;
# 	my $umaskval = undef;
# 	my $r;
#
# 	while ($fail and $max_retries--) {
#
# 		$r = system3( $zedcommand,
# 				\$er,
# 				\$stdouttxr,
# 				\$stderrtxr,
# 				$tmpfilebasepath,
# 				$workdir,
# 				$umaskval
# 		);
#
# die if $r;
#
# 		$fail = 0;
# 		sleep(1);
# 		if ( -z $zedcachebpool or
# 				-z $zedcacherpool) {
# 			# try force cache update
# 			if (defined $zedhandlingconfusesme) {
# 				# is this change intended?
# 				system( 'zfs set canmount=on bpool/BOOT/debian');
# 				system( 'zfs set canmount=noauto rpool/ROOT/debian');
# 			} else {
# 				# maybe something like that works better?
# 				system( 'zfs set canmount=noauto bpool/BOOT/debian');
# 				sleep( 1);
# 				system( 'zfs set canmount=off bpool/BOOT/debian');
# 				sleep( 1);
# 				system( 'zfs set canmount=noauto rpool/ROOT/debian');
# 				sleep( 1);
# 				system( 'zfs set canmount=off rpool/ROOT/debian');
# 				sleep( 1);
# 			}
# 			sleep( 1);
# 			# check again
# 			if ( -z $zedcachebpool or
# 					-z $zedcacherpool) {
# 				# still not there. kill, restart zed and try again, looping
# print( "Going to retry zed #$max_retries\n");
# 				system('kill -s SIGTERM zed');
# 				$fail = 1;
# 				next;
# 			} else {
# print( "Successfully created zed cache at #$max_retries\n");
# 			}
# 		} else {
# print( "Successfully created zed cache at first attempt\n");
# 			system('kill -s SIGTERM zed');
# 		}
# 	}
# if ($fail) {
# 	print "Failed zed.\n";
# } else {
# 	print "Success zed.\n";
# 	print "Going to change $zedcachebpool and $zedcacherpool.\n";
# 	removemnts($zedcachebpool);
# 	removemnts($zedcacherpool);
# }
# 	return $fail;
# }


sub do_unmountzfs
{
	my $mount = `mount`;

	my $r = 0;
	my (@zfsmnts) = $mount =~ /([^ ]+) type zfs/mg;

	while (scalar @zfsmnts) {
		my $p = pop @zfsmnts;
		$r = callsystem("umount -lf $p");
		last if ($r);
	}
	return $r;
}


##############################################################################
####################
####################	sysmod_executer START
####################
##############################################################################


# int system3( string cmdline, stringref retmsg, strref stdoutttxr, strref stderrtxr, string tmpfilebasepath, string workdir, num umaskval)
sub system3
{
	my $commamd = shift;
	my $er = shift;
	my $stdouttxr = shift;
	my $stderrtxr = shift;
	my $tmpfilebasepath = shift;
	my $workdir = shift;
	my $umaskval = shift;
	my $retval;

	my $stdoutfn = $tmpfilebasepath . '_stdout';
	my $stderrfn = $tmpfilebasepath . '_stderr';


	if (not defined $workdir) {
		$workdir = getcwd();
	}
	if (not defined $umaskval) {
		$umaskval = 002;
	}

	unlink ($stdoutfn) if (-e $stdoutfn);
	unlink ($stderrfn) if (-e $stderrfn);
	logconsole("system3.pl:system3() called");
	logconsole("    with commamd '$commamd'");
	logconsole("    with tmpfilebasepath '$tmpfilebasepath'");
	logconsole("    with workdir '$workdir'");

	my $pid = fork();
	if ($pid < 0) {
		$$er .= "Forking failed with return code $pid.";
		return $pid;
	} elsif ($pid == 0) {
		# CHILD
		# Make this process the session leader of a new session
		use POSIX qw(setsid);
		setsid() or die "Can't start a new session: $!";
# 		# Close all open file descriptors
		# Change the working directory
		chdir('/');
		# Separate from the terminal
		# Disassociate from the process group and control terminal
		# According to man 4 tty a call to TIOCNOTTY is no longer needed,
		# as this is already being done by setsid()
		# n/a
		# ignore I/O signals
		$SIG{HUP} = 'IGNORE';
		# Don’t reacquire a control terminal
		# (Anything to do for that?
		# Reset the file access creation mask
		umask $umaskval;
		close STDIN or die;
		close STDOUT or die;
		close STDERR or die;
		open(STDIN, '</dev/null') or die;
		open(STDOUT, ">$stdoutfn") or die;
		open(STDERR, ">$stderrfn") or die;
		chdir $workdir;
		my @argv = split(/ /, $commamd);
		exec( @argv);
	}
	my $wpid = waitpid($pid,0);
    # NOW: Wait for the child
	my $normalexit = WIFEXITED(${^CHILD_ERROR_NATIVE});

	if ($normalexit) {
		$retval = WEXITSTATUS(${^CHILD_ERROR_NATIVE});
	} else {
		# something unusual happened
		if (WIFSIGNALED(${^CHILD_ERROR_NATIVE})) {
			$$er .= "Child terminated due to signal";
			if (WTERMSIG(${^CHILD_ERROR_NATIVE})) {
				$$er .= ": SIGTERM";
			}
		}
	}
	if (-e $stdoutfn) {
		if (-s $stdoutfn) {
			my $s = read_a_file($stdoutfn);
			die if (not defined $s);
			$$$stdouttxr = $s;
		}
		unlink ($stdoutfn);
	}
	if (-e $stderrfn) {
		if (-s $stderrfn) {
			my $s = read_a_file($stderrfn);
			die if (not defined $s);
			$$$stderrtxr = $s;
		}
		unlink ($stderrfn);
	}

	return $retval;
}


sub escapeme
{
    my $str = shift;
    $str =~ s/\\/\\\\/;
    $str =~ s/\|/\\\|/;
    $str =~ s/\[/\\\[/;
    $str =~ s/\]/\\\]/;
    $str =~ s/\{/\\\{/;
    $str =~ s/\}/\\\}/;
    $str =~ s/\(/\\\(/;
    $str =~ s/\)/\\\)/;
    $str =~ s/\</\\\</;
    $str =~ s/\>/\\\>/;
    $str =~ s/\*/\\\*/;
    $str =~ s/\./\\\./;
    $str =~ s/\?/\\\?/;
    $str =~ s/\+/\\\+/;
    $str =~ s/\^/\\\^/;
    $str =~ s/\$/\\\$/;
    return $str;
}




# sub sysmod - replacement for useless sysrc
# see TODO PR link

sub sysmod
{
    my $filename = shift;
    my $expr = shift;
    my $oper = 'replace';
    my $parenchar = shift;
    my $sep = ' ';
    my $file;

    # remove surrounding apostrophes if present
    foreach ( '\'', '"') {
        if ($expr =~ m/^$_.*$_$/) {
            substr( $expr, length($expr) - 1, 1, "");
            substr( $expr, 0, 1, "");
        }
    }

    $file = read_a_file( $filename);
    if (not defined $file) {
        # file does not exist yet
        my $ph = '';
        $file = \$ph;
    }

    if ($parenchar eq 'delete') {
        (my $left, my $right) = $expr =~ /^(.*)=.*$/;
        die if (not defined $left);
        my $left_esc = escapeme($left);
        my $subst = $$file =~ s/^\s*$left_esc\s*=.*$//s;
        if ($subst) {
            die if (write_a_file( $filename, $file));
            logconsole( "sysmod: written changed file '$filename' with deleted '$expr'\n");
        } else {
            logconsole( "sysmod: not written file '$filename' because nothing changed, '$expr' to be deleted did not exist\n");
        }
        return;
    }

    (my $left, my $right) = $expr =~ /^(.*)=(.*)$/;
    die if (not defined $left or not defined $right);
    if ($left =~ m/\+$/) {
        $oper = 'add';
        chop $left;
    } elsif ($left =~ m/\-$/) {
        $oper = 'remove';
        chop $left;
    }

    if (($right =~ m/^".*"$/) or ($right =~ m/^'.*'$/)) {
        # $right is in parens
        substr( $right, length($right) - 1, 1, "");
        substr( $right, 0, 1, "");
    }

    if ($oper eq 'add' or $oper eq 'remove') {
        # if delimiter present, remove it
        if (length($right)) {
            if (not ($right =~ m/^[a-zA-Z1-90]/)) {
                $sep = substr( $right, 0, 1);
                substr( $right, 0, 1, "");
            }
        }
    }

    my $lv;
    my $rv;
    my $prematch;
    my $postmatch;
    my $changed = 0;
    my $left_esc = escapeme($left);
    my $right_esc = escapeme($right);

    # check whether value is already present
    if ($$file =~ m/(?:\n|^)\s*$left_esc(?:[^\n]*)(?:\n|$)/s) {
        ($prematch, $lv, $rv, $postmatch) = $$file =~ /^(.*(?:\n*))((?:\s*$left_esc\s*))=([^\n]*)(.*)$/s;
    }
    if ($parenchar ne '' and defined $rv and $rv =~ m/^$parenchar.*$parenchar$/) {
        # remove parens from $rv
        substr( $rv, length($rv) - 1, 1, "");
        substr( $rv, 0, 1, "");
    }

    if ($oper eq 'remove') {
        my $recompose = 1;
        if (not defined $lv) {
            # lv not present, nothing to do
            # check whether rvalue already contains $right
        } elsif ($rv =~ m/^(?:.*$sep\s*|)$right_esc(?:\s*$sep.*|\s+|$)/) {
            $changed = 1;
            # left present, contains right, remove right from rv
            # four cases:
            # 1. rv is only value -> remove both lv and rv
            # 2. rv is last value -> remove rv and previous delim
            # 3. rv is first value -> remove rv and first delim
            # 4. rv is middle value -> remove rv and one delim
            if ($rv =~ m/^\s*$right_esc\s*$/) {
                # 1. rv is only value -> remove both lv and rv
                # make sure only one CR remains
                if (length( $postmatch)) {
                    substr( $postmatch, 0, 1, "");
                } elsif ($prematch =~ m/\n$/) {
                    chomp $prematch;
                }
                $$file = $prematch . $postmatch;
                $recompose = 0;
            } elsif ($rv =~ m/.*$sep\s*$right_esc\s*$/) {
                # 2. rv is last value -> remove rv and previous delim
                (my $snip) = $rv =~ m/.*($sep\s*$right_esc\s*).*/;
                $rv =~ s/$snip//;
            } elsif ($rv =~ m/^\s*$right_esc\s*$sep/) {
                # 3. rv is first value -> remove rv and first delim
                (my $snip) = $rv =~ m/.*($right_esc\s*$sep\s*).*/;
                $rv =~ s/$snip//;
            } elsif ($rv =~ m/.*$sep\s*$right_esc\s*$sep\s*.*/) {
                # 4. rv is middle value -> remove rv and one delim
                (my $snip) = $rv =~ m/.*($sep\s*$right_esc\s*)$sep\s*.*/;
                $rv =~ s/$snip//;
            } else {
                die;   # should never happen
            }
        } else {
            # left present, does not contain right, nothing to do
        }
        if ($changed and $recompose) {
            $$file = $prematch . $lv . '=' . $parenchar . $rv . $parenchar . $postmatch;
        }
    } elsif ($oper eq 'add') {
        if (not defined $lv) {
            # lv not present, just add left=right
            if (not $$file =~ m/\n$/) {
                $$file .= "\n";
            }
            $$file .= $left . '=' . $parenchar . $right . $parenchar . "\n";
            $changed = 1;
            # check whether rvalue already contains $right
        } elsif ($rv =~ m/(?:.*$sep\s*|)$right_esc(?:\s*$sep.*|\s*)/) {
            # left present, contains right, nothing to do
            $changed = 0;
        } else {
            # left present, does not contain right, add right
            my $ins = '';
            if ($prematch =~ m/^\n/) {
                $ins = "\n";
            }
            $rv =~ s/\n$//s;    # chop newline if present
            $rv =~ s/\s*$//s;   # chop whitespace if present
            $ins .= $left . '=' . $parenchar . $rv . $sep . $right . $parenchar;
            $$file = $prematch . $ins . $postmatch;
            $changed = 1;
        }
    } elsif ($oper eq 'replace') {
        # make sure it is not present yet
        if (not defined $lv) {
            # lv not present, just add
            if (not $$file =~ m/\n$/) {
                $$file .= "\n";
            }
            $$file .= $left . '=' . $parenchar . $right . $parenchar . "\n";
            $changed = 1;
        } else {
            # left present, replace if rv and right not equal
            if ($right ne $rv) {
                $$file = $prematch . $left . '=' . $parenchar . $right . $parenchar . $postmatch;
                $changed = 1;
            }
        }
    }

    if ($changed) {
        die if (write_a_file( $filename, $file));
        logconsole( "sysmod: written changed file '$filename' with settings '$expr'\n");
    } else {
        logconsole( "sysmod: not written file '$filename' because nothing changed by settings '$expr'\n");
    }
}





############################################################
####################    functions for "internal batch executer"
############################################################

sub callsystem
{
	my $sy = shift;

	logconsole( "callsystem('$sy')\n");
	my $syr = system( $sy);
	if ($syr == -1) {
		# error
		my $syserrno;
		my $syserrstr;
		if ($syserrno = $!) {
			$syserrstr = "$!";
			print( "callsystem: failed with error number $syserrno ($syserrstr)\n");
			die;
		}
		my $sysstatus = $?;
		if ($sysstatus & 127) {
			my $m .= "callsystem: died with signal " . ($sysstatus & 127);
			if ($sysstatus & 128) {
				$m .= ' and dumped core';
			}
			logconsole( " $m\n");
			die;
		}
	}
	my $retc = $syr >> 8;
	print( 'callsystem: returned \'' . $retc . "'. Success\n");
	return $retc;
}


sub executer
{
	my $batch = shift;
	my @steps = split( "\n", $batch);

	logconsole( "executer start\n");
	foreach (@steps) {

if ($secondstage) {
	print "Going to execute'$_'\n";
# 	print "Hit Enter to execute";
# 	<STDIN>;
# 	print "\n";
}

		# check for cd, do these commands ourself
		if (m/^cd\s/ or m/^chdir\s/) {
			if (m/^cd\s([a-zA-Z01-9_\-\/\.]+)$/ or m/^chdir\s([a-zA-Z01-9_\-\/\.]+)$/) {
				my $newdir = $1;
				if (not chdir( $newdir)) {
					die "executer: Dir doesn't exist!"
				}
				next;
			} else {
				die "executer: Bad chdir";
			}
		} elsif (m/^$sysmod/) {
			(my $fil, my $arg, my $paren) = $_ =~ /^$sysmod\s+([^\s]*)\s+(.*?)\s+(none|single|double|delete)\s*$/;
			my $parch;
			if ($paren eq 'single') {
				$parch = '\'';
			} elsif ($paren eq 'double') {
				$parch = '"';
			} elsif ($paren eq 'none') {
				$parch = '';
			} elsif ($paren eq 'delete') {
				$parch = 'delete';
			} else {
				die "bad paren\n";
			}
			sysmod( $fil, $arg, $parch);
			next;
# 		} elsif (m/^$_fillzedcache_/) {
# 			die if (do_fillzedcache());
# 			next;
		} elsif (m/^$_appendtofstab_/) {
			die if (do_appendtofstab());
			next;
		} elsif (m/^$_unmountzfs_/) {
			die if (do_unmountzfs());
			next;
		} elsif (m/^$_writefile_import_bpool_service_/) {
			die if (do_writefile_import_bpool_service());
			next;
		}

		# check if special "pass on" return codes are defined
		# these are given in the format:
		#   [a b c]command parms
		# makes executer interpret a b c as success return codes
		# for example freebsd-update install returns 1/2 if system is up-to-date!
		my $ex;
		my @goodcodes;
		my $isspecial;
		if (m/^\[([01-9 ]+)\](.*)$/) {
			$ex = $2;
			@goodcodes = split( '\s', $1);
			$isspecial = 1;
		} else {
			$ex = $_;
			$isspecial = 0;
		}

		my $retval = 0;
		$retval = callsystem($ex);
		if ($isspecial) {
			if ( isnumin( \@goodcodes, $retval)) {
				logconsole( "executer: Success! retval $retval: '$_'\n");
				next;
			}
		} else {
			if ($retval == 0) {
				logconsole( "executer: Success! retval $retval: '$_'\n");
				next;
			}
		}
		# error out
		logconsole( "executer: Terminated: Got nonzero result from '$_'\n");
		die;
	}
	logconsole( "executer finish\n");
}


##############################################################################
####################
####################	sysmod_executer END
####################
##############################################################################








############################################################
####################    main part: batch creation
############################################################


############################################################
#################### 	START: set up dialogs data
############################################################

my $ds_cachnfstmp = 'ds_cachnfstmp';
my $ds_srv = 'ds_srv';
my $ds_usrlocal = 'ds_usrlocal';
my $ds_vargames = 'ds_vargames';
my $ds_usegui = 'ds_usegui';
my $ds_usedocker = 'ds_usedocker';
my $ds_usesnap = 'ds_usesnap';
my $ds_varwww = 'ds_varwww';
my $ds_tmp = 'ds_tmp';
my $ds_varmail = 'ds_varmail';

my %datasetlist = (
	$ds_cachnfstmp =>
			'Separate datasets for /var/cache, var/lib/nfs, /var/tmp',
	$ds_srv =>
			'Use /srv on this system',
	$ds_usrlocal =>
			'Use /usr/local on this system',
	$ds_vargames =>
			'System will have games installed',
	$ds_usegui =>
			'System will have a GUI',
	$ds_usedocker =>
			'System will use Docker (which manages its own datasets & snapshots)',
	$ds_varmail =>
			'System will store local email in /var/mail',
	$ds_usesnap =>
			'System will use Snap packages',
	$ds_varwww =>
			'Use /var/www on this system',
	$ds_tmp =>
			'Separate dataset for /tmp',
);

my @datasetseq = (
	$ds_cachnfstmp,
	$ds_srv,
	$ds_usrlocal,
	$ds_vargames,
	$ds_usegui,
	$ds_usedocker,
	$ds_varmail,
	$ds_usesnap,
	$ds_varwww,
	$ds_tmp,
);

my %datasetenable = (
	$ds_cachnfstmp	=> 'on',
	$ds_srv         => 'off',
	$ds_usrlocal    => 'on',
	$ds_vargames    => 'on',
	$ds_usegui      => 'on',
	$ds_usedocker   => 'off',
	$ds_varmail     => 'on',
	$ds_usesnap     => 'off',
	$ds_varwww      => 'on',
	$ds_tmp         => 'on',
);

my $dataset_backtitle = 'Optional datasets';
my $dataset_title = 'Configure optional datasets';
my $dataset_text = 'Please check all datasets you want installed';
my $dataset_dimensions = '20 66 ';
my $dataset_presetval = '';

my $zfsonrootinst_backtitleheader = 'ZFS on root installation';
my $bootmode_backtitle = "Boot mode selection";
my $bootmode_title = "Please choose boot mode to install";

my $goinstall_backtitle = "Install decision: Verify that all is correct";
my $goinstall_title = "Resulting data and command batch";
my $goinstall_questionstart = "Please decide whether to install or not:\n\n";
my $goinstall_question = "Select Yes to install, No to abort";

my $inp_hostname_backtitle = 'Hostname';
my $inp_hostname_title = 'Configure the hostname';
my $inp_hostname_text = 'Please enter desired hostname';
my $inp_hostname_dimensions = '10 40';
my $inp_hostname_presetval = '';

my $inp_interface_backtitle = 'Interface';
my $inp_interface_title = 'Configure the interface';
my $inp_interface_text = 'Please choose interface to use';
my $inp_interface_dimensions = '15 75';
my $inp_interface_presetval = '';

############################################################
#################### 	END: set up dialogs data
############################################################

#
# $cmd .= "sudo apt install python3-pip\n";
# $cmd .= "pip3 install -r docs/requirements.txt\n";
# $cmd .= "# Add ~/.local/bin to your $PATH, e.g. by adding this to ~/.bashrc:\n";
# $cmd .= "PATH=$HOME/.local/bin:$PATH\n";


#################### start: set up configuration storage variables

# my $bootpool = 'bpool';
# my $rootpool = 'rpool';
# my $rootpool = 'rpool';
my $bootpool;
my $rootpool;


# config query data
# see do_queries()
my %selecteddrives;
my %datasetlist_selected = ();
my $my_hostname;
my $installuefi; # bool: if 0 install CSM
# see do_createbatch()
my $aptsourceslistfn = '/etc/apt/sources.list';
my $aptsourceslist_orig;
my $aptsourceslist_new;

my $hostnamefn = '/etc/hostname';
# my $hostname_orig;
my $hostname_new;

my $hostsfn = '/etc/hosts';
my $hosts_orig;
my $hosts_new;

# aux internal vars for do_queries and do_createbatch
my @drives;
my %drives_byidtosd = ();

my $intfconfigfnam;
my $intfconfigftxt;
# my $aptsourceslistr;

my $inp_interface_selected;

my $mountpref = '/mnt';

my $etcdkmszfsconffn = '/etc/dkms/zfs.conf';
my $etcdkmszfsconf;


my $cmd = '';
my $cmd2 = '';




my $etcdefaultgrubfnpath_tmp = '/root/etcdefaultgrub';
my $etcdefaultgrubfnpath_target = '/etc/default/grub';
# my $etcdefaultgrubfnpath_target = $mountpref . '/etc/default/grub';

my $etcdefaultgrub =
'# If you change this file, run \'update-grub\' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n \'Simple configuration\'

GRUB_DEFAULT=0
GRUB_TIMEOUT=120
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
# GRUB_CMDLINE_LINUX_DEFAULT="nomodeset"
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX="root=ZFS====DEBIANROOTPOOL===/ROOT/debian"
GRUB_TERMINAL=console
# Uncomment if you do not want GRUB to pass "root=UUID=xxx" parameter to Linux
#GRUB_DISABLE_LINUX_UUID=true
# Uncomment to get a beep at grub start
#GRUB_INIT_TUNE="480 440 1"
';
#################### end: set up configuration storage variables



############################################################
####################    main part: query configuration
############################################################

sub do_queries
{
	# Select disk for install
	getdrivesinfo();
	# make a dialog for selection
	my @driveseq;
	foreach (sort keys %$$availdrives) {
print "drive '$_'\n";
		push @driveseq, $_;
	}

	do {
		getcheckform (
			$$availdrives,
			\@driveseq,
			"$zfsonrootinst_backtitleheader: Target drives",
			'Target drives selection',
			'Choose the target drives on which you want to install.\nNote:\nInternally disk-by-id will be used.',
			'15 80 8',
			\%selecteddrives,
			);

			# TODO maybe there should be a notification instead of just
			# repeating questionnaire if the user deselects all
	} while ( not scalar keys %selecteddrives);

	# set the chosen drive(s)
	foreach (keys %selecteddrives) {
		my $wwnid = getdrivewwnid($_);
		push @drives, $wwnid;
		$drives_byidtosd{$wwnid} = $_;
	}

	# Check
	die("No drives selected!\n") if (not scalar @drives);

	getcheckform (
		\%datasetlist,
		\@datasetseq,
		"$zfsonrootinst_backtitleheader: $dataset_backtitle",
		$dataset_title,
		$dataset_text,
		'15 80 8',
		\%datasetlist_selected,
		\%datasetenable,
		undef);

	$my_hostname = inputbox(
				"$zfsonrootinst_backtitleheader: $inp_hostname_backtitle",
				$inp_hostname_title,
				$inp_hostname_text,
				$inp_hostname_dimensions,
				$inp_hostname_presetval );









	# MAYBE MAKE FUNCTION SETHOSTNAME
	# TODO check for valid hostname

	# pool names are
	#	boot:  <hostname>boot
	#	root:  <hostname>root
	#	user data pool:  <hostname>pool
	$bootpool = $my_hostname . 'boot';
	$rootpool = $my_hostname . 'root';

	# update other variables connected to hostname
# 	$zedcachebpool = "$zedcachedir/$bootpool";
# 	$zedcacherpool = "$zedcachedir/$rootpool";

	$etcdefaultgrub =~ s/===DEBIANROOTPOOL===/$rootpool/;





	# ask whether Grub for the different mode should be installed
	my $ourmode;
	my $othermode;

	my $efidir = '/sys/firmware/efi';
	if (-e $efidir and -d $efidir) {
		$ourmode = 'UEFI';
		$othermode = 'CSM BIOS';
	} else {
		$ourmode = 'CSM BIOS';
		$othermode = 'UEFI';
	}
	my $bootmode_question = "Your system booted in $ourmode mode.\n" .
						"Choose YES if you want $ourmode installation, NO if you want $othermode installation.";
	my $r = yesno(
				$bootmode_backtitle,
				$bootmode_title,
				$bootmode_question,
				'15 60');
	$installuefi = ( (($ourmode eq 'UEFI') and $r) or
						(($ourmode eq 'CSM BIOS') and not $r) );

	getinterfs();
	my %interflist;
	my @interfseq;
# 	my $inp_interface_selected;
	my $inp_interface_selected_preset;

	foreach (sort keys %$$intfsh) {

		my $ifname = $_;
		my $m = '';
# 		$m .= (exists $$$intfsh{$ifname}->{$ifvar_nocarrier})
# 				? ''
# 				: '[Act] ';
		if (exists $$$intfsh{$ifname}->{$ifvar_nocarrier}) {
			$m .= '';
		} else {
			$m .= '[Act] ';
		}
# 		$m .= (exists $$$intfsh{$ifname}->{$ifvar_ip4})
# # 				? ('[IP: ' . $$$intfsh{$ifname}->{$ifvar_ip4} . ']')
# 				? ('[Inet] ')
# 				: '';
		if (exists $$$intfsh{$ifname}->{$ifvar_ip4}) {
			$m .= '[Inet] ';
			if (not exists $$$intfsh{$ifname}->{$ifvar_nocarrier}) {
				# make preset only if has IP4 and is online
				$inp_interface_selected_preset = $ifname;
			}
		}
		$m .= 	$$$intfsh{$ifname}->{$ifvar_vendor} . ' ' .
				$$$intfsh{$ifname}->{$ifvar_model};
		$interflist{$ifname} = $m;
		push @interfseq, $ifname;
	}

	getradioform (
		\%interflist,
		\@interfseq,
		"$zfsonrootinst_backtitleheader: $inp_interface_backtitle",
		$inp_interface_title,
		'Please choose the interface you want to use.\nThere will be created an according config file in \'/etc/network/interfaces.d/...\'.\n(Note: You can edit that file to change your choice later if that interface does not use DHCP.)',
		'19 80 14',
		\$inp_interface_selected,
		\$inp_interface_selected_preset);


# TODO
	my $interfaces_conf =
"auto $inp_interface_selected
iface $inp_interface_selected inet dhcp
";


}






############################################################
####################    main part: batch creation
############################################################

sub getdrivepath
{
	my $drv = shift;
	my $partno = shift;

# 	my $did = $drives_byidtosd{$drv};
	my $did = $drv;
	my $dp = " /dev/$diskbyid$did";
# 	my $dp = " /dev/disk/$did";
# 	my $dp = " $did";

	if (defined $partno and not ($dp =~ /^uuid/)) {
# 		if ($usesdX) {
# 			$dp .= $partno;
# 		} else {
			$dp .= "-part$partno";
# 		}
	}

	return $dp;
}

# see https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Bookworm%20Root%20on%20ZFS.html

sub do_createbatch
{
	# Configure the package sources:
	# Change file /etc/apt/sources.list
	my $aptsourceslist_orig = read_a_file($aptsourceslistfn);
	die if (not defined $aptsourceslist_orig);

	# work and compareable copy
	my $an = $$aptsourceslist_orig;
	$aptsourceslist_new = \$an;
	# add bookworm-backports contrib non-free


	# TODO  bookworm-backports valid on all servers?

 	$an =~ s/main non-free-firmware/main bookworm-backports contrib non-free non-free-firmware/g;
	die if (write_a_file($aptsourceslistfn, $aptsourceslist_new));


	$cmd .= "sudo apt update\n";

	# if not using gnome, do we really need this crap?
	$cmd .= "[0 1]gsettings set org.gnome.desktop.media-handling automount false\n";
# 	$cmd .= "apt install --yes debootstrap gdisk zfsutils-linux\n";
	$cmd .= "apt install --yes debootstrap\n";
	$cmd .= "apt install --yes gdisk\n";
	$cmd .= "apt install --yes zfsutils-linux\n";

	foreach (@drives) {
		my $DISK = $_;

		# For flash-based storage, if the disk was previously used,
		# you may wish to do a full-disk discard (TRIM/UNMAP),
		# which can improve performance:

		# check whether this is flash stg
		my $dr = $drives_byidtosd{$DISK};
		my $isflashtmp = `cat /sys/block/$dr/queue/rotational`;
		if (index($isflashtmp, '0') != -1) {
			$cmd .= "[0 1]blkdiscard -f /dev/$diskbyid$DISK\n";
		}

		# Clear the partition table:
		$cmd .= "[0 2]sgdisk --zap-all /dev/$diskbyid$DISK\n";

		# Check for message:
		# If you get a message about the kernel still using the
		# old partition table, reboot and start over
		# (except that you can skip this step).
		# TODO to be sure, check if this does give a nonzero return code!

		# Run this if you need legacy (BIOS) booting:
		$cmd .= "sgdisk -a1 -n1:24K:+1000K -t1:EF02 /dev/$diskbyid$DISK\n";
		# Run this for UEFI booting (for use now or in the future):

		$cmd .= "sgdisk -n2:1M:+512M -t2:EF00 /dev/$diskbyid$DISK\n";
		# Run this for the boot pool:
		$cmd .= "sgdisk -n3:0:+1G -t3:BF01 /dev/$diskbyid$DISK\n";
		# Unencrypted or ZFS native encryption:
		$cmd .= "sgdisk -n4:0:0 -t4:BF00 /dev/$diskbyid$DISK\n";
		$cmd .= "partprobe /dev/$diskbyid$DISK\n";
# 		# ZFS will complain if the parts still contain metadata
# 		# so lets delete first 1000K
# 		$cmd .= "dd if=/dev/zero of=/dev/disk/by-id/$DISK-part3 count=1 bs=1000K\n";
# 		$cmd .= "dd if=/dev/zero of=/dev/disk/by-id/$DISK-part4 count=1 bs=1000K\n";
	}

# 	# Ask: Mirror, raidz_something?
# 	if (scalar @drives > 1) {
# 		my %topol_list = (
# 			'mirror'    => 'Each drive is mirrored',
# 			'raidz'     => 'Drives are joined to a large one - no redundancy',
# 			'Gnome'     => 'The Gnome - for those who like it, it is the best',
# 			'Mate'      => 'Derived from old Gnome, faster than current Gnome',
# 			'XFCE'      => 'Another Windows clone, leaner than KDE',
# 		);
#
# 	}

	# for now skip raidz, as only mirror allows round-robin reads
	# on all vdevs, which we want for performance

	if ($use_zpool_attach == 0) {
		# Create the boot pool using mirror:
		my $thesedrives = (scalar @drives > 1) ? ' mirror' : '';
		foreach (@drives) {
# 			$thesedrives .= ' -d ' . getdrivepath($_, 3);
			$thesedrives .= getdrivepath($_, 3);
		}

		$cmd .= "zpool create" .
		$forcezpoolcreate .
		" -o ashift=12" .
		" -o autotrim=on" .
		" -o compatibility=grub2" .
# 		" -o cachefile=/etc/zfs/zpool.cache" .
# 		" -o cachefile=none" .
		" -O devices=off" .
		" -O acltype=posixacl" .
		" -O xattr=sa" .
		" -O compression=lz4" .
		" -O normalization=formD" .
		" -O relatime=on" .
		" -O canmount=off" .
		" -O mountpoint=/boot" .
		" -R $mntprefix" .
		" $bootpool$thesedrives\n";

		$cmd .= "zpool set cachefile=none $bootpool\n";

		# Create the root pool:
		$thesedrives = (scalar @drives > 1) ? ' mirror' : '';
		foreach (@drives) {
# 			$thesedrives .= ' -d ' . getdrivepath($_, 4);
			$thesedrives .= getdrivepath($_, 4);
		}

		$cmd .= "zpool create" .
		$forcezpoolcreate .
		" -o ashift=12" .
		" -o autotrim=on" .
		" -O acltype=posixacl" .
		" -O xattr=sa" .
		" -O dnodesize=auto" .
		" -O compression=lz4" .
		" -O normalization=formD" .
		" -O relatime=on" .
		" -O canmount=off" .
		" -O mountpoint=/" .
		" -R $mntprefix" .
		" $rootpool$thesedrives\n";

		$cmd .= "zpool set cachefile=none $rootpool\n";

	} else {	# not: if ($use_zpool_attach == 0) {
		# Create the boot pool using attach:
		my $firstdrive;
		my @otherdrives;

		foreach (@drives) {
			if (not defined $firstdrive) {
				$firstdrive = getdrivepath($_, 3);
			} else {
				push @otherdrives, getdrivepath($_, 3);
			}
		}

		$cmd .= "zpool create" .
		$forcezpoolcreate .
		" -o ashift=12" .
		" -o autotrim=on" .
		" -o compatibility=grub2" .
# 		" -o cachefile=/etc/zfs/zpool.cache" .
# 		" -o cachefile=none" .
		" -O devices=off" .
		" -O acltype=posixacl" .
		" -O xattr=sa" .
		" -O compression=lz4" .
		" -O normalization=formD" .
		" -O relatime=on" .
		" -O canmount=off" .
		" -O mountpoint=/boot" .
		" -R $mntprefix" .
		" $bootpool$firstdrive\n";

		$cmd .= "zpool set cachefile=none $bootpool\n";

		# mirror?
		if (scalar @otherdrives) {
			foreach (@otherdrives) {
				# if not adding ashift option zpool triggers a bug
#  				$cmd .= "zpool attach -sw -o ashift=12 $bootpool $firstdrive $_\n";
 				$cmd .= "zpool attach" .
					" -w" .
					" -o ashift=12" .
# 		" -o autotrim=on" .
# 		" -o compatibility=grub2" .
# 		" -o cachefile=/etc/zfs/zpool.cache" .
					" $bootpool $firstdrive $_\n";
			}
		}

		# Create the root pool:
		$firstdrive = undef;
		@otherdrives = ();

		foreach (@drives) {
			if (not defined $firstdrive) {
				$firstdrive = getdrivepath($_, 4);
			} else {
				push @otherdrives, getdrivepath($_, 4);
			}
		}

		$cmd .= "zpool create" .
		$forcezpoolcreate .
# 		" -o cachefile=none" .
		" -o ashift=12" .
		" -o autotrim=on" .
		" -O acltype=posixacl" .
		" -O xattr=sa" .
		" -O dnodesize=auto" .
		" -O compression=lz4" .
		" -O normalization=formD" .
		" -O relatime=on" .
		" -O canmount=off" .
		" -O mountpoint=/" .
		" -R $mntprefix" .
		" $rootpool$firstdrive\n";

		$cmd .= "zpool set cachefile=none $rootpool\n";

		# mirror?
		if (scalar @otherdrives) {
			foreach (@otherdrives) {
				# if not adding ashift option zpool triggers a bug
				$cmd .= "zpool attach$forcezpoolcreate -sw -o ashift=12 $rootpool $firstdrive $_\n";
			}
		}
	} 	# not: if ($use_zpool_attach == 0)

	# Create filesystem datasets to act as containers:

# 	$cmd .= "zfs create -o cachefile=none -o canmount=off -o mountpoint=none $rootpool/ROOT\n";
# 	$cmd .= "zfs create -o cachefile=none -o canmount=off -o mountpoint=none $bootpool/BOOT\n";
	$cmd .= "zfs create -o canmount=off -o mountpoint=none $rootpool/ROOT\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/ROOT\n";
	$cmd .= "zfs create -o canmount=off -o mountpoint=none $bootpool/BOOT\n";
# 	$cmd .= "zpool set cachefile=none $bootpool/BOOT\n";

	# Create filesystem datasets for the root and boot filesystems:

# 	$cmd .= "zfs create -o cachefile=none -o canmount=noauto -o mountpoint=/ $rootpool/ROOT/debian\n";
	$cmd .= "zfs create -o canmount=noauto -o mountpoint=/ $rootpool/ROOT/debian\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/ROOT/debian\n";

	my $debianroot = "$rootpool/ROOT/debian";
	$cmd .= "zfs mount $debianroot\n";




	# TODO
	# make sure that there is an immutablen cache file of length zero
	# so in case of attempts of autoimporting cache nothing can be broken

# 	$cmd .= "rm -f $debianroot/etc/zfs/zpool.cache\n";
# 	$cmd .= "touch $debianroot/etc/zfs/zpool.cache\n";
# 	$cmd .= "chmod a-w $debianroot/etc/zfs/zpool.cache\n";
# 	$cmd .= "chattr +i $debianroot/etc/zfs/zpool.cache\n";




# 	$cmd .= "zfs create -o cachefile=none -o mountpoint=/boot $bootpool/BOOT/debian\n";
	$cmd .= "zfs create -o mountpoint=/boot $bootpool/BOOT/debian\n";
# 	$cmd .= "zpool set cachefile=none $bootpool/BOOT/debian\n";

	# Create datasets:

	# NOTE Dont create home dataset.
	# Create a link later in postinstallation, before adding users.
	# -> do_createpostinstallbatch()

# 	$cmd .= "zfs create $rootpool/home\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/home\n";

# 	$cmd .= "zfs create -o mountpoint=/root $rootpool/home/root\n";
	$cmd .= "zfs create -o mountpoint=/root $rootpool/roothome\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/home/root\n";
	$cmd .= "chmod 700 $mntprefix/root\n";





	$cmd .= "zfs create -o canmount=off  $rootpool/var\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/var\n";
	$cmd .= "zfs create -o canmount=off  $rootpool/var/lib\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/var/lib\n";
	$cmd .= "zfs create $rootpool/var/log\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/var/log\n";
	$cmd .= "zfs create $rootpool/var/spool\n";
# 	$cmd .= "zpool set cachefile=none $rootpool/var/spool\n";

	# The datasets below are optional, depending on your preferences and/or software choices.
	# If you wish to separate these to exclude them from snapshots:
	if (exists $datasetlist_selected{$ds_cachnfstmp} ) {
		$cmd .= "zfs create -o com.sun:auto-snapshot=false $rootpool/var/cache\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/cache\n";
		$cmd .= "zfs create -o com.sun:auto-snapshot=false $rootpool/var/lib/nfs\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/lib/nfs\n";
		$cmd .= "zfs create -o com.sun:auto-snapshot=false $rootpool/var/tmp\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/tmp\n";
		$cmd .= "chmod 1777 $mntprefix/var/tmp\n";
	}

	# If you use /srv on this system:
	if (exists $datasetlist_selected{$ds_srv} ) {
		$cmd .= "zfs create $rootpool/srv\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/srv\n";
	}

	# If you use /usr/local on this system:
	if (exists $datasetlist_selected{$ds_usrlocal} ) {
		$cmd .= "zfs create -o canmount=off $rootpool/usr\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/usr\n";
		$cmd .= "zfs create $rootpool/usr/local\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/usr/local\n";
	}

	# If this system will have games installed:
	if (exists $datasetlist_selected{$ds_vargames} ) {
		$cmd .= "zfs create $rootpool/var/games\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/games\n";
	}

	# If this system will have a GUI:
	if (exists $datasetlist_selected{$ds_usegui} ) {
		$cmd .= "zfs create $rootpool/var/lib/AccountsService\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/lib/AccountsService\n";
		$cmd .= "zfs create $rootpool/var/lib/NetworkManager\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/lib/NetworkManager\n";
	}

	# If this system will use Docker (which manages its own datasets & snapshots):
	if (exists $datasetlist_selected{$ds_usedocker} ) {
		$cmd .= "zfs create -o com.sun:auto-snapshot=false $rootpool/var/lib/docker\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/lib/docker\n";
	}

	# If this system will store local email in /var/mail:
	if (exists $datasetlist_selected{$ds_varmail} ) {
		$cmd .= "zfs create $rootpool/var/mail\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/mail\n";
	}

	# If this system will use Snap packages:
	if (exists $datasetlist_selected{$ds_usesnap} ) {
		$cmd .= "zfs create $rootpool/var/snap\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/snap\n";
	}

	# If you use /var/www on this system:
	if (exists $datasetlist_selected{$ds_varwww} ) {
		$cmd .= "zfs create $rootpool/var/www\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/var/www\n";
	}

	# A tmpfs is recommended later, but if you want a separate dataset for /tmp:
	if (exists $datasetlist_selected{$ds_tmp} ) {
		$cmd .= "zfs create -o com.sun:auto-snapshot=false $rootpool/tmp\n";
# 		$cmd .= "zpool set cachefile=none $rootpool/tmp\n";
		$cmd .= "chmod 1777 $mntprefix/tmp\n";
	}





	# Mount a tmpfs at /run:
	$cmd .= "mkdir $mntprefix/run\n";
	$cmd .= "mount -t tmpfs tmpfs $mntprefix/run\n";
	$cmd .= "mkdir $mntprefix/run/lock\n";




















	# create swap partition if user chose so




	# get swap partition wwn/uuid whatever

	# set it in /etc/fstab
	# TODO
# # swap was on /dev/md0p7 during installation
# UUID=58f3687f-ad89-42a4-b463-a5da03c3f279 none            swap    sw              0       0
# aber wwn path besser


# ggfs dann swapon

	# set it in grubb
	# https://wiki.ubuntuusers.de/Archiv/pm-utils/
	# TODO
#
#  Am wichtigsten ist dabei die Datei /etc/initramfs-tools/conf.d/resume. Wenn nicht, dann die Angaben in die entsprechenden Dateien schreiben bzw. korrigieren (und ggf. die GRUB-Konfiguration aktuallisieren).
#
# initrd aktualisieren:
#
# sudo update-initramfs -u
#
# System neu starten und STD testen.

# alternativ:
# o regenerate all of the initrd.img-* files (not recommended), use:
#
# sudo update-initramfs -c -k all
















	# Install the minimal system:
	# The debootstrap command leaves the new system in an unconfigured state.
	# An alternative to using debootstrap is to copy the entirety of a working system into the new ZFS root.
	$cmd .= "debootstrap bookworm /mnt\n";


	# Copy in zpool.cache:
# 	$cmd .= "mkdir $mntprefix/etc/zfs\n";
# 	$cmd .= "cp /etc/zfs/zpool.cache $mntprefix/etc/zfs/\n";

	# Step 4: System Configuration

	# Configure the hostname:
	# Replace HOSTNAME with the desired hostname:
# 	my $hostname_orig = read_a_file($hostnamefn);
# 	die if (not defined $hostname_orig);
	# work and compareable copy
# 	$hostname_new = \$an;
	$hostname_new .= "$my_hostname\n";

# 	$cmd .= "hostname $my_hostname\n";
# 	$cmd .= "hostname > /mnt/etc/hostname\n";



	# Update /etc/hosts
# 		vi /mnt/etc/hosts
# 		Add a line:
# 		127.0.1.1       HOSTNAME
# 		or if the system has a real name in DNS:
# 		127.0.1.1       FQDN HOSTNAME
	$hosts_orig = read_a_file($hostsfn);
	die if (not defined $hosts_orig);
	# work and compareable copy
# 	my $hon = $$hosts_orig;
# 	$hosts_new = \$hon;
	$hosts_new = $$hosts_orig;

	$hosts_new .= "\n127.0.0.1\t$my_hostname$etchosts\n";
# 	die if (append_a_file('/mnt/etc/hostname', \$addstr));
# 	die if (append_a_file('/mnt/etc/hostname', \$addstr));


	# Create the interface conf file

# 	$intfconfigfnam = $mntprefix . '/etc/network/interfaces.d/' . $inp_interface_selected;
	$intfconfigfnam = '/etc/network/interfaces.d/' . $inp_interface_selected;
	$intfconfigftxt =
		"Customize this file if the system is not a DHCP client.\n" .
		"auto $inp_interface_selected\n" .
		"iface $inp_interface_selected inet dhcp\n";



	# Configure the package sources:
	# Change file /etc/apt/sources.list
	# It is stored in $aptsourceslist_new
	# Only the live system entries need to be removed
	# eg these not on http: but on file:
# 	$aptsourceslistr = read_a_file($aptsourceslistfn);
# 	die if (not defined $aptsourceslistr);
#
# 	# add contrib
#  	$$aptsourceslistr =~ s/main non-free-firmware/main contrib non-free non-free-firmware/g;

	$$aptsourceslist_new =~ s/^deb \[trusted=yes\] file.*$//mg;


	#	Bind the virtual filesystems from the LiveCD environment
	#	to the new system and chroot into it:

	# Note: This is using --rbind, not --bind.

	$cmd .= "mount --make-private --rbind /dev $mntprefix/dev\n";
	$cmd .= "mount --make-private --rbind /proc $mntprefix/proc\n";
	$cmd .= "mount --make-private --rbind /sys $mntprefix/sys\n";

	$cmd .= "cp /root/$myname $mntprefix/root\n";
	$cmd .= "cp $file_firststage $mntprefix/root\n";
	$cmd .= "cp $file_secondstage $mntprefix/root\n";
	$cmd .= "cp $file_secondstage_bootstrap $mntprefix/root\n";
	$cmd .= "cp $hostnamefn $mntprefix$hostnamefn\n";
	$cmd .= "cp $hostsfn $mntprefix$hostsfn\n";
	$cmd .= "cp $aptsourceslistfn $mntprefix$aptsourceslistfn\n";

	$cmd .= "cp $etcdefaultgrubfnpath_tmp $mntprefix/root\n";
# 	$cmd .= "cp $etcdefaultgrubfnpath_tmp $etcdefaultgrubfnpath_target\n";
# 	$cmd .= "cp $etcdefaultgrubfnpath_tmp $mountpref$etcdefaultgrubfnpath_tmp\n";


# 	$cmd .= "chroot /mnt /usr/bin/env DISK=$DISK bash --login\n";
# 	$cmd .= "chroot /mnt /usr/bin/env bash --login\n";
	$cmd .= "chroot $mntprefix $file_secondstage_bootstrap\n";

	$cmd .= "$_unmountzfs_\n";

	# TODO
	# give a notice here that in fail case one needs to enter
# if this fails for rpool, mounting it on boot will fail
# and you will need to zpool import -f rpool, then exit in the initramfs prompt.
	$cmd .= "zpool export -a\n";


	# create batch for chroot

	$boot2 = "#!/usr/bin/bash\n";
	$boot2 .= "apt update\n";
	# first the bootstrap to get full Perl installed
	$boot2 .= "apt install --yes perl\n";


	# not inherited??
	$boot2 .= "apt install --yes dialog\n";


	$boot2 .= "perl /root/$myname -2\n";


	# Configure a basic system environment:

	$cmd2 .= "apt install --yes console-setup locales\n";

	# Even if you prefer a non-English system language,
	# always ensure that en_US.UTF-8 is available:

	$cmd2 .= "dpkg-reconfigure locales tzdata keyboard-configuration console-setup\n";

	# Install ZFS in the chroot environment for the new system:
	$cmd2 .= "apt install --yes dpkg-dev linux-headers-generic linux-image-generic\n";
	$cmd2 .= "apt install --yes zfs-initramfs\n";

	# Change file /etc/dkms/zfs.conf
	$cmd2 .= "$sysmod $etcdkmszfsconffn REMAKE_INITRD=yes none\n";


	# Note:
	# Ignore any error messages saying
	# ERROR: Couldn't resolve device and
	# WARNING: Couldn't determine root device. cryptsetup does not support ZFS

# 		For LUKS installs only, setup /etc/crypttab:
#
# 		apt install --yes cryptsetup cryptsetup-initramfs
#
# 		echo luks1 /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}-part4) \
# 			none luks,discard,initramfs > /etc/crypttab
#
# 		The use of initramfs is a work-around for cryptsetup does not support ZFS.
#
# 		Hint: If you are creating a mirror or raidz topology, repeat the /etc/crypttab entries for luks2, etc. adjusting for each disk.

	# Install an NTP service to synchronize time.
	# This step is specific to Bookworm which does not install
	# the package during bootstrap. Although this step is not
	# necessary for ZFS, it is useful for internet browsing where
	# local clock drift can cause login failures:

	$cmd2 .= "apt install systemd-timesyncd\n";



























	#### GRUB part
	$cmd2 .= "cp $etcdefaultgrubfnpath_tmp $etcdefaultgrubfnpath_target\n";
	if ($installuefi) {
		$cmd2 .= "apt install dosfstools\n";

		my $usedrive = $drives[0];
		$cmd2 .= "mkdosfs -F 32 -s 1 -n EFI $usedrive-part2\n";
		$cmd2 .= "mkdir /boot/efi\n";
# echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}-part2) \
#    /boot/efi vfat defaults 0 0 >> /etc/fstab
# 		$cmd2 .= "echo /dev/disk/by-uuid/$(blkid -s UUID -o value $usedrive-part2) /boot/efi vfat defaults 0 0 >> /etc/fstab\n";
		my $blkid = `blkid -s UUID -o value $usedrive-part2`;
		my $blkid_first = $blkid;
		$appendtofstab = "/dev/disk/by-uuid/$blkid_first /boot/efi vfat defaults 0 0\n";
		$cmd2 .= "$_appendtofstab_\n";

		$cmd2 .= "mount /boot/efi\n";
		$cmd2 .= "apt install --yes grub-efi-amd64 shim-signed\n";

		# Install the boot loader:
		# If you are creating a mirror or raidz topology,
		# repeat the grub-install command for each disk in the pool.

		# For UEFI booting, install GRUB to the ESP:

		$cmd2 .= "grub-install --target=x86_64-efi " .
					"--efi-directory=/boot/efi " .
					"--bootloader-id=debian --recheck --no-floppy\n";

		# It is not necessary to specify the disk here.
		# If you are creating a mirror or raidz topology,
		# the additional disks will be handled later.

		$cmd2 .= "umount /boot/efi\n";


		if (scalar @drives > 1) {
			$cmd2 .= "umount /boot/efi\n";
			my $dskind = 1;
			# For the second and subsequent disks (increment debian-2 to -3, etc.):
			while ($dskind < scalar @drives) {
				$cmd2 .= "dd if=$usedrive-part2 of=" . $drives[$dskind] . "-part2\n" .
					"efibootmgr -c -g -d " . $drives[$dskind] . " -p 2 " .
						"-L \"debian-" . ++$dskind . "\" -l '\\EFI\\debian\\grubx64.efi'\n";
				my $blkid_old = $blkid;
				$blkid = `blkid -s UUID -o value $drives[$dskind]-part2`;
				my $changefstabfrom = "\\/dev\\/disk\\/by-uuid\\/$blkid_old \\/boot\\/efi vfat defaults 0 0";
				my $changefstabto = "\\/dev\\/disk\\/by-uuid\\/$blkid \\/boot\\/efi vfat defaults 0 0";
				# update fstab and then
				$cmd2 .= "sed -i 's/$changefstabfrom/$changefstabto' $file_etc_fstab\n";
				$cmd2 .= "mount /boot/efi\n";
				$cmd2 .= "apt install --yes grub-efi-amd64 shim-signed\n";
				$cmd2 .= "umount /boot/efi\n";
			}
			# finally restore fstab so /boot/efi points to first (boot) disk
			my $changefstabfrom = "\\/dev\\/disk\\/by-uuid\\/$blkid \\/boot\\/efi vfat defaults 0 0";
			my $changefstabto = "\\/dev\\/disk\\/by-uuid\\/$blkid_first \\/boot\\/efi vfat defaults 0 0";
			$cmd2 .= "sed -i 's/$changefstabfrom/$changefstabto' $file_etc_fstab\n";



		}
	} else {
		# For legacy (BIOS) booting, install GRUB to every drives' MBR:
		$cmd2 .= "apt install --yes grub-pc\n";
		$cmd2 .= "apt purge --yes os-prober\n";
		foreach (@drives) {
			# Note that you are installing GRUB to the whole disk,
			# not a partition.
			$cmd2 .= "grub-install /dev/$diskbyid$_\n";
		}
		if (scalar @drives > 1) {
			# interaktiv
			$cmd2 .= "dpkg-reconfigure grub-pc\n";
		}
	}

	# Grub install
	# Step 5: GRUB Installation

	# Verify that the ZFS boot filesystem is recognized:
	$cmd2 .= "grub-probe /boot\n";

	# Refresh the initrd files:
	$cmd2 .= "update-initramfs -c -k all\n";

	# instead of modding the default grub config file, just overwrite that trash
	$cmd2 .= "cp /root/etcdefaultgrub /etc/default/grub\n";



# obsoleted:
# 	# Workaround GRUB’s missing zpool-features support:
# # 	$cmd2 .= "$sysmod /etc/default/grub GRUB_CMDLINE_LINUX-=root=ZFS=/ROOT/debian double\n";
# 	$cmd2 .= "$sysmod /etc/default/grub GRUB_CMDLINE_LINUX=root=ZFS=rpool/ROOT/debian double\n";
#
# 	# Optional (but highly recommended): Make debugging GRUB easier:
# 	$cmd2 .= "$sysmod /etc/default/grub GRUB_CMDLINE_LINUX_DEFAULT-=quiet double\n";
# 	$cmd2 .= "$sysmod /etc/default/grub GRUB_TERMINAL=console none\n";
# 	$cmd2 .= "$sysmod /etc/default/grub GRUB_TIMEOUT=60 none\n";

	# Update the boot configuration:
	$cmd2 .= "update-grub\n";
	# Note: Ignore errors from osprober, if present.


	# Enable import bpool for systemd
	# 	$file_import_bpool_service -> /etc/systemd/system/zfs-import-bpool.service
	$cmd2 .= "$_writefile_import_bpool_service_\n";
	$cmd2 .= "systemctl enable zfs-import-bpool.service\n";

	# 	Note: For some disk configurations (NVMe?), this service may fail with an error indicating that the bpool cannot be found. If this happens, add -d DISK-part3 (replace DISK with the correct device path) to the zpool import command.


	# Fix filesystem mount ordering:

	# We need to activate zfs-mount-generator.
	# This makes systemd aware of the separate mountpoints,
	# which is important for things like /var/log and /var/tmp.
	# In turn, rsyslog.service depends on var-log.mount by way
	# of local-fs.target and services using the PrivateTmp feature
	# of systemd automatically use After=var-tmp.mount.

# 	$cmd2 .= "mkdir $zedcachedir\n";
# 	$cmd2 .= "touch $zedcacherpool\n";
# 	$cmd2 .= "touch $zedcachebpool\n";
#
# 	$cmd2 .= "_fillzedcache_\n";

	# Set a root password:
	# TODO print some instruction
	$cmd2 .= "passwd\n";



	#### Step 8: Full Software Installation
	$cmd2 .= "apt dist-upgrade --yes\n";
	$cmd2 .= "tasksel --new-install\n";

	# TODO
	# 	Disable log compression:
# 	for file in /etc/logrotate.d/* ; do
# 	if grep -Eq "(^|[^#y])compress" "$file" ; then
# 		sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
# 	fi
# 	done

# 	my @logd = getdirfiles( '/etc/logrotate.d');
# 	foreach (@logd) {
# 		# TODO
#
#
# 	}

	$cmd2 .= "zfs snapshot $bootpool/BOOT/debian\@install\n";
	$cmd2 .= "zfs snapshot $rootpool/ROOT/debian\@install\n";



}


sub do_showbatchandconfig
{
	my $m = '';

	$m .= "################ New APT sources list:\n" .
			"####  START\n";
	$m .= "$$aptsourceslist_new\n";
	$m .= "####  END\n";

	$m .= "################ Installing system on these drives:\n" .
			"####  START\n";
	foreach (sort @drives) {
		$m .= " $_\n";
	}
	$m .= "####  END\n";


	$m .= "################ Using these datasets:\n" .
			"####  START\n";
# 	$m .= "####  START keys\n";
	foreach (sort keys %datasetlist_selected) {
		$m .= " $_\n";
	}

# 	$m .= "####  START vals\n";
# 	foreach (sort %datasetlist_selected) {
# 		$m .= " $_\n";
# 	}
	$m .= "####  END\n";

	#
	$m .= "################ New '$hostnamefn' file contents:\n" .
			"####  START '$hostnamefn'\n" .
			$hostname_new .
			"####  END '$hostnamefn'\n";

	$m .= "################ New '$hostsfn' file contents:\n" .
			"####  START '$hostsfn'\n" .
			$hosts_new .
			"####  END '$hostsfn'\n";

	$m .= "\n################ UEFI mode: " .
			(($installuefi)
				? 'UEFI'
				: 'CSM'
			) . "\n";
			####  END UEFI

	$m .= "\n################ Interface: " .
			$inp_interface_selected . "\n";
			####  END Interface

	$m .= "\n################ Interface config file\n" .
			"################ '$intfconfigfnam' START\n" .
			$intfconfigftxt . "\n" .
			"################ '$intfconfigfnam' END\n";
			####  END Interface Config

	$m .= "\n################ Command batch \$cmd START:\n" .
			$cmd . "\n" .
			"################ Command batch \$cmd END\n";
			####  END Command batch \$cmd

	$m .= "\n################ Second Command batch \$cmd2 START:\n" .
			$cmd2 . "\n" .
			"################ Second Command batch \$cmd2 END\n";
			####  END Command batch \$cmd

	$m .= "\n\n";

	my $r = yesno(
				$goinstall_backtitle,
				$goinstall_title,
				$goinstall_questionstart . $m . $goinstall_question,
				'15 72');
	return $r;
}












my $fn_dnsmasqconf = '/etc/dnsmasq.conf';
my $cf_dnsmasq =
"interface=eth1
listen-address=127.0.0.1
domain=dummy.dummy
dhcp-range=10.0.50.100,10.0.50.150,12h
";
my $_write_dnsmasqconf_ = '_write_dnsmasqconf_';

my $fn_iptablesrules = '/etc/iptables/rules.v4';
my $cf_iptablesrules =
"interface=eth1
listen-address=127.0.0.1
domain=dummy.dummy
dhcp-range=10.0.50.100,10.0.50.150,12h
";
my $_write_iptablesrules_ = '_write_iptablesrules_';

# various things could need automation after the basic install:
# - first user generation
# - swap drive/part addition
# - home data drive creation
# - home data drive addition/importing/linking in

sub do_createpostinstallbatch
{


	# TODO
	# post install, needs to be invoked when booted from newly created system

	# 1. Add swap drive
	# 2. Add home pool, do the links for it
	# 3. Import /etc/hosts

	$cmd3 .= "$_write_etcchosts_\n";

	$cmd3 .= "apt install firmware-misc-nonfree\n";

	# 4. Turn off graphical login, Plymouth garbage etc
	# see https://www.baeldung.com/linux/boot-linux-command-line-mode
	my $etcsysctldlocalconf = '';
	my $inits = `cat /proc/1/comm`;
	if ($inits eq 'systemd') {

		$cmd3 .= "systemctl set-default multi-user.target\n";

		$cmd3 .= "systemctl disable zfs-mount.service\n";



# 		https://kb.cmo.de/wissensdatenbank/linux-problem-task-blocked-for-more-than-120-seconds/
# 		$cmd3 .= "echo 0 > /proc/sys/kernel/hung_task_timeout_secs"
# 		$cmd3 .= "echo 0 > /proc/sys/kernel/hung_task_timeout_secs"

		# set up /etc/sysctl.d/local.conf
		$etcsysctldlocalconf .=
			  "vm.dirty_ratio=0\n"
			. "vm.dirty_background_ratio=0\n"
			;
# 		$cmd3 .= "sysctl -w vm.dirty_ratio=0\n";

# It is recommended to make the swapfile at least half the size of the RAM, but it can be larger if desired. After creating the swapfile, the next step is to prevent the kernel from utilizing it for swapping. Execute the following command to achieve this:

		$etcsysctldlocalconf .= "vm.swappiness=1\n";

	}

# Now generate a file named local.conf within the /etc/sysctl.d directory and incorporate the kernel variable in that location to ensure its persistence:
# temporarily store in $etcsysctldlocalconffntmp ?? TODO

	if ($etcsysctldlocalconf ne '') {
		die if (write_a_file($etcsysctldlocalconffn, \$etcsysctldlocalconf));
	}

# 	# if onboard mga cannot be deactivated, blacklist it
# 	my $blmod_fn = '/etc/modprobe.d/blacklist';
# 	my $blmod_tx = "blacklist mga\n";
#
# # 	$cmd3 .= "apt install xserver-xorg-video-mga\n";
	$cmd3 .= "apt install xserver-xorg-video-all\n";
#
# 	$cmd3 .= "apt install clinfo vulkaninfo\n";

	$cmd3 .= "apt install --yes fvwm3\n";




	# 	To make cupsd work, deactivate apparmor
	$cmd3 .= "apt install --yes apparmor-utils\n";
	$cmd3 .= "aa-complain cupsd\n";

	# 5. Additional installs+configurations

# https://forums.raspberrypi.com/viewtopic.php?t=47516

# rm -rf /var/cache/man/hr/index.db

	# part of do_queries repeated begin




	# TODO
	# make sure in /etc/systremd/system/zfs-import-target.wants the file zfs-import-cache.service is removed
	# in its place maybe add a file simiolaar to zfs-import-bpool.service



	getdrivesinfo();
	# make a dialog for selection
	my @driveseq;
	foreach (sort keys %$$availdrives) {
print "drive '$_'\n";
		push @driveseq, $_;
	}

	do {
		getcheckform (
			$$availdrives,
			\@driveseq,
			"$zfsonrootinst_backtitleheader: Target drives",
			'Target drives selection',
			'Choose the target drives on which you want to install.\nNote:\nInternally disk-by-id will be used.',
			'15 80 8',
			\%selecteddrives,
			);

			# TODO maybe there should be a notification instead of just
			# repeating questionnaire if the user deselects all
	} while ( not scalar keys %selecteddrives);

	# set the chosen drive(s)
	foreach (keys %selecteddrives) {
		my $wwnid = getdrivewwnid($_);
		push @drives, $wwnid;
		$drives_byidtosd{$wwnid} = $_;
	}

	# Check
	die("No drives selected!\n") if (not scalar @drives);

	# part of do_queries repeated end



	my $theuserdrives = '';

	# modified/enhanced (devpath) part of do_createbatch repeated begin

	my $diskcount = 0;
	foreach (@drives) {
		my $DISK = $_;
		$diskcount++;
		# For flash-based storage, if the disk was previously used,
		# you may wish to do a full-disk discard (TRIM/UNMAP),
		# which can improve performance:

		# check whether this is flash stg
		my $dr = $drives_byidtosd{$DISK};
		my $devpath = "/dev/$diskbyid$DISK";
		$theuserdrives .= ' ' . $devpath;
		if ($diskcount == 2) {
			$theuserdrives = ' mirror ' . $theuserdrives;
		}
		my $isflashtmp = `cat /sys/block/$dr/queue/rotational`;
		if (index($isflashtmp, '0') != -1) {
			$cmd3 .= "[0 1]blkdiscard -f $devpath\n";
		}

		# Clear the partition table:
		$cmd3 .= "[0 2]sgdisk --zap-all $devpath\n";

		# Check for message:
		# If you get a message about the kernel still using the
		# old partition table, reboot and start over
		# (except that you can skip this step).
		# TODO to be sure, check if this does give a nonzero return code!

# 		$salign = "-a$sgdisk_align ";
		my $salign = '';
		$cmd3 .= "sgdisk $salign-n1:0:0 -t1:BF00 $devpath\n";
		$cmd3 .= "partprobe $devpath\n";
# 		# ZFS will complain if the parts still contain metadata
# 		# so lets delete first 1000K
# 		$cmd .= "dd if=/dev/zero of=/dev/disk/by-id/$DISK-part3 count=1 bs=1000K\n";
# 		$cmd .= "dd if=/dev/zero of=/dev/disk/by-id/$DISK-part4 count=1 bs=1000K\n";
	}

	# part of do_createbatch repeated end


	# 	user zpool creation
	my $userpool = $my_hostname . 'pool';

	my $crtuserzpool = "zpool create" .
		$forcezpoolcreate .
		" -o ashift=12" .
		" -o autotrim=on" .
# 		" -o compatibility=grub2" .
# 		" -o cachefile=/etc/zfs/zpool.cache" .
# 		" -o cachefile=none" .
		" -O devices=off" .
		" -O acltype=posixacl" .
		" -O xattr=sa" .
		" -O compression=lz4" .
		" -O normalization=formD" .
		" -O relatime=on" .
# 		" -O canmount=off" .
# 		" -O mountpoint=/boot" .
		" -R $mntprefix" .
		" $userpool$theuserdrives\n";
	$crtuserzpool .= "zpool set cachefile=none $userpool\n";

	# now create the incorporated smaller pools, for ensuring backup media compatibility
	$crtuserzpool .= "mkdir $userpool/home\n";
	$crtuserzpool .= "zfs create $userpool/core880G\n";
	$crtuserzpool .= "zfs set quota=880G $userpool/core880G\n";
	$crtuserzpool .= "zfs create $userpool/core880G/core220G\n";
	$crtuserzpool .= "zfs set quota=220G $userpool/core880G/core220G\n";
	$crtuserzpool .= "zfs create $userpool/core880G/core220G/essential4G\n";
	$crtuserzpool .= "zfs set quota=4G $userpool/core880G/core220G/essential4G\n";
# 	$crtuserzpool .= "mkdir $userpool/core880G/core220G/essential4G/home\n";
# 	$crtuserzpool .= "zfs create $userpool/core880G/core220G/essential4G/essential550M\n";
# 	$crtuserzpool .= "zfs set quota=4G $userpool/core880G/core220G/essential550M\n";
# 	$crtuserzpool .= "mkdir $userpool/core880G/core220G/essential550M/home\n";


	$cmd3 .= $crtuserzpool;

	$cmd3 .= "cd /\n";


# 	Create a user account:
#
# Replace YOUR_USERNAME with your desired username:
#
# username=YOUR_USERNAME
#
# zfs create rpool/home/$username
# 	$cmd3 .= "adduser\n";
# adduser $username
#
# cp -a /etc/skel/. /home/$username
# chown -R $username:$username /home/$username
# usermod -a -G audio,cdrom,dip,floppy,netdev,plugdev,sudo,video $username

}



sub do_savebatchandconfigonlive
{
# 	die if (write_a_file("$mountpref/$hostnamefn", \$hostname_new));
# 	die if (write_a_file("$mountpref/$hostsfn", \$hosts_new));
# 	die if (write_a_file("$mountpref/$aptsourceslistfn", $aptsourceslistr));
# 	die if (write_a_file("$intfconfigfnam", \$intfconfigftxt));
	if (not $os_ubuntu) {
		if (write_a_file($intfconfigfnam, \$intfconfigftxt)) {
			die("do_savebatchandconfig(): write_a_file('$intfconfigfnam', intfconfigtxt) FAILED\n");
		}
	}
# 	die if (write_a_file("$hostnamefn", \$hostname_new));
	if (write_a_file($hostnamefn, \$hostname_new)) {
		die("do_savebatchandconfig(): write_a_file('$hostnamefn', hostname_new) FAILED\n");
	}
# 	die if (write_a_file("$hostsfn", \$hosts_new));
	if (write_a_file($hostsfn, \$hosts_new)) {
		die("do_savebatchandconfig(): write_a_file('$hostsfn', hosts_new) FAILED\n");
	}
# 	die if (write_a_file("$aptsourceslistfn", $aptsourceslistr));
	if (write_a_file($aptsourceslistfn, $aptsourceslist_new)) {
		die("do_savebatchandconfig(): write_a_file('$aptsourceslistfn', aptsourceslistr) FAILED\n");
	}
# 	die if (write_a_file("$fn_blacklist", $blacklistfiletxt));
	if (write_a_file($fn_blacklist, \$blacklistfiletxt)) {
		die("do_savebatchandconfig(): write_a_file('$fn_blacklist', blacklistfiletxt) FAILED\n");
	}

	if (write_a_file( $etcdefaultgrubfnpath_tmp, \$etcdefaultgrub)) {
# 		die("do_savebatchandconfig(): write_a_file('/etc/default/grub', $etcdefaultgrub) FAILED\n");
		die("do_savebatchandconfig(): write_a_file($etcdefaultgrubfnpath_tmp, etcdefaultgrub) FAILED\n");
	}
}


# sub do_savebatchandconfig
# {
# # 	die if (write_a_file("$mountpref/$hostnamefn", \$hostname_new));
# # 	die if (write_a_file("$mountpref/$hostsfn", \$hosts_new));
# # 	die if (write_a_file("$mountpref/$aptsourceslistfn", $aptsourceslistr));
# # 	die if (write_a_file("$intfconfigfnam", \$intfconfigftxt));
# 	if (write_a_file("$intfconfigfnam", \$intfconfigftxt)) {
# 		die("do_savebatchandconfig(): write_a_file('$intfconfigfnam', intfconfigtxt) FAILED\n");
# 	}
# # 	die if (write_a_file("$hostnamefn", \$hostname_new));
# 	if (write_a_file("$mntprefix/$hostnamefn", \$hostname_new)) {
# 		die("do_savebatchandconfig(): write_a_file('$mntprefix/$hostnamefn', hostname_new) FAILED\n");
# 	}
# # 	die if (write_a_file("$hostsfn", \$hosts_new));
# 	if (write_a_file("$mntprefix/$hostsfn", \$hosts_new)) {
# 		die("do_savebatchandconfig(): write_a_file('$mntprefix/$hostsfn', hosts_new) FAILED\n");
# 	}
# # 	die if (write_a_file("$aptsourceslistfn", $aptsourceslistr));
# 	if (write_a_file("$mntprefix/$aptsourceslistfn", $aptsourceslist_new)) {
# 		die("do_savebatchandconfig(): write_a_file('$mntprefix/$aptsourceslistfn', aptsourceslistr) FAILED\n");
# 	}
# # 	die if (write_a_file("$fn_blacklist", $blacklistfiletxt));
# 	if (write_a_file("$mntprefix/$fn_blacklist", \$blacklistfiletxt)) {
# 		die("do_savebatchandconfig(): write_a_file('$mntprefix/$fn_blacklist', blacklistfiletxt) FAILED\n");
# 	}
# }


sub do_execute
{
	executer( $cmd);
}

sub do_appendtofstab
{
	return append_a_file( $file_etc_fstab, \$appendtofstab);
}

sub do_writeintfconfig
{
	return write_a_file( $intfconfigfnam, \$intfconfigftxt);
}

sub do_writefile_import_bpool_service
{
	my $filecontents_import_bpool_service =
'[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none ' . $bootpool . '

[Install]
WantedBy=zfs-import.target

';
# '[Unit]
# DefaultDependencies=no
# Before=zfs-import-scan.service
# Before=zfs-import-cache.service
#
# [Service]
# Type=oneshot
# RemainAfterExit=yes
# ExecStart=/sbin/zpool import -N -o cachefile=none ' . $bootpool . '
# # Work-around to preserve zpool cache:
# ExecStartPre=-/bin/mv /etc/zfs/zpool.cache /etc/zfs/preboot_zpool.cache
# ExecStartPost=-/bin/mv /etc/zfs/preboot_zpool.cache /etc/zfs/zpool.cache
#
# [Install]
# WantedBy=zfs-import.target
#
# ';

	return (write_a_file($file_import_bpool_service, \$filecontents_import_bpool_service));
}

sub do_preparesecondstage
{
# 	die if write_a_file("$mntprefix/$file_secondstage_bootstrap" , \$boot2);
	die if write_a_file($file_firststage , \$cmd);

	die if write_a_file($file_secondstage_bootstrap , \$boot2);
	`chmod u+x $file_secondstage_bootstrap`;
# 	die if write_a_file('/mnt/' . $file_secondstage_bootstrap, \$boot2);
# 	`chmod u+x '/mnt/' . $file_secondstage_bootstrap`;
# 	die if write_a_file("$mntprefix/$file_secondstage" , \$cmd2);
	die if write_a_file($file_secondstage , \$cmd2);
}

sub do_executesecondstage
{
	$secondstage = 1;

	# set up some variables again that were questioned in stage 1
	# for zedcache path we need hostname
	# as it is not yet set up fully, read it from /etc/hostname
	my $hnr = read_a_file('/etc/hostname');
	die if not defined $hnr;
	my ($hname) = $$hnr =~ /^([a-z0-9]+)/;

	$bootpool = $hname . 'boot';
	$rootpool = $hname . 'root';

# 	$zedcachebpool = "$zedcachedir/$bootpool";
# 	$zedcacherpool = "$zedcachedir/$rootpool";
# TODO thirdstage
# 	do_createpostinstallbatch();

	my $stg2 = read_a_file($file_secondstage);
	if (not defined $stg2) {
		die("Could not read file $file_secondstage, aborted\n");
	}
print "Read $file_secondstage:\nSTART\n$$stg2\nEND\nExecuting it!\n";
	executer( $$stg2);
}


sub do_executethirdstage
{
# 	$thirdstage = 1;
#
# 	# set up some variables again that were questioned in stage 1
# 	# for zedcache path we need hostname
# 	# as it is not yet set up fully, read it from /etc/hostname
# 	my $hnr = read_a_file('/etc/hostname');
# 	die if not defined $hnr;
# 	my ($hname) = $$hnr =~ /^([a-z0-9]+)/;
#
# 	$bootpool = $hname . 'boot';
# 	$rootpool = $hname . 'root';
#
# # 	$zedcachebpool = "$zedcachedir/$bootpool";
# # 	$zedcacherpool = "$zedcachedir/$rootpool";
#
#
#
# 	my $stg3 = read_a_file($file_thirdstage);
# 	if (not defined $stg3) {
# 		die("Could not read file $file_thirdstage, aborted\n");
# 	}
# print "Read $file_secondstage:\nSTART\n$$stg2\nEND\nExecuting it!\n";
# 	executer( $$stg2);
}


sub messag
{
	my $m = shift;

	my $l = '#' x 40 . "\n";
	my $lns = $l x 2;

	return (
		$lns .
		'#############  ' . $m . "\n" .
		$lns
	);
}

sub showmsg
{
	my $m = shift;

	msgbox( "$myname",
			"Stage note",
			$m,
			'10 70');
}

############################################################
####################    main part: main block
############################################################

my $opt_secondstage;
my $opt_thirdstage;

GetOptions(
# 	"help|h|?"			=> \&opt_show_help,
# 	"version"			=> \&opt_show_version,
	"2"					=> \$opt_secondstage,
	"3"					=> \$opt_thirdstage,
# 	"i|install"         => \$opt_install,
# 	"x|installxorg"     => \$opt_installxorg,
# 	"c|configx"         => \$opt_configx,
);


if (defined $opt_secondstage) {
	showmsg(messag('do_executesecondstage()'));
	do_executesecondstage();
} elsif (defined $opt_thirdstage) {
	showmsg(messag('do_executethirdstage()'));
	do_executethirdstage();
} else {
	# normal first run
	if (not isanywhere('dialog')) {
	showmsg(messag('normal first run'));
		# not installed on debian by default
		system('apt-get update');
		system('apt-get install dialog');
	}

# exit 0;
	showmsg(messag('do_queries()'));
	do_queries();
	showmsg(messag('do_createbatch()'));
	do_createbatch();
	showmsg(messag('do_showbatchandconfig()'));
	my $r = do_showbatchandconfig();
	if ($r) {
		showmsg(messag('do_savebatchandconfigonlive()'));
		do_savebatchandconfigonlive();
		showmsg(messag('do_preparesecondstage()'));
		do_preparesecondstage();
		showmsg(messag('do_execute()'));
		do_execute();
		# TODO give notice to reboot and maybe to import rpool
		# at initramfs:
		#     zpool import -f rpool
		#     exit
		# and then to login as root and
		# launch third stage
		#     ./bookworm_zfsinst -3

		showmsg('FINISHED');

print
"To do now:
- reboot
- if initramfs stops, import rpool manually:
      zpool import -f rpool
      exit
- boot, and then login as root and launch second install stage
		$myname
	blah blah

"
	}
}
