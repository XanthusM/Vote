// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract Vote {
    address public owner;
    mapping (uint => Candidate) public candidates;
    uint prizeAmount;
    uint votingId;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event AddVotingCandidate(uint votingId, address candidates);
    event VotingCreated(uint votingId);

    constructor(address[] memory candidates) {
    finishAt = block.timestamp + 3 days;
    }

    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        uint proposalIndex;   // index of the voted proposal 
    }


    struct Candidate {
        uint id;
        string name;
        uint totalVotes;
    }


    function createVoting(address[] memory candidates) external onlyOwner {
    votingId = ++lastVotingId;
    require(votingFinishAt[votingId] == 0, "already exists");
    votingFinishAt[votingId] = block.timestamp + 3 days;
    require(candidates.length > 0, "empty array");
    mapping(address => bool) storage _candidates = votingCandidates[votingId];
    for (uint i = 0; i < candidates.length; i++) {
        _candidates[candidates[i]] = true;
        emit AddVotingCandidate(votingId, candidates[i]);
    }
    emit VotingCreated(votingId);
}


    function vote(uint proposal) public payable{  
        Voter storage sender = voters[msg.sender];
        require(block.timestamp < finishAt, "already finished");
        require(msg.value == 1e18 / 100);  // 0.01 eth
        require(!sender.voted, "Already voted");
        require(msg.value >= 0.01 ether, "SMALL_ETH"); 
        sender.voted = true;
        sender.proposalIndex = proposal;

        prizeAmount += msg.value;
    }


    function finalize(votingId) public view returns (uint winnerVoteId_, uint candidateId) {
        uint winningVoteCount = 0;
        for (uint p = 0; p < candidates.length; p++) {  
            if (candidates[p].voteCount > winningVoteCount) {
                winningVoteCount = candidates[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    function winnerVote(uint winnerVoteId_) public onlyOwner {
        winnerVoteId_ = Candidate[finalize(votingId)];
        payable(owner).call{value: prizeAmount/100 * 10}();
    }

    function withdrawFee() public onlyOwner {
        uint comissions = prizeAmount/100*10;
        owner.transfer(comissions);
    }
    
    function showCandidate() public view returns(address[] memory) {
        return candidates;
    }
}

//понимаю, что контракт почти нерабочий. пока писал его так запутался и отклонился от тз, что пришлось всё переосмыслять и переписывать, по этой же причине нет 
//и тестов. звучит так себе, но совсем ничего не прислать было бы худшим решением. очень хочу попасть в вашу академию. если каким-то чудом вы меня примете, 
//клянусь все два месяца выкладываться как только могу.