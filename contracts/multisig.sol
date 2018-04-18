pragma solidity ^0.4.22;

import "./SafeMath.sol";

contract MultiSignatures {

	using SafeMath for uint;

	mapping(address => bool) public Allowed;

	uint fee;
	uint feeBalance;

	/*
		@dev Define access list based on signed arguments
		      keccak(nreq..fee)               
		@param nreq, number of signature for approval
		@param fee, fee based gasLimit (without gas*gasprice)
		@param v, v part of web3 "personalSignature"
		@param r, r part of web3 "personalSignature"
		@param s, s part of web3 "personalSignature"
	*/
	function constructor(uint nreq, uint fee, uint8[] v, bytes32[] r, bytes32[] s) {
		require(v.length == r.length &&
			    v.length == s.length &&
			    v.length > 0);
		bytes memory prefix = "\x19Ethereum Signed Message:\n64";
		bytes32 prefixedHash = keccak256(prefix, nreq, fee);
		for (uint i = 0; i < v.length; i++) {
			address addr = ecrecover(prefixedHash, v[i], r[i], s[i]);
			require(addr != 0x0);
			Allowed[addr] = true;
		}
	}
	// Register addresses
	// Spend emit event success or failure
	// Suicide
}
