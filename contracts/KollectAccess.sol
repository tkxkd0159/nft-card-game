// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract KollectAccess{
	// ceo: ceo setups the rules of the system and control accessibility
	address ceo = address(0);

	modifier validAddr(address addr) {
		require(addr != address(0), "address empty");
		_;
	}	

	modifier isCEO {
		require(msg.sender != address(0), "address empty");
		require(msg.sender == ceo || ceo == address(0), "you are not CEO");
		_;
	}

	constructor(){
		ceo = msg.sender;
	}

	function setCEO(address newceo) public isCEO{
		require(ceo == address(0) || newceo != address(0), "invalid input");
		ceo = newceo;
	}

	function getCEO() public view returns(address) {
		return ceo;
	}
}