pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/access/SignatureBouncer.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

contract MultiSignatures is SignatureBouncer {

	using SafeMath for uint256;

	mapping(address => uint256) public OperatorsBalance;

	event FundReceived(address from, uint256 amount);

	uint256 public Nonce;
	uint256 public Fee; //TODO
	uint256 public Threshold;
	uint256 public SignerCount;
	uint256 public Votetime;
	uint256 private withdrawBalance;

	/*
		@dev Define access list based on signed arguments
		      keccak(nreq..fee)               
		@param nreq, number of signature for approval
		@param fee, fee based gasLimit (without gas*gasprice) paid to operator
		@param votetime, votetime before a new vote can happen
		@param owners, authorized signers
	*/
	constructor(uint256 nreq, uint256 fee,
				uint256 votetime, address[] owners) public {
		uint256 gasInitial = gasleft();
		require(nreq > 0);
		require(nreq <= owners.length);
		Threshold = nreq;
		Votetime = votetime;
		Fee = fee; //TODO
		Nonce = 0;
		SignerCount = owners.length;
		for (uint256 i = 0; i < owners.length; i++) {
			addBouncer(owners[i]);
		}
		// calculate fee
		assignGasCost(gasInitial);
	}

	/*
		@dev Return spending balance
	*/
	function balance() public view returns (uint256) {
		uint256 _balance = address(this).balance;
		return _balance.sub(withdrawBalance);
	}

	/*
		@dev Assign transaction cost
		@param gasInitial, initial gasleft
	*/
	function assignGasCost(uint256 gasInitial) private {
		uint256 cost = (gasInitial-gasleft())*tx.gasprice;
		// TODO add gas cost of the two following lines
		OperatorsBalance[msg.sender] = OperatorsBalance[msg.sender].add(cost);
		withdrawBalance = withdrawBalance.add(cost);
	}

	/*
		@dev fallback catch all the funds
	*/
	function() public payable {
		emit FundReceived(msg.sender, msg.value);
	}

	struct Votedata {
		address to;
		uint256 gasLimit;
		uint256 value;
		bytes data;
		address executor;
		uint256 endDateVote;
		bytes32 voteHash;
		uint256 count;
		mapping (address => bool) voters;
	}
	mapping (uint256 => Votedata) Votes;
	/*
		@dev Verify operation for setting/unsetting address
		@param to: receiver address
		@param gasLimit: internal gasLimit
		@param value: value sent
		@param data: optional payload data
		@param sigs, signature of web3 "personalSignature" function
		// sig = sign(keccak256(to + gasLimit + [keccak256(data)]))
	*/
	function Vote(address _to, uint256 _gasLimit, uint256 _value, bytes _data, bytes[] sigs) public view {
		bytes memory prefix = "\x19Ethereum Signed Message:\n84"; // 20 + 32 + 32
		bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, _to, _gasLimit, _value /* TODO data*/));
		for (uint256 i = 0; i < sigs.length; i++) {
			address addr = prefixedHash.recover(sigs[i]);
			checkRole(addr, ROLE_BOUNCER);
			if (Votes[Nonce].to != 0x0 || Votes[Nonce].endDateVote < now) {
				Votes[Nonce] = Votedata({
					to: _to,
					gasLimit: _gasLimit,
					value: _value,
					data: _data,
					executor: 0x0,
					voteHash: prefixedHash,
					count: 0,
					endDateVote: Votetime.add(now)
				});
			} else {
				if (Votes[Nonce].voters[addr])
					continue;
			}
			Votes[Nonce].voters[addr] = true;
			Votes[Nonce].count++;
		}
		// TODO Calculate fee for sender
	}

	function extractSigs(bytes sigs) public pure returns (uint256, bytes[]) {
		bytes[] memory addr;
		addr.push("t");
		return (0, addr);
	}

	/*
		@dev SetAddress add or remove address controller to this multisignature contract
		@param nreq, number of signature required to send funds
		@param who, the address to set/unset in this contract
		 // if present, get removed from signer
		 // if not present, set who as new signer
		@param sigs, signature of web3 "personalSignature"
	*/
	function SetAddress(uint256 nreq, address who, bytes[] sigs) public {
		bytes memory prefix = "\x19Ethereum Signed Message:\n20"; // 20 + 1
		bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, who));
		mapping(address => uint256) signers;
		uint256 sigcount;
		for (uint256 i = 0; i < sigs.length; i++) {
			address addr = prefixedHash.recover(sigs[i]);
			checkRole(who, ROLE_BOUNCER);
			if (signers[who])
				continue;
			signers[who] = true;
			sigcount++;
		}
		require(sigcount == SignerCount);
		if (hasRole(who, ROLE_BOUNCER)) {
			require(SignerCount.sub(1) <= nreq);
			SignerCount--;
			removeBouncer(who);
		} else {
			SignerCount++;
			addBouncer(who);
		}
		Threshold = nreq;
		// TODO Calculate fee for sender
	}

	// Spend emit event success or failure
	function execute() public returns (bool) {
		require(Votes[Nonce].count >= Threshold);
		require(Votes[Nonce].endDateVote < now);
		bool result;
		uint256 dataLength = Votes[Nonce].data.length;
		bytes memory data = Votes[Nonce].data;
		uint256 value = Votes[Nonce].value;
		address destination = Votes[Nonce].to;
		assembly {
			let output := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
			let d := add(data, 32) // Exclude 32 bytes which are the padded length of dat
			result := call(
				sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
		// Gcall(700) + Gcallvalue(9000) + Gnewaccount(25000)
				   // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
				   // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
				destination,
				value,
				d,
				dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
				output,
				0                  // Output is ignored, therefore the output size is zero
			)
		}
		return result;
	}
		// Gas cost
	// Suicide
}
