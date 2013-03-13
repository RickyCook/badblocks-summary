#!/usr/bin/perl -w
use strict;
use warnings;

use List::Util qw(max min);
use List::MoreUtils qw(none);

use constant SUMMARY_EVERY => 500000;

sub gap_group {
	my ($x) = @_;
	return 0 if($x < 1);
	return int(log($x) / log(10))
}
sub has {
	my ($block, $list) = @_;

	#
	# Check for unique
	#
	foreach my $i (@$list) {
		if(ref($i) eq '') {
			return 1 if $block == $i;
		} else {
			my ($min, $max) = @$i;
			return 1 if
				   $block >= $min
				&& $block <= $max;
		}
	}

	#
	# Block is unique, add to set
	#
	if (@$list) {
		my $p = $list->[-1];

		my $range_min = $p;
		my $range_max = $p;
		if (ref($p) eq 'ARRAY') {
			($range_min, $range_max) = @$p;
		} elsif (ref($p) ne '') {
			die('Unexpected type: ' . ref($p));
		}

		if ($block - $range_max == 1) {
			$list->[-1] = [$range_min, $block];
		} else {
			push @$list, $block;
		}
	} else {
		@$list = ($block);
	}

	return 0;
}

if (!@ARGV) {
	require File::Basename; import File::Basename;
	my $name = basename($0);
	my $se = SUMMARY_EVERY;
	print <<END;

Parses a file containing a block number per line (default output of the badblocks command)
and gathers information such as contiguous sections and number of unique bad blocks.

Usage: $name filename | --test
  filename  the location of the file to parse
    --test  run unit tests

- Will output some summary information every $se unique blocks.
- Note that if the input file is unordered, only the unique block count can be trusted. In
this case, gap grouping information is likely incorrect.

END
	exit 1;
}

if ($ARGV[0] ne '--test') {
	my $fn = $ARGV[0];

	my $previous = 0;

	my $list = [];
	my %gap_groups = ();

	my $unique = 0;
	my $dupes = 0;

	open FH, '<', $fn or die $!;

	print "Getting unique values from $fn\n";
	while (my $line = <FH>) {
		# Make sure using an int all the time
		$line = int($line);

		if (has($line, $list)) {
			$dupes++;
		} else {
			$unique++;

			if ($line > $previous) {
				my $gap = $line - $previous;
				if ($gap > 1) {
					my $group = gap_group($gap);
					$gap_groups{$group} ||= 0;
					$gap_groups{$group}++;
				}
			}

			if ($unique % SUMMARY_EVERY == 0) {
				print "$unique bad blocks ($dupes duplicates)\n";
				print "Gaps:\n";
				print join "\n", map {
					"10^$_ - 10^" . ($_+1) . ': ' . $gap_groups{$_}
				} sort(keys %gap_groups);
				print "\n";
			}
		}

		$previous = $line;
	}

	printf "Found %s unique values\n", scalar $unique;
} else {
	require Test::More;
	import Test::More tests => 43;
	
	my $t_prefix = 'gap_group:';

	my %gap_group_data = (
		0   => 0,
		1   => 0,
		10  => 1,
		100 => 2,
		493 => 2,
	);
	foreach my $x (keys %gap_group_data) {
		is(gap_group($x), $gap_group_data{$x}, "$t_prefix $x has group $gap_group_data{$x}");
	}

	$t_prefix = 'has:';
	my $st_prefix = "$t_prefix check for '10' when initial list contains nothing:";
	my $list = [];
	ok(
		!has(10, $list),
		"$st_prefix value is unique"
	);
	is_deeply(
		$list,
		[ 10 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for '10' when initial list contains only '10':";
	$list = [ 10 ];
	ok(
		has(10, $list),
		"$st_prefix value is not unique"
	);
	is_deeply(
		$list,
		[ 10 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for '0' when initial list contains nothing:";
	$list = [];
	ok(
		!has(0, $list),
		"$st_prefix value is unique"
	);
	is_deeply(
		$list,
		[ 0 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for '0' when initial list contains only '0':";
	$list = [ 0 ];
	ok(
		has(0, $list),
		"$st_prefix value is not unique"
	);
	is_deeply(
		$list,
		[ 0 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for '100' (unique) when initial list contains multiple values:";
	$list = [ -6, 5, 30 ];
	ok(
		!has(100, $list),
		"$st_prefix value is unique"
	);
	is_deeply(
		$list,
		[ -6, 5, 30, 100 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for '100' (not unique) when initial list contains multiple values:";
	$list = [ -6, 5, 30, 100 ];
	ok(
		has(100, $list),
		"$st_prefix value is not unique"
	);
	is_deeply(
		$list,
		[ -6, 5, 30, 100 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for '5' (unique) when initial list contains multiple unordered values:";
	$list = [ -6, 100, 30 ];
	ok(
		!has(5, $list),
		"$st_prefix value is not unique"
	);
	is_deeply(
		$list,
		[ -6, 100, 30, 5 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for '5' (not unique) when initial list contains multiple unordered values:";
	$list = [ -6, 100, 5, 30 ];
	ok(
		has(5, $list),
		"$st_prefix value is not unique"
	);
	is_deeply(
		$list,
		[ -6, 100, 5, 30 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check for a consecutive range of unique values:";
	$list = [];
	ok(
		!has(3, $list),
		"$st_prefix 1/3 value is unique"
	);
	ok(
		!has(4, $list),
		"$st_prefix 2/3 value is unique"
	);
	ok(
		!has(5, $list),
		"$st_prefix 3/3 value is unique"
	);
	is_deeply(
		$list,
		[ [ 3, 5 ] ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix check values against a range:";
	$list = [ [ 3, 5 ] ];
	ok (
		has(3, $list),
		"$st_prefix value at start of range is not unique"
	);
	ok (
		has(4, $list),
		"$st_prefix value at in range is not unique"
	);
	ok (
		has(5, $list),
		"$st_prefix value at end of range is not unique"
	);
	ok (
		!has(6, $list),
		"$st_prefix new value at end of range is unique"
	);
	ok (
		!has(8, $list),
		"$st_prefix new non-cosecutive value is unique"
	);
	is_deeply(
		$list,
		[ [ 3, 6 ], 8 ],
		"$st_prefix complete list is correct"
	);

	$st_prefix = "$t_prefix complex set with multiple ranges and individual values:";
	$list = [ 1, [ 20, 30 ], [ 35, 40 ], 45, 48 ];
	ok (has(1, $list), "$st_prefix value is not unique");
	ok (has(25, $list), "$st_prefix value is not unique");
	ok (has(35, $list), "$st_prefix value is not unique");
	ok (has(45, $list), "$st_prefix value is not unique");
	ok (has(48, $list), "$st_prefix value is not unique");
	ok (!has(0, $list), "$st_prefix value is unique");
	ok (!has(2, $list), "$st_prefix value is unique");
	ok (!has(32, $list), "$st_prefix value is unique");
	ok (!has(33, $list), "$st_prefix value is unique");
	ok (!has(42, $list), "$st_prefix value is unique");
	ok (!has(50, $list), "$st_prefix value is unique");
	is_deeply(
		$list,
		[ 1, [ 20, 30 ], [ 35, 40 ], 45, 48, 0, 2, [ 32, 33 ], 42, 50 ],
		"$st_prefix complete list is correct"
	);

}