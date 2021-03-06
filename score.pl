#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: score.pl
#
#        USAGE: ./score.pl -f players.txt
#
#  DESCRIPTION: Tournament management script for Android: Netrunner
#
# REQUIREMENTS: Enter the players into a text file, one player per line.
#       AUTHOR: Adam Fairbrother (Hegz), adam.fairbrother@gmail.com
#      VERSION: 1.0
#===============================================================================

use strict;
use warnings;
use utf8;
no warnings qw(experimental);
use 5.14.0;
use YAML::XS qw(DumpFile LoadFile);
use Term::UI;
use Term::ReadLine;
use Perl6::Form;
use List::MoreUtils qw(firstidx);
use Scalar::Util qw(looks_like_number);

my $Players_File = $ARGV[0];
$Players_File =~ s/(.*)\..{0,3}/$1/;

my $data_file = $Players_File . ".yml";
my $score_round;
my $player_data;
my $total_rounds;

unless ( -e $data_file ) {
    Load_Player_data();
}
else {
    $player_data  = LoadFile($data_file);
    $score_round  = $player_data->{META}->{score_round};
    $total_rounds = $player_data->{META}->{total_rounds};
	for (keys $player_data) {
		unless ( defined $player_data->{$_}->{status}) {
			$player_data->{$_}->{status} = 'Active';
		}
	}
}

my $term = Term::ReadLine->new('brand');
delete $player_data->{BYE};
delete $player_data->{META};

# Main Menu
my @menu = (
    'Add Score Data',
    'Advance Round',
    'Show Matchups',
    'View standings',
	'Administrator Override',
    'Save & Quit'
);
my $main_menu;
do {
    $main_menu = $term->get_reply(
        prompt   => "Menu selection",
        choices  => \@menu,
        default  => $menu[-1],
        print_me => "\nCurrent Round:"
          . ( $score_round + 1 )
          . " of $total_rounds\n",
    );

    for ($main_menu) {
        no warnings qw(experimental);
        Score_Data() when $_     eq $menu[0];
        Select_round() when $_   eq $menu[1];
        Show_Matchups() when $_  eq $menu[2];
        View_Standings() when $_ eq $menu[3];
        Override() when $_       eq $menu[4];
    }

} while ( $main_menu ne $menu[-1] );

Save_File();

exit 0;

# End of main 

sub Save_File {
	# Save data to file
	$player_data->{'META'} = {
		score_round  => $score_round,
		total_rounds => $total_rounds,
	};
	DumpFile( $Players_File . ".yml", $player_data );
	delete $player_data->{BYE};
	delete $player_data->{META};
}

sub Select_round {
# Advance the round and set pairings.
	# Check to see that all current round data has been scored.
	for (keys $player_data) {
		unless (defined $player_data->{$_}->{prestige}[$score_round]){
			print "\nERROR: Missing Score data for round " . ($score_round + 1) ." Unable to advance\n\n";
			return 0;
		}
	}
	#Check to see if is already the last round
	if (($score_round + 1) eq $total_rounds) {
		print "\nERROR: Already at the last round.\n\n";
		return 0;
	}
    $score_round++;
    Make_Pairing();
    return 0;
}

sub sum {
	# Total the values in an array
    my @array = @_;
    my $total = 0;
    for (@array) {
        $total += $_ if defined $_;
    }
    return $total;
}

