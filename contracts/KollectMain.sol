// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./KollectAccess.sol";
import "./KollectPack.sol";
import "./KollectCard.sol";
import "./KLT.sol";

// defining cross-module actions
contract Kollect is KollectAccess, KLT {
	// modules
	// KLT klt;
	KollectCard kc;
	KollectPack kp;

	constructor(address kc_a,
			    address kp_a
			    ) KLT() {
		ceo = msg.sender;
		kc = KollectCard(kc_a); // maybe not required
		kp = KollectPack(kp_a);	
		kp.setMain(address(this));	
	}

	// buy pack by eth
	function buyPack_eth(address payable buyer, uint16 rid, uint32 amount) public payable 
		validAddr(buyer) {
		
		require(kp.checkStock(rid, amount));
		uint32 total = kp.getTotal(rid, amount);
		require(msg.value == total); // enough ether?
		require(vault.send(msg.value)); // send ether to CEO
		kp.sendPack(buyer, rid, amount);
	}

	//buy pack by KLT:
	function buyPack_klt(uint16 rid, uint32 amount) public 
		 validAddr(msg.sender) {

		require(kp.checkStock(rid, amount));
		uint32 total = kp.getTotal(rid, amount);
		transfer(address(this), total);	// send KLT to vault
		kp.sendPack(msg.sender, rid, amount);
	}

	// buy pack by cash:
	//  * cash tx is not managed by Dapp; Just call this function to update status
	function reportPackBuy(address buyer, uint16 rid, uint32 amount) public 
		 validAddr(buyer) {

		require(kp.checkStock(rid, amount));
		kp.sendPack(buyer, rid, amount);
	}	

	// sell(redeem) cards
	function redeem(uint256[] calldata cids) external 
		 validAddr(msg.sender) {
		uint amount = 0;
		uint l = cids.length;
		for(uint i=0; i<l; i++){
			amount += kc.getRedeemValue(cids[i]);			
		}
		kc.burnCards(cids, msg.sender);
		issue(amount);
	}
}