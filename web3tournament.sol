//SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
//import "@openzeppelin/contracts/access/AccessControl.sol";

/*
ASSUMPTIONS
    - Players don't register twice --> Easy check TODO
    - Tournament legs are decided off-chain --> Can be done on-chain using semi-random numbers (rand) and selecting players using 'players[rand]' for each match
    - Matchs are played one at a time --> If we trust referee it's easily scalable, otherwise might need to use a mapping  referee => matchCreated (one referee can't be at two matchs at the same time)
    - Referee is owner --> Using Access control we can separate them
    - Owner "declares" the winner --> We trust the owner is going to honor the results of the final

TO SOLVE
    - In the MATCH FUNCTIONS matchStart args are _player1 and _player2 ; in matchFinished args are _refereeWinner and _refereeLoser
        -> PROBLEM: _player1 and _player2 must be the same two addresses used in matchFinished
*/

contract web3tournament is Ownable {
    // ENUMS
    enum TOURNAMENT_STATUS {
        NOT_STARTED,
        IN_PROGRESS,
        FINISHED
    }
    TOURNAMENT_STATUS public tournament_status;

    enum MATCH_STATUS {
        NOT_STARTED,
        IN_PROGRESS,
        FINISHED
    }
    MATCH_STATUS public match_status;

    // MAPPINGS AND VARIABLES
    address[] public players;
    address[] public ranking;

    //EVENTS
    event playerAdded(address indexed newPlayer);
    event tournamentWinner(address indexed champion);
    event matchStartedBetween(address indexed player1, address indexed player2);
    event matchResults(address indexed winner, address indexed loser);

    //CONSTRUCTOR

    constructor() {
        match_status = MATCH_STATUS.NOT_STARTED;
        tournament_status = TOURNAMENT_STATUS.NOT_STARTED;
    }

    //TOURNAMENT FUNCTIONS
    function addPlayer(address _player) public {
        require(_player != address(0));
        require(_player != owner());
        require(
            tournament_status == TOURNAMENT_STATUS.NOT_STARTED,
            "The tournament has already started!"
        );
        players.push(_player);
        emit playerAdded(_player);
    }

    function startTournament() public onlyOwner {
        require(tournament_status == TOURNAMENT_STATUS.NOT_STARTED);
        tournament_status = TOURNAMENT_STATUS.IN_PROGRESS;
    }

    function amountOfPlayers() public view returns (uint256) {
        return players.length;
    }

    function endTournament(address _champion) public onlyOwner {
        require(
            tournament_status == TOURNAMENT_STATUS.IN_PROGRESS,
            "There is no ongoing tournament!"
        );
        require(
            match_status == MATCH_STATUS.FINISHED,
            "There is a match in progress!"
        );
        require(ranking.length == players.length - 1);
        tournament_status = TOURNAMENT_STATUS.FINISHED;
        ranking.push(_champion);
        rewardPlayers();
    }

    function rewardPlayers() internal onlyOwner {
        require(tournament_status == TOURNAMENT_STATUS.FINISHED);
        require(match_status == MATCH_STATUS.FINISHED);
        //transfer NFTs to winner, 2nd, 3rd and TOP 10 players
        //TODO
        // https://docs.openzeppelin.com/contracts/4.x/api/token/erc1155
        emit tournamentWinner(ranking[ranking.length - 1]);
    }

    //MATCHS FUNCTIONS
    function matchStart(address _player1, address _player2) public onlyOwner {
        require(match_status == MATCH_STATUS.NOT_STARTED);
        require(tournament_status == TOURNAMENT_STATUS.IN_PROGRESS);
        require(players.length > 1);
        require(_player1 != _player2);
        match_status = MATCH_STATUS.IN_PROGRESS;
        emit matchStartedBetween(_player1, _player2);
    }

    function matchFinished(address _refereeWinner, address _refereeLoser)
        public
        onlyOwner
    {
        require(match_status == MATCH_STATUS.IN_PROGRESS);
        require(tournament_status == TOURNAMENT_STATUS.IN_PROGRESS);
        require(_refereeWinner != _refereeLoser);
        match_status = MATCH_STATUS.FINISHED;
        ranking.push(_refereeLoser);
        emit matchResults(_refereeWinner, _refereeLoser);
    }
}
