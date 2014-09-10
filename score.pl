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
use 5.14.0;
use YAML::XS qw(DumpFile LoadFile);
use Term::UI;
use Term::ReadLine;
use Getopt::Std;
use Perl6::Form;
use List::MoreUtils qw(firstidx);
my $DEBUG = 0;

# Set file name to work from
my %opts;
getopts( 'f:', \%opts );

$opts{'f'} =~ s/(.*).txt$/$1/x;

my $data_file = $opts{'f'} . ".yml";
my $score_round;
my $player_data;
my $total_rounds;
my $matchups_shown;

unless ( -e $data_file ) {
    Load_Player_data();
}
else {
    $player_data  = LoadFile($data_file);
    $score_round  = $player_data->{META}->{score_round};
    $total_rounds = $player_data->{META}->{total_rounds};
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

$player_data->{'META'} = {
    score_round  => $score_round,
    total_rounds => $total_rounds,
};

DumpFile( $opts{f} . ".yml", $player_data );
exit 0;

sub Select_round {
    $score_round++;
    Make_Pairing();
	$matchups_shown = undef;
    return 0;
}

sub sum {
    my @array = @_;
    my $total = 0;
    for (@array) {
        $total += $_ if defined $_;
    }
    return $total;
}

sub Make_Pairing {

    # Sort players based on Prestige.
    my @Players = sort {
        sum( @{ $player_data->{$b}->{prestige} } )
          <=> sum( @{ $player_data->{$a}->{prestige} } )
    } keys $player_data;
    if ($DEBUG) {
        for my $i ( 0 .. $#Players ) {
            print STDERR "DEBUG: $i. " . $Players[$i] . "\n";
        }
    }
    for my $i ( 0 .. $#Players ) {
        my $player = $Players[$i];
        unless ( defined $player_data->{$player}->{opponents}[$score_round] || $player_data->{$player}->{status} eq 'Disabled') {
            print STDERR "DEBUG: $i " . $player . ".\n" if $DEBUG;
            print STDERR
"DEBUG:    previous opponents: @{$player_data->{$player}->{opponents}}\n"
              if $DEBUG;
            my $opponent = $i;
            my $nomatch  = 0;
            my $BYE;
            do {
                # Check next opponent in list to see if they are a valid pair
                $opponent++;
                $nomatch = 0;
                if ( defined $Players[$opponent] && $player_data->{$Players[$opponent]}->{status} ne 'Disabled') {
                    print STDERR "DEBUG:   ->  checking $opponent "
                      . $Players[$opponent] . "\n"
                      if $DEBUG;
                    for ( @{ $player_data->{$player}->{opponents} } ) {
                        if ( $_ eq $Players[$opponent] ) {
                            print STDERR "DEBUG:    -> $_ Not a valid match.\n"
                              if $DEBUG;

                            # Fail this pair up.
                            $nomatch = 1;
                        }
                    }
                }
                else {
                    # End of list and no match found.
                    print STDERR "DEBUG: No Match found, "
                      . $player
                      . " is matched with BYE.\n"
                      if $DEBUG;
                    $nomatch = 0;
                    $BYE     = 1;
                }
                sleep 1;
            } while ($nomatch);
            if ($BYE) {
                print STDERR "DEBUG: Finalizing BYE for " . $player . ".\n"
                  if $DEBUG;
                push @{ $player_data->{$player}->{opponents} }, 'BYE';
                $player_data->{$player}->{prestige}[$score_round] = 4;
            }
            else {
                print STDERR "DEBUG: Finalizing match of "
                  . $Players[$opponent]
                  . " With "
                  . $player . ".\n"
                  if $DEBUG;
                push @{ $player_data->{$player}->{opponents} },
                  $Players[$opponent];
                push @{ $player_data->{ $Players[$opponent] }->{opponents} },
                  $player;
            }
        }
    }
    DumpFile( $opts{f} . ".yml", $player_data );
    return 0;
}

sub Show_Matchups {
    my %matchups;
    for ( keys $player_data ) {
        $matchups{$_} = $player_data->{$_}->{opponents}[$score_round];
    }

    my $spacer = 0;
    for ( keys $player_data ) {
        $spacer = length if length > $spacer;
    }
    $spacer += 5;

    print "Round " . $score_round + 1 . " Pairings\n";

    for ( sort keys %matchups ) {
        if ( defined $matchups{$_} ) {
            print sprintf( "%-${spacer}s %-5s %-${spacer}s \n",
                $_, '->', $matchups{$_} );
            delete $matchups{ $matchups{$_} };
        }
    }
    print "\n";
	$matchups_shown = 1;
    return 0;
}

sub View_Standings {
    my @temp =
      map { [ sum( @{ $player_data->{$_}->{prestige} } ), $_ ] }
      keys $player_data;
    for (@temp) {
        my $Sos  = 0;
        my $name = $_->[1];
        for ( @{ $player_data->{$name}->{opponents} } ) {
            $Sos += sum( @{ $player_data->{$_}->{prestige} } )
              unless $_ eq 'BYE';
        }
        push $_, $Sos;
    }
    my @Players =
      map { $_->[1] } sort { $b->[0] <=> $a->[0] || $b->[2] <=> $a->[2] } @temp;

    my $spacer = 0;
    for ( keys $player_data ) {
        $spacer = length if length > $spacer;
    }

    print form "  {>>>} {<{"
      . ($spacer)
      . "}<} {<<<<<<<} {<<<}  {<{"
      . ( $spacer x ($score_round + 1) ) . "}<}",
      "Rank", "Player", "Prestige", "SoS", "Oponents";
    my $index = 0;
    for my $player (@Players) {
        my $prestige = 0;
        my $Sos      = 0;
        my $n        = ++$index . '.';

		if ($player_data->{$player}->{status} eq 'Disabled') {
			--$index;
			$n = '!DEL-';
		}

        $prestige = sum( @{ $player_data->{$player}->{prestige} } );

        for ( @{ $player_data->{$player}->{opponents} } ) {
            $Sos += sum( @{ $player_data->{$_}->{prestige} } )
              unless $_ eq 'BYE';
        }
        my $opponents;
        for my $opp ( @{ $player_data->{$player}->{opponents} } ) {
            my $standing = firstidx { $_ eq "$opp" } @Players;
            $standing++;
            $opponents = $opponents . sprintf( "%-" . ($spacer) . "s ", $opp );
        }

        print form "  {>>>} {<{"
          . ($spacer)
          . "}<} {<<<<<<<} {<<<}  {<{"
          . ( $spacer x ($score_round + 1) ) . "}<}",
          $n, $player, $prestige, $Sos, $opponents;
    }
    print "\n";
    return 0;
}

sub Load_Player_data {

    # Load Players
    open( my $fh_players, "<", $opts{'f'} . ".txt" ) or die "$!";
    chomp( my @players = <$fh_players> );
    close $fh_players;
    print STDERR "DEBUG: Loaded " . scalar @players . " Players.\n" if $DEBUG;

    # Add Bye if needed
    if ( scalar @players % 2 == 1 ) {
        print STDERR "DEBUG: Adding BYE Player.\n" if $DEBUG;
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
    print STDERR "DEBUG:" . $rounds . " rounds needed.\n" if $DEBUG;

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
            print STDERR
              "DEBUG: adding prestige for BYE player opponent: $player1.\n"
              if $DEBUG;
            $player_data->{$player1}->{prestige}[0] = 4;
        }
        elsif ( $player1 eq 'BYE' ) {
            print STDERR
              "DEBUG: adding prestige for BYE player opponent: $player2.\n"
              if $DEBUG;
            $player_data->{$player2}->{prestige}[0] = 4;
        }

         print STDERR "DEBUG:" . scalar @players . " remaining.\n" if $DEBUG;
    } while ( scalar @players > 0 );

    $score_round  = 0;
    $total_rounds = $rounds;

    $player_data->{'META'} = {
        score_round  => 0,
        total_rounds => $rounds,
    };
    return 0;
}

