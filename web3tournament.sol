//SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
//import "@openzeppelin/contracts/access/AccessControl.sol";

/*
COMMENTS 
    - Players can also be interpreted as teams

ASSUMPTIONS
    - Players don't register twice --> Easy check TODO / expensive loop
    - Tournament legs are decided off-chain --> Can be done on-chain using semi-random numbers (rand) and selecting players using 'players[rand]' for each match
    - Matchs are played one at a time 
        --> If we trust referee it's easily scalable, otherwise might need to track which referee was designated to each match (one referee can't be at two matchs at the same time)
        --> We can also delete MATCH_STATUS and allow for multiple matches simultaneously
    - Referee is owner --> Using Access control we can separate them
    - Owner "declares" the winner --> We trust the owner is going to honor the results of the final

TO SOLVE
    - In the MATCH FUNCTIONS matchStart args are _player1 and _player2 ; in matchFinished args are _refereeWinner and _refereeLoser
        -> PROBLEM: _player1 and _player2 must be the same two addresses used in matchFinished
    - Check that _player1 and _player2 are part of players[] --> Better to do off-chain grabbing data from events log
*/

// @ title Generic playoff tournament

contract web3tournament is Ownable {
    // ENUMS
    // @notice This tracks the status of the tournament
    enum TOURNAMENT_STATUS {
        NOT_STARTED,
        INSCRIPTIONS,
        IN_PROGRESS,
        FINISHED
    }
    TOURNAMENT_STATUS public tournament_status;

    // @notice This tracks the status of the matches
    enum MATCH_STATUS {
        NOT_STARTED,
        IN_PROGRESS
    }
    MATCH_STATUS public match_status;

    // MAPPINGS, ARRAYS AND VARIABLES

    // @notice A list of all the players registered
    address[] public players;

    // @notice The winner will always be the last address in the rankings array once the tournament is finished
    address[] public ranking;

    // @notice Depending on the results of the tournament, this addresses will cointain up to the 10th place
    address internal champion;
    address internal silver;
    address[] internal top10;

    //EVENTS
    event playerAdded(address indexed newPlayer);
    event matchStartedBetween(address indexed player1, address indexed player2);
    event matchResults(address indexed winner, address indexed loser);
    event positions(
        address indexed champion,
        address indexed silver,
        address[] indexed top10
    );

    //CONSTRUCTOR

    constructor() {
        match_status = MATCH_STATUS.NOT_STARTED;
        tournament_status = TOURNAMENT_STATUS.NOT_STARTED;
    }

    //TOURNAMENT FUNCTIONS

    // @notice Tournament inscriptions are open
    function startInscriptions() public onlyOwner {
        require(tournament_status == TOURNAMENT_STATUS.NOT_STARTED);
        tournament_status = TOURNAMENT_STATUS.INSCRIPTIONS;
    }

    // @notice Any player can register himself by adding his address
    // @param _player self-explanatory
    function addPlayer(address _player) external {
        require(_player != address(0));
        require(_player != owner());
        require(
            tournament_status == TOURNAMENT_STATUS.INSCRIPTIONS,
            "The tournament has already started!"
        );
        players.push(_player);
        emit playerAdded(_player);
    }

    // @notice A tournament can be initialized only when the amount of players/teams is even
    function startTournament() public onlyOwner {
        require(tournament_status == TOURNAMENT_STATUS.INSCRIPTIONS);
        require(players.length % 2 == 0);
        require(players.length != 0);
        tournament_status = TOURNAMENT_STATUS.IN_PROGRESS;
    }

    // @notice Returns the amount of players/teams have signed up for the tournament
    function amountOfPlayers() public view returns (uint256) {
        return players.length;
    }

    // @notice Returns the amount of players/teams have signed up for the tournament
    function listPlayers() public view returns (address[] memory) {
        return players;
    }

    // @notice To end the tournament the owner must send the champions address, and matches can't be in progress
    // @param _champion Tournament winner address, determined by owner
    function endTournament(address _champion) public onlyOwner {
        require(
            tournament_status == TOURNAMENT_STATUS.IN_PROGRESS,
            "There is no ongoing tournament!"
        );
        require(
            match_status == MATCH_STATUS.NOT_STARTED,
            "There is a match in progress!"
        );
        require(ranking.length == players.length - 1); // This guarantees all players have participated
        tournament_status = TOURNAMENT_STATUS.FINISHED;
        ranking.push(_champion);
        rewardPlayers();
    }

    // @notice Players will always be rewarded independently from owner; although owner is needed to END the tournament
    function rewardPlayers() internal onlyOwner {
        require(tournament_status == TOURNAMENT_STATUS.FINISHED);
        champion = ranking[ranking.length - 1];
        silver = ranking[ranking.length - 2];
        /*
        if(players.length >2){
            for (uint256 i = ranking.length - 3; i <= ranking.length; i++) {
                if(i<=10){
                top10.push(ranking[i]);
                } else {
                    top10 = top10;
                }
            }
        }
*/
        emit positions(champion, silver, top10);
        tournament_status = TOURNAMENT_STATUS.NOT_STARTED;
        champion = address(0);
        silver = address(0);
        delete players;
        delete top10;
        delete ranking;

        /* TODO
        
        transfer NFTs to winner, 2nd, 3rd and TOP 10 players
        
        https://docs.openzeppelin.com/contracts/4.x/api/token/erc1155 
        */
    }

    //MATCHS FUNCTIONS

    // @notice Owner/referee adds both players addresses | Mainly to keep a log of the matches | NON-ESSENTIAL
    function matchStart(address _player1, address _player2) public onlyOwner {
        require(match_status == MATCH_STATUS.NOT_STARTED);
        require(tournament_status == TOURNAMENT_STATUS.IN_PROGRESS);
        require(players.length > 1);
        require(_player1 != _player2);
        match_status = MATCH_STATUS.IN_PROGRESS;
        emit matchStartedBetween(_player1, _player2);
    }

    // @notice Owner/referee determines the winner and loser of the match
    function matchFinished(address _refereeWinner, address _refereeLoser)
        public
        onlyOwner
    {
        require(match_status == MATCH_STATUS.IN_PROGRESS);
        require(tournament_status == TOURNAMENT_STATUS.IN_PROGRESS);
        require(_refereeWinner != _refereeLoser);
        ranking.push(_refereeLoser);
        emit matchResults(_refereeWinner, _refereeLoser);
        match_status = MATCH_STATUS.NOT_STARTED;
    }
}
