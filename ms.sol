// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;


contract MultisigWallet {

    struct Transaction {
        uint id;
        bytes data;
        bool executed;
    }

    address public governedContract;

    mapping (uint => Transaction) public transactions;

    mapping (uint => mapping (address => bool)) public confirmations;

    mapping (address => bool) public isOwner;

    address[] public owners;

    uint public required;

    uint public transactionCount;

    uint constant public MAX_OWNER_COUNT = 100;


    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revocation(address indexed sender, uint indexed transactionId);
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);


    constructor(address[] memory _owners, address _contract, uint256 _required)  {
        require((_owners.length <= MAX_OWNER_COUNT && _owners.length >= 0), "Invalid owners amount");
        require((_required > 0 && _required <= _owners.length), "Invalid amount of required confirmations");

        for (uint i=0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]] && _owners[i] != address(0));
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
        governedContract = _contract;
    }

    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].id != 0);
        _;
    }

    modifier confirmed(uint transactionId, address owner) {
        require(confirmations[transactionId][owner]);
        _;
    }

    modifier notConfirmed(uint transactionId, address owner) {
        require(!confirmations[transactionId][owner]);
        _;
    }

    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed);
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner]);
        _;
    }


    function submitTransaction(bytes memory data) public returns (uint transactionId)
    {
        transactionId = addTransaction(data);
        confirmTransaction(transactionId);
    }


    function confirmTransaction(uint transactionId) public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
    }


    function revokeConfirmation(uint transactionId)
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }


    function executeTransaction(uint transactionId)
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        if (isConfirmed(transactionId)) {
            (bool success, ) = governedContract.call{value: 0}(transactions[transactionId].data);
            require(success, "Transaction execution reverted.");
            emit Execution(transactionId);
            transactions[transactionId].executed = true;
        }
    }



    function isConfirmed(uint transactionId) public view returns (bool)
    {
        uint count = 0;
        for (uint i = 0; i<owners.length; i++) {
            if (confirmations[transactionId][owners[i]])
                count += 1;
        }
        if (count == required) {
            return true;
        }  else {
            return false;
        }
    }


    function addTransaction(bytes memory _data) internal returns (uint transactionId)
    {
        transactionCount++;
        Transaction memory txn = Transaction({
                                    id: transactionCount,
                                    data: _data,
                                    executed: false
                                });


        transactions[transactionCount] = txn;
        emit Submission(transactionCount);
        return transactionCount;
    }


    function getConfirmationCount(uint transactionId) public view returns (uint)
    {
        uint count = 0;
        for (uint i=0; i<owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) {
                count += 1;
            }
        }
        return count;

    }


    function getOwners() public view returns (address[] memory)
    {
        address[] memory result = new address[](owners.length);
        for (uint i = 0; i< owners.length; i++) {
            result[i] = owners[i];
        }
        return result;
    }


    function getConfirmations(uint transactionId) public view returns (address[] memory _confirmations)
    {
        address[] memory confirmationsTemp = new address[](owners.length);
        uint count = 0;
        uint i;
        for (i=0; i<owners.length; i++)
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        _confirmations = new address[](count);
        for (i=0; i<count; i++)
            _confirmations[i] = confirmationsTemp[i];
    }

}



