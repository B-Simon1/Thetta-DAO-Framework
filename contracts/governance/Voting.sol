pragma solidity ^0.4.22;

import '../IDaoBase.sol';
import './IVoting.sol';
import './IProposal.sol';
import '../tokens/StdDaoToken.sol';
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract Voting is IVoting, Ownable {
	IDaoBase dao;
	IProposal proposal; 

	uint public minutesToVote;
	bool finishedWithYes;
	bool canceled = false;
	uint64 genesis;
	uint public quorumPercent;
	uint public consensusPercent;

	address tokenAddress;
	uint votingID;	
	string groupName;

	struct Vote{
		address voter;
		bool isYes;
	}

	mapping(address=>bool) voted;
	mapping(uint=>Vote) votes;

	uint votesCount = 0;
	VotingType votingType;

	event Voted(address _who, bool _yes);
	event CallAction();

	enum VotingType{
		Membership,
		Token_Simple,
		Token_Quadratic,
		Token_Liquid
	}

	/*
	 * @param _dao – DAO where proposal was created.
	 * @param _proposal – proposal, which create vote.
	 * @param _origin – who create voting (group member).
	 * @param _minutesToVote - if is zero -> voting until quorum reached, else voting finish after minutesToVote minutes
	 * @param _quorumPercent - percent of group members to make quorum reached. If minutesToVote==0 and quorum reached -> voting is finished
	 * @param _consensusPercent - percent of voters (not of group members!) to make consensus reached. If consensus reached -> voting is finished with YES result
	 * @param _votingType
	 * @param _groupName
	 * @param _tokenAddress
	*/
	constructor(IDaoBase _dao, IProposal _proposal, 
		address _origin, uint _minutesToVote,
		uint _quorumPercent, uint _consensusPercent, VotingType _votingType,
		string _groupName, address _tokenAddress
		) public 
	{
		require((_quorumPercent<=100)&&(_quorumPercent>0));
		require((_consensusPercent<=100)&&(_consensusPercent>0));

		dao = _dao;
		proposal = _proposal;
		minutesToVote = _minutesToVote;
		quorumPercent = _quorumPercent;
		consensusPercent = _consensusPercent;
		groupName = _groupName;
		votingType = _votingType;
		genesis = uint64(now);	

		_vote(_origin, true);
	}

	function getVotersTotal() view returns(uint){
		if(VotingType.Membership==votingType){
			return dao.getMembersCount(groupName);

		}else if(VotingType.Token_Simple==votingType){
			return StdDaoToken(tokenAddress).totalSupply();

		}else if(VotingType.Token_Quadratic==votingType){
			return StdDaoToken(tokenAddress).getVotingTotalForQuadraticVoting();

		}else{
			revert();
		}
	}

	function getVoterPower(address _voter) view returns(uint){
		if(VotingType.Membership==votingType){
			require(dao.isGroupMember(groupName, _voter));
			return 1;

		}else if(VotingType.Token_Simple==votingType){
			return StdDaoToken(tokenAddress).getBalanceAtVoting(votingID, _voter);
		
		}else if(VotingType.Token_Quadratic==votingType){
			return _sqrt(StdDaoToken(tokenAddress).getBalanceAtVoting(votingID, _voter));
		
		}else{
			revert();
		}
	}

	function _sqrt(uint x) internal pure returns (uint y) {
		uint z = (x + 1) / 2;
		y = x;
		while (z < y) {
			y = z;
			z = (x / z + z) / 2;
		}
	}

	function vote(bool _isYes) public {
		require(!isFinished());
		require(!voted[msg.sender]);
		_vote(msg.sender, _isYes);
	}

	function _vote(address _voter, bool _isYes) internal {
		votes[votesCount] = Vote(_voter, _isYes);
		voted[_voter] = true;
		emit Voted(_voter, _isYes);
		votesCount += 1;
		callActionIfEnded();
	}

	function callActionIfEnded() public {
		if(!finishedWithYes && isFinished() && isYes()){ 
			// should not be callable again!!!
			finishedWithYes = true;
			emit CallAction();
			proposal.action(); // can throw!
		}
	}

	function isFinished() public view returns(bool){
		if(canceled){
			return true;
		
		}else if(minutesToVote!=0){
			return _isTimeElapsed();
		
		}else if(finishedWithYes){
			return true;
		
		}else{
			return _isQuorumReached();
		}
	}

	function _isTimeElapsed() internal view returns(bool){
		if(minutesToVote==0){
			return false;
		}

		return (uint64(now) - genesis) >= (minutesToVote * 60 * 1000);
	}

	function _isQuorumReached() internal view returns(bool){
		uint yesResults = 0;
		uint noResults = 0;
		uint votersTotal = 0;

		(yesResults, noResults, votersTotal) = getVotingStats();
		return ((yesResults + noResults) * 100) >= (votersTotal * quorumPercent);
	}

	function _isConsensusReached() internal view returns(bool){
		uint yesResults = 0;
		uint noResults = 0;
		uint votersTotal = 0;

		(yesResults, noResults, votersTotal) = getVotingStats();
		return (yesResults * 100) >= ((yesResults + noResults) * consensusPercent);
	}

	function isYes() public view returns(bool){
		if(true==finishedWithYes){
			return true;
		}
		return !canceled&& isFinished()&& 
			_isQuorumReached()&& _isConsensusReached();
	}

	function getVotingStats() public constant returns(uint yesResults, uint noResults, uint votersTotal){
		for(uint i=0; i<votesCount; ++i){
			if(votes[i].isYes){
				yesResults+= getVoterPower(votes[i].voter);
			}else{
				noResults+= getVoterPower(votes[i].voter);
			}		
		}
		votersTotal = getVotersTotal();	
		return;
	}

	function cancelVoting() public onlyOwner {
		canceled = true;
	}	
}


