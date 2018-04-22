pragma solidity ^0.4.22;

import "./SafeMath.sol";

contract MultiSignatures {

	using SafeMath for uint;

	uint public Owners;
	uint public Threshold;
	mapping(address => bool) public Allowed;
	mapping(address => uint) public OperatorsBalance;

	uint fee;
	uint feeBalance;

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
	function VerifySet(bytes32 signedHash, bool set, address who, uint8[] v, bytes32[] r, bytes32[] s) public view returns (bool) {
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

	// Set addresses
	// Fallback
	// Spend emit event success or failure
	// Suicide
}
