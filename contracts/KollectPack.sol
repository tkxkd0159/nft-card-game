// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./KollectAccess.sol";

/*
 --------- data types -----------
 release ID 			: uint16  
 release price 			: uint16
 design ID 				: uint16
 card ID 				: uint32 
 card/release count 	: uint32
 --------------------------------
*/

contract KollectPack is KollectAccess {

	/* ----- access control ----- */

	// mainAddr: contract address of 'Kollect' contract
	// Kollect's call is only accepted for some functions

	address mainAddr;
	modifier byMain{
		require(msg.sender == mainAddr);
		_;
	}
	function setMain(address _mainAddr) external {
		// set once, and not thereafter
		require(mainAddr == address(0), "mainAddr already set");		
		mainAddr = _mainAddr;
	}

	// packPublishers: pack publisher releases a definite number of packs
	mapping(address => bool) packPublishers;
	modifier isPackPublisher{
		require(packPublishers[msg.sender] == true);
		_;
	}	
	function addPackPublisher(address newaddr) external isCEO validAddr(newaddr) {
		packPublishers[newaddr] = true;
	}
	
	/* -------------------------- */

	struct Release{
		uint16 price;
		uint32 stock;
		uint32 seed;
		uint16[] designs; // dids the release contains
	}
	Release[] releases;
	
	// owner : release : remaining pack count	
	mapping (address => mapping(uint16 => uint32)) owner_rel_pack;
	
	// for prng
	uint32 master_seed;

	constructor() KollectAccess() {		
		packPublishers[ceo] = true;

		// master seed obtained from recent block hash
		// master_seed = uint32(uint(blockhash(3)) & 0xffffff);	//it returns 0;
		master_seed = 79;
	}

	function getSeed() internal returns(uint32){
		master_seed *= 3;
		master_seed %= 101;
		return master_seed;
	}

	// PackPublisher only
	function definePack(uint16[] calldata dids, uint32 _amount, uint16 _price) isPackPublisher external {
		uint256 l = dids.length;
		Release memory newrel = Release({
			price: _price,
			stock: _amount,
			seed: getSeed(),
			designs: new uint16[](l)
			});
		uint8 i;
		for(i=0; i<l; i++)
		{
			newrel.designs[i] = dids[i];
		}
		releases.push(newrel);
	}

	// PackPublisher only
	function release(uint16 rid, uint32 _amount, uint16 _price) isPackPublisher public {
		// price 0 means 'no change to the price'
		// amount 0 means 'no additional stock, just pricing'
		require(rid < releases.length);
		if(_price != 0){
			releases[rid].price = _price;
		}
		releases[rid].stock += _amount;
	}

	// called after currency transfer
	function sendPack(address buyer, uint16 rid, uint32 amount) byMain external {
		owner_rel_pack[buyer][rid] += amount;
		releases[rid].stock -= amount;
	}

	function unpack(address owner, uint16 rid, uint32 amount) external returns(uint16[] memory dids) {		
		require(owner_rel_pack[owner][rid] >= amount, "not enough amount");
		require(rid < releases.length, "not released one");
		uint32 l = amount * 10;

		dids = new uint16[](l);
		for(uint i=0; i<l; i++)
		{
			releases[rid].seed *= 3;
			releases[rid].seed %= 101;
			dids[i] = releases[rid].designs[uint16(releases[rid].seed % releases[rid].designs.length)];
		}
		owner_rel_pack[owner][rid] -= amount;
	}

	// // seed monitoring: for debug..
	// function relgen(uint16 rid) external {
	// 	releases[rid].seed *= 3;
	// 	releases[rid].seed %= 101;
	// }
	// function getSeeds(uint16 rid) view external returns(
	// 	uint32 ms, uint32 ns, uint16 did){
	// 	return (master_seed, releases[rid].seed, uint16(releases[rid].seed % releases[rid].designs.length));
	// }

	// show remaining stocks in market
	function getPackStock() external view returns(		
		uint32[] memory stocks,
		uint16[] memory prices) {

		uint16 i;
		uint256 l = releases.length;

		stocks = new uint32[](l);
		prices = new uint16[](l);

		for(i=0; i<l; i++){
			stocks[i] = releases[i].stock;
			prices[i] = releases[i].price;
		}
	}

	function getMyPackInfo(address owner) external view returns(
		uint16[] memory rids,
		uint32[] memory remainings){

		uint16 i;
		uint256 l = releases.length;

		// first, scan the rel num
		uint16 relcount = 0;
		for(i=0; i<l; i++){
			if(owner_rel_pack[owner][i] > 0){
				relcount++;
			}
		}

		// then, create the array
		rids = new uint16[](relcount);
		remainings = new uint32[](relcount);

		// fill out
		uint16 c = 0;
		for(i=0; i<l; i++){
			if(owner_rel_pack[owner][i] > 0){
				rids[c] = i;
				remainings[c] = owner_rel_pack[owner][i];
				c++;
			}
		}
	}

	function getOwnerPackCount(address owner, uint16 rid) external view returns(uint32){
		return owner_rel_pack[owner][rid];
	}

	function checkStock(uint16 rid, uint32 amount) external view returns(bool) {
		return ((rid < releases.length) && (releases[rid].stock >= amount)); // enough stock?
	}

	function getTotal(uint16 rid, uint32 amount) external view returns(uint32) {
		return (releases[rid].price * amount);
	}
}