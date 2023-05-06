//SPDX-License-Identifier:MIT

pragma solidity 0.8.0;

contract escrowContract{
    fallback()external payable{
        balances[msg.sender] += msg.value;
    }

    mapping(address=>mapping(address=>bool)) internal isAllowedToWithdraw;
    mapping(address=>mapping(address=>bool)) internal isAllowedToPartialWithdraw;
    mapping(address=>mapping(address=>uint)) internal allowedPartialWithdraw;
    mapping(address=>uint) public balances;
    
    modifier haveEnoughBalance(address _of, uint _amount){
        require(balances[_of] >= _amount,"Not Enough Balance" );
        _;
    }

    function claculate(uint a)public view returns(uint){
        return balances[msg.sender] / a;
    }

    mapping(address=>mapping(bytes32=>address)) private txByteHash;
    mapping(address=>mapping(bytes32=>uint)) public partialTxHashes;
    mapping(bytes32=>address) public transactionHashAddress;
    mapping(bytes32=>address) public transactionBytesOwner;

    function assignPartialWithdrawlAddress(address _of, uint _amount ) public haveEnoughBalance(msg.sender, _amount)  returns(bytes32) {
        assert(!isAllowedToPartialWithdraw[msg.sender][_of]);
        assert(!isAllowedToWithdraw[msg.sender][_of]);
        isAllowedToPartialWithdraw[msg.sender][_of] = true;
        bytes32 txHash =  keccak256(abi.encodePacked(block.timestamp, block.difficulty));
        transactionHashAddress[txHash] = _of;
        uint amount = contractAmount[msg.sender][_of] / _amount;
        partialTxHashes[msg.sender][txHash] = amount;
        transactionBytesOwner[txHash] = msg.sender;
        txByteHash[msg.sender][txHash] = _of;
        isWorkDone[txHash] = false;
        contractAddressReceiver[txHash] = _of;
        onwerOfEscrow[txHash] = msg.sender;
        return txHash;
    }

    modifier isDone(bytes32 txHash){
        require(isWorkDone[txHash],"Not done");
        _;
    }
    modifier onlyReceiver(bytes32 txHash){
        address receiver = contractAddressReceiver[txHash];
        require(contractAddressReceiver[txHash] == msg.sender,"Only Receiver can withdraw funds");
        _;
    }

    function withdrawPartialFunds(bytes32 txHash) public onlyReceiver(txHash) payable  {
        require(txHash.length == 32,"Invalid Signature Length");
        address _owner = onwerOfEscrow[txHash];
        require(partialTxHashes[_owner][txHash] >= 0, "Invalid Transaction");
        uint _amount = partialTxHashes[_owner][txHash];
        address _partialWithdrawl = txByteHash[_owner][txHash];
        payable(_partialWithdrawl).transfer(_amount);
        partialTxHashes[_owner][0]  = 0;
        balances[_owner] -= _amount;
        //onwerOfEscrow[txHash] = _owner;
        contractAmount[_owner][msg.sender] -= _amount;
        balances[_partialWithdrawl] += _amount;
    }

    function withdrawAllFunds(bytes32 txHash, bytes memory _sig) public eligibleToWithdrawFunds(txHash) onlyReceiver(txHash) isDone(txHash) payable{
        require(verifyTransactions(_sig,txHash),"Not Elligible");
        address receiver = transactionHashAddress[txHash];
        address _onwer = transactionBytesOwner[txHash];
        uint amount = contractAmount[_onwer][receiver];
        payable(receiver).transfer(amount);
        balances[receiver] += amount;
        isReceiverWithdrawed[txHash][receiver] = true;
    }

    function checkAllDone(bytes32 txHash) public onlyContractOwner(txHash) allDone(txHash){
        contractDone[txHash] = true;
    }
    modifier eligibleToWithdrawFunds(bytes32 txHash){
        require(contractDone[txHash],"Onwers havn't set the contract done");
        _;
    }

    modifier onlyContractOwner(bytes32 txHash){
        require(onwerOfEscrow[txHash] == msg.sender,"Only Onwers can do that");
        _;
    }

    modifier allDone(bytes32 txHash){
        require(contractDone[txHash] == false,"All done");
        _;
    }

    mapping(bytes32=>bool) private contractDone;
    mapping(bytes32=>mapping(address=>bool)) private isReceiverWithdrawed;

    function checkWork(bytes32 txHash) public onlyReceiver(txHash) {
        isWorkDone[txHash] = true;
    }

    mapping(bytes32=>address) private contractAddressReceiver;
    mapping(address=>mapping(address=>uint)) private contractAmount;

    function assignTransaction(address _of, uint _amount) public {
        require(balances[msg.sender] >= _amount,"Not Enough Balance");
        contractAmount[msg.sender][_of] = _amount;
    }

    function getEthSignedMessage(bytes32 _txHash) public pure returns(bytes32){
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",_txHash));
    }

    mapping(bytes32=>bytes) private bytesMap;

    function verifyTransactions(bytes memory _sig, bytes32 txHash) public view returns(bool){
        bytes32 ethSignedMessageHash = getEthSignedMessage(txHash);
        address _onwer = transactionBytesOwner[txHash];
        //bytesMap[txHash] = _sig;
        return recover(ethSignedMessageHash,_sig) == _onwer;
    }

    function recover(bytes32 ethSignedMessage, bytes memory _sig) public pure returns(address){
        (bytes32 r, bytes32 s, uint8 v) = split(_sig);
        return ecrecover(ethSignedMessage, v,r,s);
    }

    function split(bytes memory _sig) public pure returns(bytes32 r, bytes32 s , uint8 v){
        require(_sig.length == 65,"Invalid Length");
        assembly{
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            v := byte(0,mload(add(_sig, 96)))
        }
    }

    mapping(bytes32=>bool)private isWorkDone;


    //0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
    //0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    //0x6672495182b30cffe27b8e6f92ba6d538c8f5b1923222025b2d5e9585d86f373
    

    mapping(bytes32=>address) private onwerOfEscrow;

    

    function viewAddress(bytes32 txHash, address _owner) internal returns(address){
        address _partialWithdrawl = txByteHash[_owner][txHash];
        return _partialWithdrawl;
    }

    function getTransactionHash() public view returns (bytes32) {
       return blockhash(block.number);
    }


}