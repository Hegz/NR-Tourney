#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: score.pl
#
#        USAGE: ./score.pl  
#
#  DESCRIPTION: Score players at the end of the round
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Adam Fairbrother (Hegz), afairbrother@sd73.bc.ca
# ORGANIZATION: School District No. 73
#      VERSION: 1.0
#      CREATED: 14-07-24 09:35:38 AM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use v5.14;
use YAML::XS qw(DumpFile LoadFile);
use Term::UI;
use Term::ReadLine;

my $data_file = "playerdata.yml";
my $score_round = 0;
my $term = Term::ReadLine->new('brand');

my $player_data = LoadFile($data_file);
delete $player_data->{BYE};

my @score_options = ('Won both games', 'Won and Lost', 'Win and Timeout', 'Lost and Timeout', 'Timeout first game', 'Lost both games');

# Main Menu
my @menu = ('Add Score Data', 'Set current round','Ready next round', 'View standings', 'Save & Quit');
my $main_menu;
do {
	$main_menu = $term->get_reply (
		prompt => "Menu selection",
		choices => \@menu,
		default => $menu[4],
		);

	for ($main_menu) {
		no warnings qw(experimental);
		Score_Data() when $_ eq $menu[0];
		Select_round() when $_ eq $menu[1];
	}


} while ($main_menu ne $menu[4]); 
DumpFile("playerdata.yml", $player_data);
exit 0;

sub Select_round {
	$score_round = $term->get_reply (
		prompt => 'Set the current Round',
		choices => [qw(1 2 3 4 5 6)],
		default => $score_round + 1,
	);
	$score_round -= 1;
	}

sub Score_Data {
	# Filter out players with score data for this round
	my @sorted_players;  ;
	for (sort keys %$player_data){
		if ($player_data->{$_}->{prestige}[$score_round] <= 0) {
			push @sorted_players, $_;
		}
	}

	# prompt for player
	my $Player = $term->get_reply (
		prompt => 'Score which player?',
		choices => \@sorted_players,
	);

	# Prompt for Score
	my $score = $term->get_reply (
		prompt => 'Match Result',
		choices => \@score_options,
	);

	for ($score) {
		no warnings qw(experimental);
		when ($score eq $score_options[0]) {
			$player_data->{$Player}->{prestige}[$score_round] = 4;
			$player_data->{$player_data->{$Player}->{opponents}[$score_round]}->{prestige}[$score_round] = 0;
		}
		when ($score eq $score_options[1]) {
			$player_data->{$Player}->{prestige}[$score_round] = 2;
			$player_data->{$player_data->{$Player}->{opponents}[$score_round]}->{prestige}[$score_round] = 2;
		}
		when ($score eq $score_options[2]) {
			$player_data->{$Player}->{prestige}[$score_round] = 3;
			$player_data->{$player_data->{$Player}->{opponents}[$score_round]}->{prestige}[$score_round] = 1;
		}
		when ($score eq $score_options[3]) {
			$player_data->{$Player}->{prestige}[$score_round] = 1;
			$player_data->{$player_data->{$Player}->{opponents}[$score_round]}->{prestige}[$score_round] = 3;
		}
		when ($score eq $score_options[4]) {
			$player_data->{$Player}->{prestige}[$score_round] = 1;
			$player_data->{$player_data->{$Player}->{opponents}[$score_round]}->{prestige}[$score_round] = 1;
		}
		when ($score eq $score_options[5]) {
			$player_data->{$Player}->{prestige}[$score_round] = 0;
			$player_data->{$player_data->{$Player}->{opponents}[$score_round]}->{prestige}[$score_round] = 4;
		}
	}
}


exit 0;
# Print player with no score data for this round

# Select a player


# @score_options = ('Won both games', 'Won and Lost', 'Win and Timeout', 'Lost and Timeout', 'Timeout first game', 'Lost both games');
# Select Score Options
# 4 Points -- 2 Wins
# 2 Points -- 1 Win & 1 Loss
# 3 Points -- 1 Win & timeout
# 1 Point  -- 1 Loss & timeout
# 1 Point  -- 2 timeouts
# 0 points -- 2 Loses
