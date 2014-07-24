#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: round1.pl
#
#        USAGE: ./round1.pl  
#
#  DESCRIPTION: Generate Round 1 pairings for swiss tournament
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Adam Fairbrother (Hegz), afairbrother@sd73.bc.ca
# ORGANIZATION: School District No. 73
#      VERSION: 1.0
#      CREATED: 14-07-23 04:03:04 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use v5.14;
use YAML::XS qw(DumpFile);

my $DEBUG = 0;
my $playerdata;

# Load Players
open (my $fh_players, "<", "Players.txt") or die "$!";
chomp( my @players = <$fh_players>);
print STDERR "DEBUG: Loaded " . scalar @players . " Players.\n" if $DEBUG;

# Add Bye if needed
if (scalar @players % 2 == 1 ){
	print STDERR "DEBUG: Adding BYE Player.\n" if $DEBUG;
	push @players, "BYE";
}

my $spacer = 0;
for (@players) {
	$spacer = length if length > $spacer;
}
$spacer += 10;

# Determine number of rounds 
my $rounds;
for (scalar @players) {
	no warnings qw(experimental);
	$rounds = 6 when $_ ge 33;
	$rounds = 5 when $_ ge 17;
	$rounds = 4 when $_ ge 9;
	$rounds = 3 when $_ ge 5;
	$rounds = 2 when $_ ge 2;
}
	print STDERR "DEBUG:" . $rounds . " rounds needed.\n" if $DEBUG;

# Generate Pairings at random
do {
	my $player1 =  splice @players, int(rand(scalar @players)), 1;
	my $player2 =  splice @players, int(rand(scalar @players)), 1;
	print sprintf( "%-${spacer}s %-${spacer}s \n", $player1, $player2);

	$playerdata->{$player1} = { 
					opponents => [ $player2 ],
					prestige => [(0,) x $rounds],
				};

	$playerdata->{$player2} = { 
					opponents => [ $player1 ],
					prestige => [(0,) x $rounds],
				};

	print STDERR "DEBUG:" . scalar @players . " remaining.\n" if $DEBUG;
} while (scalar @players gt 0);

DumpFile("playerdata.yml", $playerdata);