sub Make_Pairing {
	# Make all the pairings for the current round.

    # Sort players based on Prestige.
    my @Players = sort {
        sum( @{ $player_data->{$b}->{prestige} } )
          <=> sum( @{ $player_data->{$a}->{prestige} } )
    } keys $player_data;

    for my $i ( 0 .. $#Players ) {
	# Match the top player with the next valid player in the list.
        my $player = $Players[$i];
		if ($player_data->{$player}->{status} eq 'Disabled') {
			$player_data->{$player}->{opponents}[$score_round] = 'N/A';
		}
        unless ( defined $player_data->{$player}->{opponents}[$score_round] || $player_data->{$player}->{status} eq 'Disabled') {
		# Filter out players that have a match, and disabled players
            my $opponent = $i; # Index for the player in the @Players array
            my $nomatch  = 0;  # valid matching
            my $BYE;           # Player will be paired with BYE

            do {
                # Check next opponent in list to see if they are a valid pair
                $opponent++;   # set the array index for the proposed opponent
                $nomatch = 0;
                if ( defined $Players[$opponent] && $player_data->{$Players[$opponent]}->{status} ne 'Disabled') {
				# Ensure the next player in the list is defined, Active
					if ( defined $player_data->{$Players[$opponent]}->{opponents}[$score_round] ) {
						# Check to ensure opponent doesn't have existing match data;
						$nomatch = 1;
					}
					unless ($nomatch) {
						for ( @{ $player_data->{$player}->{opponents} } ) {
						# Check the players previous opponents. 
							if ( $_ eq $Players[$opponent] ) {
							# This matching took place in a previous round.
								$nomatch = 1;
							}
						 }
					}
				}
                else {
                # End of list of players and no valid match match found
                    $nomatch = 0;
                    $BYE     = 1;
                }
            } while ($nomatch); # Check next opponent if match failed.

            if ($BYE) {
			# Set the matching and prestige for the BYE
                push @{ $player_data->{$player}->{opponents} }, 'BYE';
                $player_data->{$player}->{prestige}[$score_round] = 4;
            }
            else {
			# Match player with the selected opponent, match opponent with player
                push @{ $player_data->{$player}->{opponents} },
                  $Players[$opponent];
                push @{ $player_data->{ $Players[$opponent] }->{opponents} },
                  $player;
             }
         }
    } # Proceed to the next player
	Save_File();
    return 0;
}

sub Show_Matchups {
    my %matchups;
    for ( keys $player_data ) {
		unless ($player_data->{$_}->{status} eq 'Disabled') {
	        $matchups{$_} = $player_data->{$_}->{opponents}[$score_round];
		}
    }

    my $spacer = 0;
    for ( keys $player_data ) {
        $spacer = length if length > $spacer;
    }

	my $format = "{>>>} {<{" . $spacer . "}<} {><<} {<{" . $spacer . "}<}";
    print "Round " . ($score_round + 1) . " Pairings\n\n";

	print form $format, 'Table', 'Player', ' ', 'Player';
	my $index = 1;
	my $BYE;
    for ( sort keys %matchups ) {
        if ( defined $matchups{$_} ) {
			if ($matchups{$_} eq 'BYE') {
				$BYE = $_;
				next;
			}
			my $table = $index++ . '.';
			print form $format, $table, $_, '<->', $matchups{$_};
            delete $matchups{ $matchups{$_} };
        }
    }
	if (defined $BYE) {
		print form $format, ' ', $BYE, '<->', 'BYE';
	}
    print "\n";
    return 0;
}

sub View_Standings {
	# Print the current standings for the tournament

	# Sort the players on Prestige, then Strength of Schedule
    my @temp =
      map { [ sum( @{ $player_data->{$_}->{prestige} } ), $_ ] }
      keys $player_data;
    for (@temp) {
        my $Sos  = 0;
        my $name = $_->[1];
        for ( @{ $player_data->{$name}->{opponents} } ) {
            $Sos += sum( @{ $player_data->{$_}->{prestige} } )
              unless $_ eq 'BYE' || $_ eq 'N/A';
        }
        push $_, $Sos;
    }
    my @Sorted_Players =
      map { $_->[1] } sort { $b->[0] <=> $a->[0] || $b->[2] <=> $a->[2] } @temp;

	# Determine the required field width for names
    my $spacer = 0;
    for ( keys $player_data ) {
        $spacer = length if length > $spacer;
    }

	# Build form format line and Header
	my $format = "  {>>>} {<{" . ($spacer) . "}<} {<<<<<<}  {<} "; 
	my @header = ('Rank', 'Player name', 'Prestige', 'SoS');
	
	for (1 .. ($score_round + 1)) {
		$format = $format . " {<{". ($spacer + 4) . "}<}";
		push @header, " Round " . $_;
	}

	# Print Header
	print form $format,@header;

	# Populate & print form data line
	my $Rank = 0;
	for my $player (@Sorted_Players) {
		my @Print_Line;

		# Add Rank, Mark disabled players rank as '!DEL-'
		if ($player_data->{$player}->{status} eq 'Disabled') {
			push @Print_Line, '!DEL-';
		}
		else {
			push @Print_Line, ++$Rank;
		}

		# Add the Player Name
		push @Print_Line, $player;

		# Add the total Prestige
        my $prestige = sum( @{ $player_data->{$player}->{prestige} } );
		push @Print_Line, $prestige;

		# Add the Strength of Schedule
		my $Sos;
        for ( @{ $player_data->{$player}->{opponents} } ) {
            $Sos += sum( @{ $player_data->{$_}->{prestige} } )
              unless $_ eq 'BYE' || $_ eq 'N/A';
        }
		$Sos = 0 unless defined $Sos;
		push @Print_Line, $Sos;

		# Add Round Results and Opponents
        for my $opp ( @{ $player_data->{$player}->{opponents} } ) {
            my $round = firstidx { $_ eq "$opp" } @{ $player_data->{$player}->{opponents} };
			my $round_prestige = ' ';
			if ( defined $player_data->{$player}->{prestige}[$round] ) {
				$round_prestige = $player_data->{$player}->{prestige}[$round];
			}
			push @Print_Line, "[$round_prestige] $opp";
        }
		print form $format, @Print_Line;
	}
	print "\n";
    return 0;
}

