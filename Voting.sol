// SPDX-License-Identifier: NONE
pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract Votings is Ownable {
    using Address for address;
    using Address for address payable;

    struct Voting {  // there is a place for pack optimisation if necessary https://dev.to/javier123454321/solidity-gas-optimizations-pt-3-packing-structs-23f4
        uint256 finishAt;
        mapping(address /* candidate */ => bool /* is candidate */) isCandidate;  // maybe use EnumerableSet if enumerable is needed
        mapping(address /* candidate */ => uint256 /* votes */) candidateVotes;
        mapping(address /* voter */ => bool /* voted */) isVoted;
        bool finalized;
        bool rewardWithdrawn;  // it's dangerous to process transfer inside finalization because contract may deny any transfer
        uint256 reward;
        uint256 winningVotes;
        address winningCandidate;
    }
    mapping (uint256 => Voting) internal _votings;
    uint256 public accumulatedFee;
    uint256 internal _lastVotingId;
    uint256 constant internal VOTING_DURATION = 3 days;
    uint256 constant internal VOTING_PRICE = 1 ether / 100;
    uint256 constant internal FEE_NUMERATOR = 10;
    uint256 constant internal FEE_DENOMINATOR = 100;
    event VotingCandidateAdded(uint256 indexed votingId, address indexed candidate);
    event Voted(address indexed voter, uint256 indexed votingId, address indexed candidate);
    event Finalized(uint256 indexed votingId, address indexed winner, uint256 reward);
    event RewardWithdrawn(uint256 indexed votingId, address indexed winner, address to, uint256 amount);
    event FeeWithdrawn(address indexed to, uint256 amount);
    constructor() {}
    function votingInfo(uint256 votingId) external view returns(
        uint256 finishAt,
        bool finalized,
        bool rewardWithdrawn,
        uint256 reward,
        uint256 winningVotes,
        address winningCandidate
    ) {
        Voting storage _voting = _votings[votingId];
        require(_voting.finishAt > 0, "not exists");
        finishAt = _voting.finishAt;
        finalized = _voting.finalized;
        rewardWithdrawn = _voting.rewardWithdrawn;
        reward = _voting.reward;
        winningVotes = _voting.winningVotes;
        winningCandidate = _voting.winningCandidate;
    }
    function createVoting(address[] memory candidates) external returns(uint256 votingId) {
        require(candidates.length > 0, "empty array");
        votingId = ++_lastVotingId;
        Voting storage _voting = _votings[votingId];
        _voting.finishAt = block.timestamp + 3 days;
        for (uint256 i = 0; i < candidates.length; i++) {
            address candidate = candidates[i];
            require(candidate != address(0), "zero address");
            _voting.isCandidate[candidate] = true;
            emit VotingCandidateAdded(votingId, candidate);
        }
    }
    function vote(uint256 votingId, address candidate) external payable {
        Voting storage _voting = _votings[votingId];
        require(_voting.finishAt > 0, "voting not exists");
        require(block.timestamp < _voting.finishAt, "already finished");
        require(!_voting.isVoted[msg.sender], "already voted");
        _voting.isVoted[msg.sender] = true;
        require(msg.value == VOTING_PRICE, "wrong ether value");
        require(_voting.isCandidate[candidate], "wrong candidate");
        _voting.reward += VOTING_PRICE;
        uint256 _votes = ++_voting.candidateVotes[candidate];
        if (_votes > _voting.winningVotes) {
            _voting.winningVotes = _votes;
            _voting.winningCandidate = candidate;
        }
        emit Voted(msg.sender, votingId, candidate);
    }
    function finalize(uint256 votingId) external {
        Voting storage _voting = _votings[votingId];
        require(_voting.finishAt > 0, "voting not exists");
        require(block.timestamp >= _voting.finishAt, "not finished");
        require(!_voting.finalized, "already finalized");
        _voting.finalized = true;
        accumulatedFee += _voting.reward * FEE_NUMERATOR / FEE_DENOMINATOR;
        emit Finalized(votingId, _voting.winningCandidate, _voting.reward);
    }
    function withdrawReward(uint256 votingId, address to) external {
        Voting storage _voting = _votings[votingId];
        require(_voting.finishAt > 0, "voting not exists");
        require(block.timestamp >= _voting.finishAt, "not finished");
        require(_voting.finalized, "not finalized");
        uint256 fee = _voting.reward * FEE_NUMERATOR / FEE_DENOMINATOR;
        uint256 toTransfer = _voting.reward - fee;
        require(!_voting.rewardWithdrawn, "reward already withdrawn");
        require(_voting.winningCandidate == msg.sender, "not winner");
        _voting.rewardWithdrawn = true;
        emit RewardWithdrawn(votingId, msg.sender, to, toTransfer);
        payable(to).sendValue(toTransfer);
    }
    function withdrawFee(address to) external onlyOwner {
        uint256 toTransfer = accumulatedFee;
        accumulatedFee = 0;
        emit FeeWithdrawn(to, toTransfer);
        payable(to).sendValue(toTransfer);
    }
}