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

my $DEBUG = 1;

# Load Players
open (my $fh_players, "<", "Players.txt") or die "$!";
my @players = <$fh_players>;
print STDERR "Loaded " . scalar @players . " Players.\n" if $DEBUG;

# Add Bye if needed
if (scalar @players % 2 == 1 ){
	print STDERR "Adding BYE Player.\n" if $DEBUG;
	push @players, "BYE";
}

# Generate Pairings