sub Load_Player_data {
# Load in the initial list of players and generate initial pairings

    # Load Players
    open( my $fh_players, "<", $ARGV[0] ) or die "$!";
    chomp( my @players = <$fh_players> );
    close $fh_players;

    # Add Bye if needed
    if ( scalar @players % 2 == 1 ) {
        push @players, "BYE";
    }

    # Determine number of rounds
    my $rounds;
    for ( scalar @players ) {
        no warnings qw(experimental);
        $rounds = 6 when $_ >= 33;
        $rounds = 5 when $_ >= 17;
        $rounds = 4 when $_ >= 9;
        $rounds = 3 when $_ >= 5;
        $rounds = 2 when $_ >= 2;
    }

    # Generate Pairings at random
    do {
        my $player1 = splice @players, int( rand( scalar @players ) ), 1;
        my $player2 = splice @players, int( rand( scalar @players ) ), 1;

        $player_data->{$player1} = {
            opponents => [$player2],
            prestige  => [ ( undef, ) x $rounds ],
			status    => 'Active',
        };

        $player_data->{$player2} = {
            opponents => [$player1],
            prestige  => [ ( undef, ) x $rounds ],
			status    => 'Active',
        };

        if ( $player2 eq 'BYE' ) {
            $player_data->{$player1}->{prestige}[0] = 4;
        }
        elsif ( $player1 eq 'BYE' ) {
            $player_data->{$player2}->{prestige}[0] = 4;
        }

    } while ( scalar @players > 0 );

    $score_round  = 0;
    $total_rounds = $rounds;

    return 0;
}

