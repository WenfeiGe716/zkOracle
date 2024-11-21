// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./MerkleTree.sol";
import "./AggregationVerifier.sol";
import "./SlashingVerifier.sol";
import "./RWAToken.sol";

contract ZKAudit is MerkleTree, RWAToken {
    AggregationVerifier aggregationVerifier;
    SlashingVerifier slashingVerifier;

    struct Account {
        uint256 index;
        PublicKey pubKey;
        uint256 balance;
    }

    struct PublicKey {
        uint256 x;
        uint256 y;
    }
    address private adminAddress;
    uint256 public exitDelay = 0;

    uint256 public constant AGGREGATOR_REWARD = 500000000000000;
    uint256 public constant VALIDATOR_REWARD = 20000000000;

    uint256 accountNumber = 0;
    mapping(uint256 => address) accounts;
    mapping(address => uint256) exitTimes;

    uint256 nextRequest;
    mapping(uint256 => uint256) requests;
    mapping(uint256 => bytes32) blocks;
    mapping(uint256 => uint) private requestAggregators;

    uint256 seedX;
    uint256 seedY;
    mapping(uint256 => string) ipAddr;

    mapping(address => bool) private blackAddress;

    bytes32[] private illegalBlocks;
    mapping(uint => bool) illegalAggregators;

    mapping(uint => bool) exits;

    event Registered(
        address sender,
        uint256 index,
        PublicKey pubkey,
        uint256 value
    );
    event Replaced(address indexed sender, address indexed replaced);
    event Exiting(address indexed sender);
    event Withdrawn(address indexed sender);

    event BlockRequested(uint256 number, uint256 request);
    event BlockSubmitted(
        uint256 submitter,
        uint256 validators,
        uint256 request
    );

    event Slashed(uint256 index);

    constructor(
        uint256 _levels,
        uint256 _seedX,
        uint256 _seedY,
        uint256 initialSupply,
        address aggregationVerifierAddress,
        address slashingVerifierAddress
    ) MerkleTree(_levels) RWAToken(initialSupply) {
        levels = _levels;
        seedX = _seedX;
        seedY = _seedY;
        aggregationVerifier = AggregationVerifier(aggregationVerifierAddress);
        slashingVerifier = SlashingVerifier(slashingVerifierAddress);
        adminAddress = msg.sender;
    }

    function getBlockByNumber(uint256 number) public onlyRole(DEFAULT_ADMIN_ROLE){
        requests[nextRequest] = number;

        // Set the aggregator corresponding to the request
        uint aggregator = getRandomNumber();
        while (illegalAggregators[aggregator] || exits[aggregator]) {
            aggregator = getRandomNumber();
        }
        requestAggregators[nextRequest] = aggregator;

        emit BlockRequested(number, nextRequest);
        nextRequest += 1;
    }

    function submitBlock(
        uint256 index,
        uint256 request,
        uint256 validators,
        bytes32 blockHash,
        uint256 postStateRoot,
        uint256 postSeedX,
        uint256 postSeedY,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        bool illegal
    ) public {
        require(index == getAggregator(request), "invalid aggregator");
        require(accounts[index] == msg.sender, "invalid index");
        require(blocks[request] == 0, "already submitted");

        blocks[request] = blockHash;

        uint[10] memory input = [
            getRoot(),
            postStateRoot,
            uint256(blockHash),
            request,
            validators,
            index,
            seedX,
            seedY,
            postSeedX,
            postSeedY
        ];
        if (aggregationVerifier.verifyProof(a, b, c, input)) {
            seedX = postSeedX;
            seedY = postSeedY;

            setRoot(postStateRoot);
            emit BlockSubmitted(index, validators, request);
            if (illegal) {
                illegalBlocks.push(blockHash);
            } 
        }
        else {
            illegalAggregators[index] = true;
            emit BlockRequested(request, nextRequest);
            require(
                false,
                "invalid proof"
            );
        }
        
    }

    function slash(
        uint256 slasherIndex,
        uint256 slashedIndex,
        uint256 request,
        uint256 postStateRoot,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c
    ) public {
        require(blocks[request] != 0, "pending request");

        uint[6] memory input = [
            getRoot(),
            postStateRoot,
            uint256(blocks[request]),
            request,
            slasherIndex,
            slashedIndex
        ];

        require(slashingVerifier.verifyProof(a, b, c, input), "invalid proof");

        setRoot(postStateRoot);
        emit Slashed(0);
    }

    function getAggregator(uint256 request) public view returns (uint) {
        return requestAggregators[request];
    }

    function getRandomNumber() public view returns (uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender
        )));
        return (random % accountNumber) + 1;
    }

    function getIPAddress(uint256 index) public view returns (string memory) {
        return ipAddr[index];
    }

    function register(
        PublicKey memory publicKey,
        string memory ip,
        uint256 balance
    ) public payable {
        Account memory account = Account(
            getNextLeafIndex(),
            publicKey,
            balance
        );
        accounts[account.index] = msg.sender;
        accountNumber = accountNumber + 1;
        ipAddr[account.index] = ip;
        uint256 accountHash = hashAccount(account);

        uint[] memory input = new uint[](1);
        input[0] = accountHash;
        uint256 h = MiMC.hash(input);

        insert(h);

        emit Registered(
            msg.sender,
            account.index,
            account.pubKey,
            account.balance
        );
    }

    function replace(
        PublicKey memory publicKey,
        Account memory toReplace,
        uint256 balance,
        uint256[] memory path,
        uint256[] memory helper
    ) public {
        _transfer(msg.sender, adminAddress, balance);
        if (!illegalAggregators[toReplace.index]) {
            require(balance >= toReplace.balance, "value too low");
            require(verify(path, helper), "account not included");
            require(
                path[0] == hashAccount(toReplace),
                "leaf does not match account"
            );
        }

        Account memory replaced = Account(
            toReplace.index,
            publicKey,
            balance
        );

        update(hashAccount(replaced), path, helper);
        _transfer(msg.sender, accounts[toReplace.index], toReplace.balance);
        emit Replaced(msg.sender, accounts[toReplace.index]);
        accounts[toReplace.index] = msg.sender;
    }

    function exit(
        Account memory account,
        uint256[] memory path,
        uint256[] memory helper
    ) public {
        require(accounts[account.index] == msg.sender, "wrong sender address");
        require(path[0] == hashAccount(account), "leaf does not match account");
        require(verify(path, helper), "account not included");
        exits[account.index] = true;
        exitTimes[msg.sender] = block.timestamp + exitDelay;
        emit Exiting(msg.sender);
    }

    function withdraw(
        Account memory account,
        uint256[] memory path,
        uint256[] memory helper
    ) public {
        require(block.number < exitTimes[msg.sender], "time not passed");
        require(accounts[account.index] == msg.sender, "wrong sender address");
        require(path[0] == hashAccount(account), "leaf does not match account");
        require(verify(path, helper), "account not included");

        
        _transfer(adminAddress, msg.sender, account.balance);
        delete accounts[account.index];

        Account memory empty = Account(account.index, account.pubKey, 0);
        update(hashAccount(empty), path, helper);
        emit Withdrawn(msg.sender);
    }

    function hashAccount(Account memory account) public pure returns (uint256) {
        uint[] memory input = new uint[](4);
        input[0] = account.index;
        input[1] = account.pubKey.x;
        input[2] = account.pubKey.y;
        input[3] = account.balance;
        return MiMC.hash(input);
    }

    function getExitTime(address addr) public view returns (uint256) {
        return exitTimes[addr];
    }

    function getSeed() public view returns (uint256, uint256) {
        return (seedX, seedY);
    }

    function getReward() public view returns (uint256) {
        return
            AGGREGATOR_REWARD + (getNextLeafIndex() / 2 + 1) * VALIDATOR_REWARD;
    }

    function getIllegalBlocks() public view onlyRole(DEFAULT_ADMIN_ROLE) returns(bytes32[] memory){
        return illegalBlocks;
    }

    function addBlackAddress(address accountAddress) public onlyRole(DEFAULT_ADMIN_ROLE){
        blackAddress[accountAddress] = true;
    }

    function removeBlackAddress(address accountAddress) public onlyRole(DEFAULT_ADMIN_ROLE){
        blackAddress[accountAddress] = false;
    }
}
