#!perl

# Parse .po file for The Prince and the Coward game

use utf8;

sub process_inv($);
sub process_varia($);
sub process_mob($);
sub process_credits($);
sub process_talk($);
sub convert_utf($$);

use open qw/:std :utf8/;

if ($#ARGV != 1) {
	die "Usage: $0 <language-code> <file.po>";
}

my $lang = $ARGV[0];

my $fname = "";
my $idx1 = "";
my $idx2 = "";
my $seenheader = 0;

my $inmsgid = 0;
my $inmsgstr = 0;
our %data;
our %data1;

open IN, $ARGV[1];

while (<IN>) {
	chomp;

	if (/^#: ([^:]+):(\d+)$/) {
		$fname = $1;
		$idx1 = $2;

		$seenheader = 1;

		$inmsgid = $inmsgstr = 0;

		next;
	}

	if (/^msgid ""$/) {
		$inmsgid = 1;
		next;
	}

	if (/^msgstr ""$/) {
		$inmsgid = 0;
		$inmsgstr = 1;
		next;
	}

	$_ = convert_utf $lang, $_;

	if (/^msgid (.*)$/) {
		my $s = $1;

		$s =~ s/(^")|("$)//g;

		$data{$fname}{$idx1} = $s;

		$inmsgid = 0;
	}

	if (/^msgstr (.*)$/) {
		my $s = $1;

		$s =~ s/(^")|("$)//g;

		$data1{$fname}{$idx1} = $s;

		$inmsgstr = 0;
	}

	if (/^"(.*)"$/) {
		if ($inmsgid) {
			$data{$fname}{$idx1} .= $1;
		} elsif ($inmsgstr) {
			$data1{$fname}{$idx1} .= $1;
		}
	}
}

for my $f (keys %data) {
	for my $k (keys %{$data{$f}}) {
		if (not exists $data1{$f}{$k}) {
			warn "Missing msgstr $f:$k";
		}
	}
}


process_inv "invtxt.txt";
process_varia "variatxt.txt";
process_mob "mob.txt";
process_credits "credits.txt";
process_talk "talktxt.txt";

exit;

sub convert_utf($$) {
	my $lang = shift;
	my $s = shift;

	return $s;
}

sub process_inv($) {
	my $file = shift;

	open(*OUT, ">$file") or die "Cannot open file $file: $!";

	print OUT "invtxt.dat\n";

	for my $n (sort {$a<=>$b} keys $data1{'invtxt.txt'}) {
		print OUT "$n. $data1{'invtxt.txt'}{$n}\n";
	}

	close OUT;
}

sub process_varia($) {
	my $file = shift;

	open(*OUT, ">$file") or die "Cannot open file $file: $!";

	print OUT "variatxt.dat\n";

	for my $n (sort {$a<=>$b} keys $data1{'variatxt.txt'}) {
		print OUT "$n. $data1{'variatxt.txt'}{$n}\n";
	}

	close OUT;
}

sub process_mob($) {
	my $file = shift;

	open(*OUT, ">$file") or die "Cannot open file $file: $!";

	print OUT "mob.lst\n";

	my $pn = 0;

	for my $n (sort {$a<=>$b} keys $data1{'mob.lst'}) {
		my $p1 = int($n / 1000);

		if ($p1 != $pn) {
			if ($p1 > 1) {
				for my $i (($pn+1)..$p1) {
					print OUT "$i.\n";
				}
			}
			$pn = $p1;
		}
		print OUT "$data1{'mob.lst'}{$n}\n";
	}

	for my $i (($pn+1)..61) {
		print OUT "$i.\n";
	}

	close OUT;
}

sub process_talk($) {
	my $file = shift;

	open(*OUT, ">$file") or die "Cannot open file $file: $!";

	print OUT "talktxt.dat\n";

	for my $f (sort grep /^dialog/, keys %data1) {
		$f =~ /dialog(\d+)/;
		my $dialog = $1;
		my $hasDialog = !!grep { $_ > 100 } keys $data1{$f};

		if ($hasDialog) {
			print OUT "\@DIALOGBOX_LINES:\n";
		} else {
			print OUT "\@NORMAL_LINES:\n";
		}

		my $seenDialogBox = 0;
		my $prevBox = -1;

		for my $n (sort {$a<=>$b} keys $data1{$f}) {
			my $s = $data1{$f}{$n};
			if ($n < 100) {
				while ($s =~ /^P#/) {
					print OUT "#PAUSE\n";
					$s = substr $s, 2;
				}

				if ($s =~ /^([^:]+): (.*)$/) {
					print OUT "#$1\n$2\n";
				} else {
					print OUT "$s\n";
				}
			} elsif ($n < 100000) {
				if (!$seenDialogBox) {
					print OUT "#BOX 0\n";
					$seenDialogBox = 1;
				}
				my $box = int($n/100) - 1;
				if ($box != $prevBox) {
					print OUT "#END\n\@DIALOG_BOX $box\n";
					$prevBox = $box;
				}
				$s =~ /^(\$\d+): (.*)$/;
				print OUT "$1\n$2\n";
			} else {
				if ($seenDialogBox < 2) {
					$prevBox = -1;
					$seenDialogBox = 2;
				}
				my $box = int($n/100) - 1000;
				if ($box != $prevBox) {
					print OUT "#END\n\@DIALOG_OPT $box\n";
					$prevBox = $box;
				}

				while ($s =~ /^P#/) {
					print OUT "#PAUSE\n";
					$s = substr $s, 2;
				}

				if ($s =~ /^([^:]+): (.*)$/) {
					print OUT "#$1\n";
					$s = $2;
				}
				my @l = split /#/, $s;
				print OUT "$l[0]\n" if $l[0] ne "";
				shift @l;

				for my $d (@l) {
					$d =~ s/^E/#ENABLE /;
					$d =~ s/^D/#DISABLE /;
					$d =~ s/^B/#BOX /;
					$d =~ s/^X/#EXIT /;
					$d =~ s/^F/#FLAG /;
					print OUT "$d\n";
				}
			}
		}
		print OUT "#END\n";
		if ($hasDialog) {
			print OUT "#ENDEND\n";
		}
	}

	close OUT;
}

sub process_credits($) {
	my $file = shift;

	open(*OUT, ">$file") or die "Cannot open file $file: $!";

	$now_string = gmtime;

	print OUT <<EOF;
credits.dat




GALADOR - THE PRINCE AND THE COWARD
v2.0 - ENGLISH
Built on: $now_string




#



SCENARIO

Adrian Chmielarz
Jacek Piekara



#
GRAPHICS AND ANIMATION

Andrzej Kukuta
Grzegorz Miechowski
Juliusz Gruber
Pawet Piotrowski
Andrzej Mitula
Ireneusz Konior
Pawet Miechowski

#



PROGRAMMING

Maciej Marzec




#

MUSIC

Karim Martusewicz

SOUND EFFECTS

Adam "Scorpik" Skorupa


#



ENGLISH LOCALIZATION

ShinjiGR
ScummVM Team




##
EOF

	close OUT;
}
