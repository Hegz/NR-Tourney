NR-Tourney
==========

A simple Android: Netrunner Tournament manager 

Compliant with Tournament rules version: 1.5.1 (Aug 2014), although this script doesn't support Championship brackets.

Installation
------------

Download the score.pl file to a discrete location on your computer Either via 

Git: git clone git@github.com:Hegz/NR-Tourney.git

Downloading the Zip

Or Just download the score.pl file directly.

Requirements
------------

The following Perl modules will need to be installed if they aren't already

YAML::XS
Term::UI
Perl6::Form
List::MoreUtils 


Usage
-----

Create a text file and add your players, 1 per line.  There is an example (players.txt) included in this repository.

Run the program with the command:  
```
score.pl -f players_list.txt
```
where players_list.txt is the name of the text file containing the players.


### Main Menu

```
Current Round:1 of 5
  1> Add Score Data
  2> Advance Round
  3> Show Matchups
  4> View standings
  5> Save & Quit

Menu selection [5]: 
```

The current round is displayed at the top of the menu, along with the total number of rounds required to come to a consensus.

After loading the program you will need to initialize and display the initial pairings by pressing 3.

Once all scoring data for the round has been entered, you can advance the round by pressing 2.

You can then repeat the process of `Show Matchups` , `Add Score Data`, `Advance Round` until the final score data has been entered for the final round.

You can view the current standings by pressing 4.

At Any time you can press 5 to save and quit the tournament.  The Tournament data will be saved to a file players_list.yml, when you re run the progam with the command:
```
score.pl -f My_Tournament.txt
```
Any saved tournament data will be reloaded.

If you wish to restart the tournament or load a new tournament with the same players , you will either need to rename the players_list.txt file, or delete the players_list.yml file.



### Recording score data

As round results are completed, you can enter the data by pressing 1.

You will then need to enter the number for the reporting player, you will then be able to select from the following menu:


```
  1> Won both games
  2> Won and Lost
  3> Won Game 1 and Timeout w/ AP lead
  4> Won Game 1 and Timeout w/ AP Tie
  5> Won Game 1 and Timeout w/ AP Deficit
  6> Lost Game 1 and Timeout w/ AP Lead
  7> Lost Game 1 and Timeout w/ AP Tie
  8> Lost Game 1 and Timeout w/ AP Deficit
  9> Timeout first game w/ AP Lead
 10> Timeout first game w/ AP Tie
 11> Timeout first game w/ AP Deficit
 12> Lost both games
```

The appropriate prestige result will be entered for the player, and their opponent, and both players will be removed from the `1> Add Score Data` menu.

To Do
-----

There are still some bugs to resolve, and a few features to add to improve program flow including:


#### Known Bugs
  * Nothing at this time, But don't place too much trust in me.

#### Features
  * Add Player to the Tournament
  * Manual change of Score data
  * Manual change of Pairing
