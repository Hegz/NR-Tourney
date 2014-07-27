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
		unless (defined $player_data->{$_}->{prestige}[$score_round]) {
			push @sorted_players, $_;
		}
	}

	if ( scalar @sorted_players  == 0 ){
		print "No More players to score for round " . ($score_round + 1) . ".\n";
		return;
	}

	# prompt for player
	my $Player = $term->get_reply (
		prompt => 'Score which player?',
		choices => \@sorted_players,
	);
	my $Player2 = $player_data->{$Player}->{opponents}[$score_round];

	print "Scoring game vs " . $Player2 . "\n"; 

# valid scoring options as of Aug, 2014
	my @score_options = (
		'Won both games', 
		'Won and Lost', 
		'Won Game 1 and Timeout w/ AP lead', 
		'Won Game 1 and Timeout w/ AP Tie', 
		'Won Game 1 and Timeout w/ AP Deficit', 
		'Lost Game 1 and Timeout w/ AP Lead', 
		'Lost Game 1 and Timeout w/ AP Tie', 
		'Lost Game 1 and Timeout w/ AP Deficit', 
		'Timeout first game w/ AP Lead', 
		'Timeout first game w/ AP Tie', 
		'Timeout first game w/ AP Deficit', 
		'Lost both games'
	);

	# Prompt for Score
	my $score = $term->get_reply (
		prompt => 'Match Result',
		choices => \@score_options,
	);
	


	for ($score) {
		no warnings qw(experimental);
		when ($score eq $score_options[0]) {
		# Won both Games
			$player_data->{$Player}->{prestige}[$score_round] = 4;
			$player_data->{$Player2}->{prestige}[$score_round] = 0;
		}
		when ($score eq $score_options[1]) {
		# Split games
			$player_data->{$Player}->{prestige}[$score_round] = 2;
			$player_data->{$Player2}->{prestige}[$score_round] = 2;
		}
		when ($score eq $score_options[2]) {
		# Won Game 1 and timeout Game 2 with agenda point lead.
			$player_data->{$Player}->{prestige}[$score_round] = 3;
			$player_data->{$Player2}->{prestige}[$score_round] = 0;
		}
		when ($score eq $score_options[3]) {
		# Won Game 1 and timeout Game 2 with agenda point Tie
			$player_data->{$Player}->{prestige}[$score_round] = 3;
			$player_data->{$Player2}->{prestige}[$score_round] = 1;
		}
		when ($score eq $score_options[4]) {
		# Won Game 1 and timeout Game 2 with agenda point deficit
			$player_data->{$Player}->{prestige}[$score_round] = 2;
			$player_data->{$Player2}->{prestige}[$score_round] = 1;
		}
		when ($score eq $score_options[5]) {
		# Lost game and timeout with Agenda point lead
			$player_data->{$Player}->{prestige}[$score_round] = 1;
			$player_data->{$Player2}->{prestige}[$score_round] = 2;
		}
		when ($score eq $score_options[6]) {
		# Lost game and timeout with Agenda point Tie
			$player_data->{$Player}->{prestige}[$score_round] = 1;
			$player_data->{$Player2}->{prestige}[$score_round] = 3;
		}
		when ($score eq $score_options[7]) {
		# Lost Game 1 and timeout Game 2 with agenda point deficit
			$player_data->{$Player}->{prestige}[$score_round] = 0;
			$player_data->{$Player2}->{prestige}[$score_round] = 3;
		}
		when ($score eq $score_options[8]) {
		# Timeout Game 1 with agenda point lead.
			$player_data->{$Player}->{prestige}[$score_round] = 1;
			$player_data->{$Player2}->{prestige}[$score_round] = 0;
		}
		when ($score eq $score_options[9]) {
		# Timeout Game 1 with agenda point tie.
			$player_data->{$Player}->{prestige}[$score_round] = 1;
			$player_data->{$Player2}->{prestige}[$score_round] = 1;
		}
		when ($score eq $score_options[10]) {
		# Timeout Game 1 with agenda point deficit
			$player_data->{$Player}->{prestige}[$score_round] = 0;
			$player_data->{$Player2}->{prestige}[$score_round] = 1;
		}
		when ($score eq $score_options[11]) {
		# Lost both Games
			$player_data->{$Player}->{prestige}[$score_round] = 0;
			$player_data->{$Player2}->{prestige}[$score_round] = 4;
		}
	}
}