sub Score_Data {


    # Filter out players with score data for this round
    my @sorted_players;
    for ( sort keys %$player_data ) {
        unless ( defined $player_data->{$_}->{prestige}[$score_round] || $player_data->{$_}->{status} eq 'Disabled') {
            push @sorted_players, $_;
        }
    }

    if ( scalar @sorted_players == 0 ) {
         print "No More players to score for round "
          . ( $score_round + 1 ) . ".\n";
        return;
    }

	push @sorted_players, 'Return';

    # prompt for player
    my $Player = $term->get_reply(
        prompt  => 'Score which player?',
        choices => \@sorted_players,
		default => $sorted_players[-1],
    );
	if ($Player eq $sorted_players[-1]) {
		return 0;
	}

    my $Player2 = $player_data->{$Player}->{opponents}[$score_round];
    print "\nScoring match vs $Player2\n";

    # valid scoring options as of Aug, 2014
    my @score_options = (
        'Won both games',
        'Won and Lost',
        'Won Game and Timeout',
        'Lost Game and Timeout',
        'Timeout on first game',
        'Lost both games',
		'Return'
    );

    # Prompt for Score
    my $score = $term->get_reply(
        prompt  => 'Match Result',
        choices => \@score_options,
		default => $score_options[-1],
    );
	if ($score eq $score_options[-1]) {
		return 0;
	}
	my $Player1_Timeout_Mod = 0;
	my $Player2_Timeout_Mod = 0;
	if ($score =~ m/Timeout/) {
		# if there was a timeout, check for Lead Tie or Deficit
		my @timeout = (
			'Agenda Point Lead',
			'Agenda Point Tie',
			'Agenda Point Deficit',
			'Return'
		);
		my $timeout_result = $term->get_reply(
			prompt => 'Timout Result',
			choices => \@timeout,
			default => $timeout[-1],
		);
		if ($timeout_result eq $timeout[-1]) {
			return 0;
		}
		for ($timeout_result) {
			no warnings qw(experimental);
			when ($timeout_result eq $timeout[0]) {
				$Player1_Timeout_Mod = 1;
			}
			when ($timeout_result eq $timeout[1]) {
				$Player1_Timeout_Mod = 1;
				$Player2_Timeout_Mod = 1;
			}
			when ($timeout_result eq $timeout[2]) {
				$Player2_Timeout_Mod = 1;
			}
		}
	}

    for ($score) {
        no warnings qw(experimental);
        when ( $score eq $score_options[0] ) {
            # Won both Games

            $player_data->{$Player}->{prestige}[$score_round]  = 4;
            $player_data->{$Player2}->{prestige}[$score_round] = 0;
        }
        when ( $score eq $score_options[1] ) {
            # Split games

            $player_data->{$Player}->{prestige}[$score_round]  = 2;
            $player_data->{$Player2}->{prestige}[$score_round] = 2;
        }
        when ( $score eq $score_options[2] ) {
            # Won Game 1 and timeout 

            $player_data->{$Player}->{prestige}[$score_round]  = 2 + $Player1_Timeout_Mod;
            $player_data->{$Player2}->{prestige}[$score_round] = 0 + $Player2_Timeout_Mod;

        }
        when ( $score eq $score_options[3] ) {
            # Lost Game 1 and timeout

            $player_data->{$Player}->{prestige}[$score_round]  = 0 + $Player1_Timeout_Mod;
            $player_data->{$Player2}->{prestige}[$score_round] = 2 + $Player2_Timeout_Mod;
        }
        when ( $score eq $score_options[4] ) {
            # Timeout first game

            $player_data->{$Player}->{prestige}[$score_round]  = 0 + $Player1_Timeout_Mod;
            $player_data->{$Player2}->{prestige}[$score_round] = 0 + $Player2_Timeout_Mod;
        }
        
        when ( $score eq $score_options[5] ) {
            # Lost both Games

            $player_data->{$Player}->{prestige}[$score_round]  = 0;
            $player_data->{$Player2}->{prestige}[$score_round] = 4;
        }
    }
	Save_File();
    return 0;
}

sub Override {
	# Note: This whole password thing is a joke. Anything other then a blank string will let you in.
	my $term = Term::ReadLine->new('passwd');
	my $passwd = $term->readline("Please enter the Administrator Password:");
	if ($passwd eq '') {
		print "\nPassword incorrect\n --== ACCESS DENIED ==--\n";
		return 0;
	}
	print "\n --== ACCESS GRANTED ==--\n";
	print "\n !!Please be carefull with the options in this menu!!\n";

	my @menu = (
		'Disable Player',
		'Enable player',
		'Add Player',
		'Score Adjustment',
		'Opponent Adjustment',
		'Re Create Pairings',
		'Override Rounds',
		'Return',
	);
	my $override_menu;
	do {
		$override_menu = $term->get_reply( 
			prompt   => "Admin Function",
			choices  => \@menu,
			default  => $menu[-1],
			print_me => "\nADMINISTRATOR OVERRIDE ENABLED",
		);

		for ($override_menu) {
			no warnings qw(experimental);
			Admin_Disable() when $_  eq $menu[0];
			Admin_Enable() when $_   eq $menu[1];
			Admin_Add() when $_      eq $menu[2];
			Admin_Score() when $_    eq $menu[3];
			Admin_Pairing() when $_  eq $menu[4];
			Admin_Matchups() when $_ eq $menu[5];
			Admin_Round() when $_    eq $menu[6];
		}

	} while ( $override_menu ne $menu[-1] );
	return 0;
}

sub Admin_Matchups {
	for ( keys $player_data ) {
		$player_data->{$_}->{opponents}[$score_round] = undef;
	}
	Make_Pairing();
}