// --------------------- IMPLEMENTATIONS ---------------------

/*contract Voting_1p1v is Voting {
	string groupName;
	constructor(IDaoBase _dao, IProposal _proposal, 
		address _origin, uint _minutesToVote,
		uint _quorumPercent, uint _consensusPercent, 
		string _groupName) public 
	Voting(_dao, _proposal, _origin, _minutesToVote, _quorumPercent, _consensusPercent)
	{
		_generalConstructor(_dao,  _proposal, _origin,  _minutesToVote, _quorumPercent,  _consensusPercent);
		groupName = _groupName;
		_vote(_origin, true);
	}

	function getVotersTotal() view returns(uint){
		if(VotingType.1P1V==votingType){
			return dao.getMembersCount(groupName);

		}else if(VotingType.Token_Simple==votingType){
			return StdDaoToken(tokenAddress).totalSupply();

		}else if(VotingType.Token_Quadratic==votingType){
			return StdDaoToken(tokenAddress).getVotingTotalForQuadraticVoting();

		}else{
			revert();
		}
	}

	function getVoterPower(address _voter) view returns(uint){	
		if(VotingType.1P1V==votingType){
			require(dao.isGroupMember(groupName, _voter));
			return 1;

		}else if(VotingType.Token_Simple==votingType){
			uint tokenAmount = StdDaoToken(tokenAddress).getBalanceAtVoting(votingID, _voter);
			return tokenAmount;
		
		}else if(VotingType.Token_Quadratic==votingType){
			uint tokenAmount = StdDaoToken(tokenAddress).getBalanceAtVoting(votingID, _voter);
			return sqrt(tokenAmount);
		
		}else{
			revert();
		}
	}

	function sqrt(uint x) internal pure returns (uint y) {
		uint z = (x + 1) / 2;
		y = x;
		while (z < y) {
			y = z;
			z = (x / z + z) / 2;
		}
	}
}

contract Voting_SimpleToken is Voting {
	address tokenAddress;
	uint votingID;
	constructor(IDaoBase _dao, IProposal _proposal, 
		address _origin, uint _minutesToVote,
		uint _quorumPercent, uint _consensusPercent, 
		address _tokenAddress) public 
	Voting(_dao, _proposal, _origin, _minutesToVote, _quorumPercent, _consensusPercent)
	{
		_generalConstructor(_dao,  _proposal, _origin,  _minutesToVote, _quorumPercent,  _consensusPercent);
		tokenAddress = _tokenAddress;
		votingID = StdDaoToken(_tokenAddress).startNewVoting();		
		_vote(_origin, true);
	}

	function getVotersTotal() view returns(uint){
		return StdDaoToken(tokenAddress).totalSupply();
	}

	function getVoterPower(address _voter) view returns(uint){
		uint tokenAmount = StdDaoToken(tokenAddress).getBalanceAtVoting(votingID, _voter);
		return tokenAmount;
	}
}

contract Voting_Quadratic is Voting {
	address tokenAddress;
	uint votingID;	
	constructor(IDaoBase _dao, IProposal _proposal, 
		address _origin, uint _minutesToVote,
		uint _quorumPercent, uint _consensusPercent, 
		address _tokenAddress) public 
	Voting(_dao, _proposal, _origin, _minutesToVote, _quorumPercent, _consensusPercent)
	{
		_generalConstructor(_dao,  _proposal, _origin,  _minutesToVote, _quorumPercent,  _consensusPercent);
		tokenAddress = _tokenAddress;
		votingID = StdDaoToken(_tokenAddress).startNewVoting();
		_vote(_origin, true);
	}

	function getVotersTotal() view returns(uint){
		return StdDaoToken(tokenAddress).getVotingTotalForQuadraticVoting();
	}

	function getVoterPower(address _voter) view returns(uint){
		uint tokenAmount = StdDaoToken(tokenAddress).getBalanceAtVoting(votingID, _voter);
		return sqrt(tokenAmount);
	}

	function sqrt(uint x) internal pure returns (uint y) {
		uint z = (x + 1) / 2;
		y = x;
		while (z < y) {
			y = z;
			z = (x / z + z) / 2;
		}
	}
}*/