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
use Getopt::Std;
use Perl6::Form;
my $DEBUG = 0;
# Set file name to work from
my %opts;
getopts('f:', \%opts);

my $data_file = $opts{'f'} . ".yml";
my $score_round;
my $player_data;
my $total_rounds;

unless ( -e $data_file ) {
	Load_Player_data();
}
else {
	$player_data = LoadFile($data_file);
	$score_round = $player_data->{META}->{score_round};
	$total_rounds = $player_data->{META}->{total_rounds};
}

my $term = Term::ReadLine->new('brand');
delete $player_data->{BYE};
delete $player_data->{META};

# Main Menu
my @menu = ('Add Score Data', 'Advance Round','Show Matchups', 'View standings', 'Save & Quit');
my $main_menu;
do {
	$main_menu = $term->get_reply (
		prompt => "Menu selection",
		choices => \@menu,
		default => $menu[4],
		print_me => "Current Round:" . ($score_round + 1) . " of $total_rounds",
		);

	for ($main_menu) {
		no warnings qw(experimental);
		Score_Data() when $_ eq $menu[0];
		Select_round() when $_ eq $menu[1];
		Show_Matchups() when $_ eq $menu[2];
		View_Standings() when $_ eq $menu[3];
	}

} while ($main_menu ne $menu[4]); 

$player_data->{'META'} = {
	score_round => $score_round,
	total_rounds => $total_rounds,
};

DumpFile($opts{f} . ".yml", $player_data);
exit 0;

sub Select_round {
	$score_round++;
	Make_Pairing();
}

sub sum{
	my @array = @_;
	my $total = 0;
	for (@array) {
		$total += $_ if defined $_;
	}
	return $total;
}

sub Make_Pairing {
	my @Players = sort {sum(@{$player_data->{$b}->{prestige}}) <=> sum(@{$player_data->{$a}->{prestige}})} keys $player_data;
	for my $i (0 .. $#Players) {
		my $player = $Players[$i];
		print "player: $player\n";
		unless (defined $player_data->{$player}->{opponents}[$score_round]){
			my $opponent = $i +1;
			if ( defined $Players[$opponent] ) {
				my $match = 1;
				do {
				print "Proposed Opponent: " . $Players[$opponent] . "\n";
					for (@{$player_data->{$player}->{opponents}}) {
						print "Previous opponent: $_\n";
						if ($_ eq $Players[$opponent]) {
							$match = 0;
						}
					}
					$opponent++;
					sleep 1;
				} while ($match == 0);
				push @{$player_data->{$player}->{opponents}}, $Players[$opponent];
				push @{$player_data->{$Players[$opponent]}->{opponents}}, $player;
			}
			else {
				push @{$player_data->{$player}->{opponents}}, 'BYE';
				$player_data->{$player}->{prestige}[$score_round] = 5;
			}
		}
	}
}

sub Show_Matchups {

	my $spacer = 0;
	for (keys $player_data) {
		$spacer = length if length > $spacer;
	}
	$spacer += 5;

	for (sort keys $player_data) {
		print sprintf( "%-${spacer}s %-5s %-${spacer}s \n", $_, '->' ,$player_data->{$_}->{opponents}[$score_round]);
	}
}

sub View_Standings {
	my @temp = map { [sum(@{$player_data->{$_}->{prestige}}), $_]} keys $player_data;
	for (@temp) {
		my $Sos = 0;
		my $name = $_->[1];
		for (@{$player_data->{$name}->{opponents}}) {
			$Sos += sum(@{$player_data->{$_}->{prestige}}) unless $_ eq 'BYE';
		}
		push $_, $Sos;
	}
	my @Players = map { $_->[1] } sort { $b->[0] <=> $a->[0] || $b->[2] <=> $a->[2] } @temp;
		print      "  Player Name                              Prestige        SoS\n";
	my $index = 0;
	for my $player (@Players) {
		my $prestige = 0;
		my $Sos = 0;
		my $n = ++$index . '.';

		$prestige = sum(@{$player_data->{$player}->{prestige}});

		for (@{$player_data->{$player}->{opponents}}) {
			$Sos += sum(@{$player_data->{$_}->{prestige}}) unless $_ eq 'BYE';
		}

		print form "  {>} {<<<<<<<<<<<<<<<<<<<<}    {>>>>>>>>}    {>>>>>>>>}",
		              $n, $player,                  $prestige,    $Sos;
	}
}

sub Load_Player_data {
	# Load Players
	open (my $fh_players, "<", $opts{'f'} . ".txt") or die "$!";
	chomp( my @players = <$fh_players>);
	print STDERR "DEBUG: Loaded " . scalar @players . " Players.\n" if $DEBUG;

	# Add Bye if needed
	if (scalar @players % 2 == 1 ){
		print STDERR "DEBUG: Adding BYE Player.\n" if $DEBUG;
		push @players, "BYE";
	}

	# Determine number of rounds 
	my $rounds;
	for (scalar @players) {
		no warnings qw(experimental);
		$rounds = 6 when $_ >= 33;
		$rounds = 5 when $_ >= 17;
		$rounds = 4 when $_ >= 9;
		$rounds = 3 when $_ >= 5;
		$rounds = 2 when $_ >= 2;
	}
		print STDERR "DEBUG:" . $rounds . " rounds needed.\n" if $DEBUG;

	# Generate Pairings at random
	do {
		my $player1 =  splice @players, int(rand(scalar @players)), 1;
		my $player2 =  splice @players, int(rand(scalar @players)), 1;

		$player_data->{$player1} = { 
						opponents => [ $player2 ],
						prestige => [(undef,) x $rounds],
					};

		$player_data->{$player2} = { 
						opponents => [ $player1 ],
						prestige => [(undef,) x $rounds],
					};

		if ($player2 eq 'BYE') {
			print STDERR "DEBUG: adding prestige for BYE player opponent: $player1.\n" if $DEBUG;
			$player_data->{$player1}->{prestige}[0] = 4;
		}
		elsif ($player1 eq 'BYE') {
			print STDERR "DEBUG: adding prestige for BYE player opponent: $player2.\n" if $DEBUG;
			$player_data->{$player2}->{prestige}[0] = 4;
		}

		print STDERR "DEBUG:" . scalar @players . " remaining.\n" if $DEBUG;
	} while (scalar @players gt 0);

	$score_round = 0;
	$total_rounds = $rounds;

	$player_data->{'META'} = {
		score_round => 0,
		total_rounds => $rounds,
	} 
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
	print "Scoring game vs $Player2\n";

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