sub Admin_Round {

	my $term = Term::ReadLine->new('round');

	print "\nCurrent Total rounds Required: " . $total_rounds . "\n\n";
	my $new_total_rounds = $term->readline("Set the new total to (Enter to Cancel):");
	if ($new_total_rounds eq '') {
		print "\nTotal Rounds Unchanged\n";
	}
	elsif ( (looks_like_number($new_total_rounds)) && ($new_total_rounds gt 0) ) {
		$total_rounds = $new_total_rounds;
	}
	else {
		print "\nError: Please enter a NUMBER Greater then 0.\n";
	}

	print "\nCurrent Round: " . $score_round + 1 . "\n\n";
	my $new_round = $term->readline("Set the curent round to (Enter to Cancel):");
	if ($new_round eq '') {
		print "\nCurrent Round Unchanged\n";
	}
	elsif ( (looks_like_number($new_round))  && ($new_round lt $total_rounds) && ($total_rounds gt 0)) {
		$score_round = $new_round - 1;
	}
	else {
		print "\nError: Please enter a NUMBER Greater then 0 and less then the total number of rounds.\n";
	}
	print "\nPlease be sure to Re Create the Pairings if the current round changed.\n";

return 0;
}

sub Admin_Score {
	my $spacer = 0;
	for ( keys $player_data ) {
		$spacer = length if length > $spacer;
	}

	my $format = "{<{" . ($spacer) . "}<}"; 
	my @header = ("Player name");
	
	for (1 .. $total_rounds) {
		$format = $format . " {>>>>>>>}";
		push @header, " Round " . $_;
	}

	my $title = form $format, @header;
	chomp $title;
	my @menu;
	my @players;

	for my $p (sort keys $player_data) {
		my @data = ($p);
		for (0 .. ($total_rounds) -1 ) {
			if (defined $player_data->{$p}->{prestige}[$_]){
			push @data, $player_data->{$p}->{prestige}[$_];
			}
			else {
				push @data, 'N/A';
			}
		}
		push @players, $p;
		push @menu, (form $format, @data);
	}
	chomp @menu;
	push @menu, "Cancel Edit";

    # Prompt for player
    my $player = $term->get_reply(
        prompt  => 'Player to edit',
        choices => \@menu,
        default  => $menu[-1],
		print_me => "\n     $title",
    );
	if ($player eq $menu[-1]){
		return 0;
	}

	my $select = $players[ firstidx { $_ eq $player } @menu];

	$format = "{<<<<<<<<<<} {>>>>>>>}";

	@menu = ();
	my @rounds;
	for (0 .. ($total_rounds) -1 ) {
		my @data;
		push @rounds, $_;
		push @data, "Round " . ($_ + 1);
		if (defined $player_data->{$select}->{prestige}[$_]){
			push @data, $player_data->{$select}->{prestige}[$_];
		}
		else {
			push @data, 'N/A';
		}
		push @menu, (form $format, @data);
	}
	push @menu, "Cancel Edit";
	chomp @menu;

    # Prompt for round 
    my $round = $term->get_reply(
        prompt  => 'Round to edit',
        choices => \@menu,
        default  => $menu[-1],
		print_me => "\n     Round         Prestige",
    );
	if ($round eq $menu[-1]){
		return 0;
	}
	my $r = $rounds[ firstidx { $_ eq $round } @menu];

	my $term = Term::ReadLine->new('prestige');

	my $new_prestige;

	do { 
		$new_prestige = $term->readline("Set prestige to (Enter to Cancel):");
		if ($new_prestige eq '') {
			print "\nPrestige for $select for Round " . $r +1 . " Unchanged.\n";
		}
		elsif ( looks_like_number($new_prestige) ) {
			$player_data->{$select}->{prestige}[$r] = $new_prestige;
		}
		else {
			print "\nError: Please enter a NUMBER.\n";
		}
	} until ( looks_like_number($new_prestige) || $new_prestige eq '' );

	my $opponent = $player_data->{$select}->{opponents}[$r];
	do { 
		print "Set prestige for " . $select . "s Round " . $r + 1 . " opponenet: $opponent\n";
		$new_prestige = $term->readline("Set prestige to (Enter to Cancel):");
		if ($new_prestige eq '') {
			print "\nPrestige for $opponent for Round " . $r +1 . " Unchanged.\n";
		}
		elsif ( looks_like_number($new_prestige) ) {
			$player_data->{$opponent}->{prestige}[$r] = $new_prestige;
		}
		else {
			print "\nError: Please enter a NUMBER.\n";
		}
	} until ( looks_like_number($new_prestige) || $new_prestige eq '' );
	return 0;
}

