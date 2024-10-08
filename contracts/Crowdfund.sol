// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract CrowdFundingEscrow {

    struct Campaign {
        address owner;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
        uint256 fundingTokenSupply; 
        mapping(address => uint256) fundingTokensOwned;
        Milestone[] milestones;
        uint256 currentMilestone;
        mapping(address => mapping(uint256 => bool)) hasVoted;
        mapping(address => mapping(uint256 => bool)) hasInteractedWithMilestone;
        string[] rewards;
        mapping(address => string) receivedRewards;
    }

    struct Milestone {
        string description;
        uint256 targetAmount; 
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVotes;
        bool isComplete;
        uint256 votingEndTime;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public numberOfCampaigns = 0;

    event CampaignCreated(uint256 id, address owner, string title);
    event DonationReceived(uint256 campaignId, address donator, uint256 amount);
    event MilestoneApproved(uint256 campaignId, uint256 milestoneIndex);
    event MilestoneRejected(uint256 campaignId, uint256 milestoneIndex);
    event FundsReleased(uint256 campaignId, uint256 milestoneIndex, uint256 amount);

    function createCampaign(
        address _owner,
        string memory _title,
        string memory _description,
        uint256 _target,
        uint256 _deadline,
        string memory _image,
        uint256 _fundingTokenSupply,
        string[] memory _rewards
    ) public returns (uint256) {
        Campaign storage campaign = campaigns[numberOfCampaigns];
        require(_deadline > block.timestamp, "The deadline must be a date in the future.");
        campaign.owner = _owner;
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;
        campaign.fundingTokenSupply = _fundingTokenSupply;
        campaign.rewards = _rewards;
        numberOfCampaigns++;
        emit CampaignCreated(numberOfCampaigns - 1, _owner, _title);
        return numberOfCampaigns - 1;
    }

    function donateToCampaign(uint256 _id) public payable {
        uint256 amount = msg.value;
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp < campaign.deadline, "The campaign has ended.");
        require(amount > 0, "Donation amount must be greater than zero.");
        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);
        campaign.amountCollected += amount;
        uint256 fundingTokensToGive = (amount * campaign.fundingTokenSupply) / campaign.target;
        campaign.fundingTokensOwned[msg.sender] += fundingTokensToGive;
        assignReward(_id, msg.sender, amount);
        emit DonationReceived(_id, msg.sender, amount);
    }

    function createMilestone(
        uint256 _id,
        string memory _description,
        uint256 _targetAmount,
        uint256 _votingDuration
    ) public {
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.owner, "Only the campaign owner can create milestones.");
        Milestone memory newMilestone;
        newMilestone.description = _description;
        newMilestone.targetAmount = _targetAmount;
        newMilestone.isComplete = false;
        newMilestone.votingEndTime = block.timestamp + _votingDuration;
        campaign.milestones.push(newMilestone);
    }

    function voteOnMilestone(uint256 _id, uint256 _milestoneIndex, bool approve) public {
        Campaign storage campaign = campaigns[_id];
        Milestone storage milestone = campaign.milestones[_milestoneIndex];
        require(block.timestamp < milestone.votingEndTime, "Voting period has ended.");
        require(!campaign.hasVoted[msg.sender][_milestoneIndex], "You have already voted on this milestone.");
        uint256 voterTokens = campaign.fundingTokensOwned[msg.sender];
        require(voterTokens > 0, "You must own funding tokens to vote.");
        if (approve) {
            milestone.votesFor += voterTokens;
        } else {
            milestone.votesAgainst += voterTokens;
        }
        milestone.totalVotes += voterTokens;
        campaign.hasVoted[msg.sender][_milestoneIndex] = true;
        campaign.hasInteractedWithMilestone[msg.sender][_milestoneIndex] = true;
    }

    function finalizeMilestone(uint256 _id) public {
        Campaign storage campaign = campaigns[_id];
        uint256 milestoneIndex = campaign.currentMilestone;
        Milestone storage milestone = campaign.milestones[milestoneIndex];
        require(block.timestamp >= milestone.votingEndTime, "Voting period is still ongoing.");
        require(!milestone.isComplete, "Milestone is already completed.");
        if (milestone.votesFor > milestone.votesAgainst) {
            require(campaign.amountCollected >= milestone.targetAmount, "Not enough funds collected.");
            (bool sent, ) = payable(campaign.owner).call{value: milestone.targetAmount}("");
            require(sent, "Failed to transfer funds to campaign owner.");
            campaign.amountCollected -= milestone.targetAmount;
            milestone.isComplete = true;
            emit FundsReleased(_id, milestoneIndex, milestone.targetAmount);
        } else {
            emit MilestoneRejected(_id, milestoneIndex);
        }
        campaign.currentMilestone++;
    }

    function assignReward(uint256 _id, address _donator, uint256 amount) internal {
        Campaign storage campaign = campaigns[_id];
        if (campaign.rewards.length > 0) {
            if (amount >= 1 ether) {
                campaign.receivedRewards[_donator] = campaign.rewards[0];
            }
        }
    }

    function getDonators(uint256 _id) public view returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function getFundingTokenBalance(uint256 _id, address _donator) public view returns (uint256) {
        return campaigns[_id].fundingTokensOwned[_donator];
    }

    function getCampaign(uint256 _id) public view returns (
        address owner, string memory title, string memory description, uint256 target, uint256 deadline, uint256 amountCollected, string memory image
    ) {
        Campaign storage campaign = campaigns[_id];
        return (campaign.owner, campaign.title, campaign.description, campaign.target, campaign.deadline, campaign.amountCollected, campaign.image);
    }

    function getMilestones(uint256 _id, address _donator) public view returns (Milestone[] memory) {
        Campaign storage campaign = campaigns[_id];
        uint256 totalMilestones = campaign.milestones.length;
        Milestone[] memory relevantMilestones = new Milestone[](totalMilestones);
        uint256 count = 0;

        for (uint256 i = 0; i < totalMilestones; i++) {
            if (campaign.hasInteractedWithMilestone[_donator][i]) {
                relevantMilestones[count] = campaign.milestones[i];
                count++;
            }
        }

        Milestone[] memory finalMilestones = new Milestone[](count);
        for (uint256 j = 0; j < count; j++) {
            finalMilestones[j] = relevantMilestones[j];
        }

        return finalMilestones;
    }
}
