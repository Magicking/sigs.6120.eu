pragma solidity ^0.4.22;

import 'zeppelin-solidity/contracts/access/SignatureBouncer.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

uint256 constant public FREE_POINTER = 0x40; //

contract MultiSignatures is SignatureBouncer {

	using SafeMath for uint256;

	enum Operation { OP_CALL, OP_ADD, OP_DEL };

	mapping(address => uint256) public OperatorsBalance;

	event FundReceived(address from, uint256 amount);

	uint256 public Nonce;
	uint256 public Fee;
	uint256 private withdrawBalance;
	uint256 public Threshold;

	/*
		@dev Define access list based on signed arguments
		      keccak(nreq..fee)               
		@param nreq, number of signature for approval
		@param fee, fee based gasLimit (without gas*gasprice) paid to operator
		@param owners, authorized signers
	*/
	constructor(uint256 nreq, uint256 fee,
						 address[] owners) public {
		uint256 gasInitial = gasleft();
		require(nreq > 0);
		require(nreq <= owners.length);
		Threshold = nreq;
		Fee = fee;
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
		return this.balance.sub(withdrawBalance);
	}

	/*
		@dev Assign transaction cost
		@param gasInitial, initial gasleft
	*/
	function assignGasCost(uint256 gasInitial) private {
		uint256 memory cost = (gasInit-gasleft())*tx.gasprice;
		// TODO add gas cost of the two following lines
		OperatorsBalance[msg.sender] = OperatorsBalance[msg.sender].add(cost);
		withdrawBalance = withdrawBalance.add(cost);
	}

	/*
		@dev fallback catch all the funds
	*/
	fallback() public payable {
		emit FundReceived(msg.sender, msg.value);
	}

	/*
		@dev Verify operation for setting/unsetting address
		@param data:
			   0 ->  32 length field
			op, Send / Add / Del operation
			  32 ->  64 operation number (0: SEND, 1: ADD, 2: DEL)
			  64 ->  96 address
			Send:
			  96 -> 128 value
			 128 -> 160 data TODO
		@param sig, signature of web3 "personalSignature" function
	*/
	function Vote(Operation op, bytes data, bytes[] sigs) public view returns (bool) {
		bytes memory prefix = "\x19Ethereum Signed Message:\n21";
		bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, uint256(op), who));
		uint256 count = 0;/*
		for (uint256 i = 0; i < sigs.length; i++) {
			address addr = prefixedHash.recover(sigs[i]);
			if (Allowed[addr]) {
				count++;
			}                           TODO
			if (count == Threshold)
				return true;
		}*/
		return false;
	}

	/*
		@dev SetAddress add or remove address controller to this multisignature contract
		@param set, if true, operation is setting address,
			otherwise is a removing operation
		@param who, the address to set/unset in this contract
		@param v, v part of web3 "personalSignature"
		@param r, r part of web3 "personalSignature"
		@param s, s part of web3 "personalSignature"
	*/
	function SetAddress(bool set, address who, uint2568[] v, bytes32[] r, bytes32[] s) public {
		require(VerifySet(set, who, v, r, s));
		if (set && !Allowed[who]) {
			Allowed[who] = true;
			Owners++;
		}
		if (!set && Allowed[who]) {
			require(Owners > 1, "At least one owner is required");
			delete Allowed[who];
			Owners--;
		}
		// Calculate fee for sender
	}

	// Spend emit event success or failure
	function execute(address destination, uint256 value, uint256 dataLength, bytes data) private returns (bool) {
		bool result;
		assembly {
			let output := mload(FREE_POINTER)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
			let dataLength := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
			result := call(
				sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
		// Gcall(700) + Gcallvalue(9000) + Gnewaccount(25000)
				   // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
				   // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
				destination,
				value,
				d,
				dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
				x,
				0                  // Output is ignored, therefore the output size is zero
			)
		}
		return result;
	}
		// Gas cost
	// Suicide
}