sub Admin_Pairing {
	my $spacer = 0;
	for ( keys $player_data ) {
		$spacer = length if length > $spacer;
	}
	my @rounds;
	my $format = "{<{" . ($spacer) . "}<}"; 
	my @header = ("Player name");
	
	for (1 .. $total_rounds) {
		$format = $format . " {<{" . ($spacer) . "}<}";
		push @header, " Round " . $_;
		push @rounds, "Round " . $_;
	}
	print "\n ";
	print form $format, @header;
	my @pairing_data;

	for my $p (sort keys $player_data) {
		my @data = ($p);
		for (0 .. ($total_rounds) -1 ) {
			if (defined $player_data->{$p}->{opponents}[$_]){
				push @data, $player_data->{$p}->{opponents}[$_];
			}
			else {
				push @data, 'N/A';
			}
		}
		push @pairing_data, (form $format, @data);
	}
	print " @pairing_data";
	push @rounds, "Cancel Edit";

    # Prompt for player
    my $round = $term->get_reply(
        prompt  => 'Choose round',
        choices => \@rounds,
        default  => $rounds[-1],
		print_me => "\nEdit pairing data for which round?",
    );
	if ($round eq $rounds[-1]){
		return 0;
	}

	my @Match_Rounds = (0 .. $total_rounds);
	my $selected_round = $Match_Rounds[ firstidx { $_ eq $round } @rounds];

	$format = "{<{" . ($spacer) . "}<}   {<{" . ($spacer) . "}<}"; 
	my $title = form $format, 'Player', 'Opponent';
	chomp $title;
	my @round_match;
	do {
		my @players;
		for my $p (sort keys $player_data) {
			my @data = ($p);
			if (defined $player_data->{$p}->{opponents}[$selected_round]){
				push @data, $player_data->{$p}->{opponents}[$selected_round];
				push @players, $p;
			}
			else {
				push @data, 'N/A';
			}
			push @round_match, (form $format, @data);
		}
		chomp @round_match;
		push @round_match, "Clear All Pairings", "Return";
		my $round = $term->get_reply(
			prompt  => 'Choose pairing',
			choices => \@round_match,
			default  => $round_match[-1],
			print_me => "     " . $title,
		);

		my $selected_player = $players[ firstidx { $_ eq $round } @rounds];
		
		if ($round eq $round_match[-2]){
			for (keys $player_data) {
				$player_data->{$_}->{opponents}[$selected_round] = undef;
			}
		}
		elsif ($round ne $round_match[-1]) {
			my @menu;
			for (sort keys $player_data) {
				push @menu, $_ unless $_ eq $selected_player;
			}
			push @menu, "Cancel";
			my $opponent = $term->get_reply(
				prompt  => "Select the opponent for $selected_player",
				choices => \@menu,
				default  => $menu[-1],
				print_me => "\nOpponent Selection",
			);
			if ($opponent eq $menu[-1]){
				next;
			}
			else {
				$player_data->{$selected_player}->{opponents}[$selected_round] = $opponent;
				$player_data->{$selected_player}->{prestige}[$selected_round] = undef;
				$player_data->{$opponent}->{opponents}[$selected_round] = $selected_player;
				$player_data->{$opponent}->{prestige}[$selected_round] = undef;
			}
		}
	} until ($round eq $round_match[-1]);
}

sub Admin_Add {
	my $term = Term::ReadLine->new('new');
	my $new_player = $term->readline("New Player Name (Enter to Cancel):");
	if ($new_player eq '') {
		return 0;
	}
# TODO Players are mis assigned when disabled players exist.
	if ((scalar (keys $player_data)) % 2 == 1) {
		for (keys $player_data) {
			if ( $player_data->{$_}->{opponents}[$score_round] eq 'BYE'){
				$player_data->{$_}->{opponents}[$score_round] = $new_player;
				$player_data->{$_}->{prestige}[$score_round] = undef;

				$player_data->{$new_player} = {
					opponents => [('N/A', ) x $score_round],
					prestige  => [ ( undef, ) x $total_rounds ],
					status    => 'Active',
		        };
				for ( 0 .. ($score_round - 1 )) {
					$player_data->{$new_player}->{prestige}[$_] = 0;
				}

		        $player_data->{$new_player}->{opponents}[$score_round] = $_;
				$player_data->{$new_player}->{prestige}[$score_round] = undef;
				last;
			}
		}
	}
	else {
		$player_data->{$new_player} = {
			opponents => [('N/A', ) x $score_round],
			prestige  => [ ( undef, ) x $total_rounds ],
			status    => 'Active',
		};
		for ( 0 .. ($score_round - 1 )) {
			$player_data->{$new_player}->{prestige}[$_] = 0;
		}
		$player_data->{$new_player}->{opponents}[$score_round] = 'BYE';
		$player_data->{$new_player}->{prestige}[$score_round] = 4;
	}

}

