pragma solidity ^0.4.22;

import "./SafeMath.sol";

uint constant public FREE_POINTER = 0x40; //

contract MultiSignatures {

	using SafeMath for uint;

	uint public Owners;
	uint public Threshold;
	mapping(address => bool) public Allowed;
	mapping(address => uint) public OperatorsBalance;

	event FundReceived(address from, uint amount);

	uint public Nonce;

	/*
		@dev Define access list based on signed arguments
		      keccak(nreq..fee)               
		@param nreq, number of signature for approval
		@param fee, fee based gasLimit (without gas*gasprice) paid to operator
		@param v, v part of web3 "personalSignature"
		@param r, r part of web3 "personalSignature"
		@param s, s part of web3 "personalSignature"
	*/
	constructor(uint nreq, uint fee
						 uint8[] v, bytes32[] r, bytes32[] s) public {
		require(v.length == r.length &&
				v.length == s.length &&
				v.length > 0);
		require(nreq <= v.length);
		bytes memory prefix = "\x19Ethereum Signed Message:\n64";
		bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, nreq, fee));
		for (uint i = 0; i < v.length; i++) {
			address addr = ecrecover(prefixedHash, v[i], r[i], s[i]);
			require(addr != 0x0);
			Allowed[addr] = true;
		}
		Owners = v.length;
		Threshold = nreq;
		// calculate fee
	}

	/*
		@dev Fallback catch all the funds
	*/
	fallback() public payable {
		emit FundReceived(msg.sender, msg.value);
	}

	/*
		@dev Verify operation for setting/unsetting address
		@param set, if true, operation is setting address,
			otherwise is a removing operation
		@param who, the address to set/unset in this contract
		@param v, v part of web3 "personalSignature"
		@param r, r part of web3 "personalSignature"
		@param s, s part of web3 "personalSignature"
	*/
	// TODO Factorize
	function VerifySet(bool set, address who, uint8[] v, bytes32[] r, bytes32[] s) public view returns (bool) {
		bytes memory prefix = "\x19Ethereum Signed Message:\n21";
		byte operation = set ? 0x1 : 0x0; // TODO use bool directly ?
		bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, operation, who));
		uint count = 0;
		for (uint i = 0; i < v.length; i++) {
			address addr = ecrecover(prefixedHash, v[i], r[i], s[i]);
			if (Allowed[addr]) {
				count++;
			}
			if (count == Threshold)
				return true;
		}
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
	function SetAddress(bool set, address who, uint8[] v, bytes32[] r, bytes32[] s) public {
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
	function execute(address destination, uint value, uint dataLength, bytes data) private returns (bool) {
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