sub Score_Data {

	# Prevent accidental scores from being entered
	unless (defined $matchups_shown) {
		print "\nERROR: You cannot add score data without valid matchups.\n";
		return 0;
	}

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
		if ( ($score_round + 1) < $total_rounds ){
			print "\n\n--== Advancing to round " 
              . ( $score_round + 2 ) . " of "
			  . $total_rounds . "==--\n\n";
			Select_round();
		}
		else {
			View_Standings();
		}
        return;
    }

    # prompt for player
    my $Player = $term->get_reply(
        prompt  => 'Score which player?',
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
    my $score = $term->get_reply(
        prompt  => 'Match Result',
        choices => \@score_options,
    );

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

            # Won Game 1 and timeout Game 2 with agenda point lead.
            $player_data->{$Player}->{prestige}[$score_round]  = 3;
            $player_data->{$Player2}->{prestige}[$score_round] = 0;
        }
        when ( $score eq $score_options[3] ) {

            # Won Game 1 and timeout Game 2 with agenda point Tie
            $player_data->{$Player}->{prestige}[$score_round]  = 3;
            $player_data->{$Player2}->{prestige}[$score_round] = 1;
        }
        when ( $score eq $score_options[4] ) {

            # Won Game 1 and timeout Game 2 with agenda point deficit
            $player_data->{$Player}->{prestige}[$score_round]  = 2;
            $player_data->{$Player2}->{prestige}[$score_round] = 1;
        }
        when ( $score eq $score_options[5] ) {

            # Lost game and timeout with Agenda point lead
            $player_data->{$Player}->{prestige}[$score_round]  = 1;
            $player_data->{$Player2}->{prestige}[$score_round] = 2;
        }
        when ( $score eq $score_options[6] ) {

            # Lost game and timeout with Agenda point Tie
            $player_data->{$Player}->{prestige}[$score_round]  = 1;
            $player_data->{$Player2}->{prestige}[$score_round] = 3;
        }
        when ( $score eq $score_options[7] ) {

            # Lost Game 1 and timeout Game 2 with agenda point deficit
            $player_data->{$Player}->{prestige}[$score_round]  = 0;
            $player_data->{$Player2}->{prestige}[$score_round] = 3;
        }
        when ( $score eq $score_options[8] ) {

            # Timeout Game 1 with agenda point lead.
            $player_data->{$Player}->{prestige}[$score_round]  = 1;
            $player_data->{$Player2}->{prestige}[$score_round] = 0;
        }
        when ( $score eq $score_options[9] ) {

            # Timeout Game 1 with agenda point tie.
            $player_data->{$Player}->{prestige}[$score_round]  = 1;
            $player_data->{$Player2}->{prestige}[$score_round] = 1;
        }
        when ( $score eq $score_options[10] ) {

            # Timeout Game 1 with agenda point deficit
            $player_data->{$Player}->{prestige}[$score_round]  = 0;
            $player_data->{$Player2}->{prestige}[$score_round] = 1;
        }
        when ( $score eq $score_options[11] ) {

            # Lost both Games
            $player_data->{$Player}->{prestige}[$score_round]  = 0;
            $player_data->{$Player2}->{prestige}[$score_round] = 4;
        }
    }
    DumpFile( $opts{f} . ".yml", $player_data );
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


	my @menu = (
		'Disable Player',
		'Enable player',
		'Add Player',
		'Score Adjustment',
		'Opponent Adjustment',
		'Return'
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
		}

	} while ( $override_menu ne $menu[-1] );
	return 0;
}

sub Admin_Score {

}

sub Admin_Pairing {

}

sub Admin_Add {

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

    # prompt for player
    my $Player = $term->get_reply(
        prompt  => 'Disable which player?',
        choices => \@sorted_players,
    );

	print $Player . " has been DEREZED.\n";
	print $Player . "'s previosu oppoment Will be matched with BYE, or player who was previosuly matched with BYE.\n";
	$player_data->{$Player}->{status} = 'Disabled';

	if ( ((scalar @sorted_players) - 1) % 2 == 1 ) {
		my $Opponent = $player_data->{$Player}->{opponents}[$score_round];
		$player_data->{$Opponent}->{opponents}[$score_round] = 'BYE';
		$player_data->{$Opponent}->{prestige}[$score_round] = '4';
	}
	else {
		$player_data->{$Player}->{opponents}[$score_round] = undef;
		$player_data->{$Player}->{prestige}[$score_round] = undef;
	}

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

    # prompt for player
    my $Player = $term->get_reply(
        prompt  => 'Enable which player?',
        choices => \@sorted_players,
    );

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