sub Admin_Disable {
    # Filter out players who are disabled
    my @sorted_players;
    for ( sort keys %$player_data ) {
        unless ($player_data->{$_}->{status} eq 'Disabled') {
            push @sorted_players, $_;
        }
    }
    if ( scalar @sorted_players == 0 ) {
		print "ERROR: No Active players. What kind of tournament are you running?\n";
        return;
    }
	push @sorted_players, 'Return';

    # prompt for player
    my $Player = $term->get_reply(
        prompt  => 'Disable which player?',
        choices => \@sorted_players,
		default => $sorted_players[-1],
    );
	if ($Player eq $sorted_players[-1]){
		return 0;
	}

	print $Player . " has been DEREZED.\n";
	print $Player . "'s previous opponent Will be matched with BYE, or player who was previosuly matched with BYE.\n";
	$player_data->{$Player}->{status} = 'Disabled';

	my $Opponent = $player_data->{$Player}->{opponents}[$score_round];
	if ( (scalar @sorted_players) % 2 == 1 ) {
	# Odd Number of players remain in the tournament, Match Previous opponent with BYE
		$player_data->{$Opponent}->{opponents}[$score_round] = 'BYE';
		$player_data->{$Opponent}->{prestige}[$score_round] = '4';
	}
	else {
		# Even Number or players.  Find the previous BYE matching and replace
		for (keys $player_data) {
			if ($player_data->{$_}->{opponents}[$score_round] eq 'BYE') {
				$player_data->{$_}->{opponents}[$score_round] = $Opponent;
				$player_data->{$_}->{prestige}[$score_round] = undef;
				$player_data->{$Opponent}->{opponents}[$score_round] = $_;
				$player_data->{$Opponent}->{prestige}[$score_round] = undef;
				last;
			}
		}
	}
	# Remove the disabled players Current Opponent, and set prestige to 0 
	$player_data->{$Player}->{opponents}[$score_round] = 'N/A';
	$player_data->{$Player}->{prestige}[$score_round] = 0;

	return 0;
}

sub Admin_Enable {

    # Filter out players who are not disabled
    my @sorted_players;
    for ( sort keys %$player_data ) {
        if ($player_data->{$_}->{status} eq 'Disabled') {
            push @sorted_players, $_;
        }
    }

    if ( scalar @sorted_players == 0 ) {
		print "ERROR: No Players are disabled at this time.\n";
        return;
    }

	push @sorted_players, 'Return';
    # prompt for player
    my $Player = $term->get_reply(
        prompt  => 'Enable which player?',
        choices => \@sorted_players,
		default => $sorted_players[-1],
    );
	if ($Player eq $sorted_players[-1]) {
		return 0;
	}

	print $Player . " has been REZED.\n";
	print $Player . "Will be matched with the BYE, or player who previosuly had the BYE.\n";
	$player_data->{$Player}->{status} = 'Active';

	if ( ((scalar @sorted_players) + 1) % 2 == 1 ) {
		my $Opponent; 
		for (keys $player_data) {
			if ($player_data->{$_}->{opponents}[$score_round] eq 'BYE') {
				$Opponent = $_;
				last;
			}
		}
		$player_data->{$Opponent}->{opponents}[$score_round] = $Player;
		$player_data->{$Opponent}->{prestige}[$score_round] = undef;
		$player_data->{$Player}->{opponents}[$score_round] = $Opponent;
		$player_data->{$Player}->{prestige}[$score_round] = undef;
	}
	else {
		$player_data->{$Player}->{opponents}[$score_round] = 'BYE';
		$player_data->{$Player}->{prestige}[$score_round] = 4;
	}
	return 0;
}
