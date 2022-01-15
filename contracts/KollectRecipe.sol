// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract KollectRecipe{
	uint8[] lower = [ 0,  3,  7, 14, 19, 23, 29];
	uint8[] upper = [ 8, 12, 18, 26, 34, 42, 45];
	uint8[] span =  [ 3,  3,  5,  4,  4,  6,  6];
	uint8[] slope = [20, 20, 12, 15, 15, 10, 10];

	uint8 maxRarity = 0;
	uint32 seed = 7;

	mapping(uint8 => uint16[]) rd;

	constructor(){
		//
	}

	function propagate(uint16 did, uint8 rarity) external {		
		rd[rarity].push(did);
		if (maxRarity < rarity){
			maxRarity = rarity;
		}
	}

	// function do_synthesize(uint16[] calldata dids) public returns(uint16 result){
	// 	return 0;
	// }
	// by rarity-sum
	function do_synthesize(uint8 rsum) external returns(uint16 did){
		uint8 i;
		uint16 ssum = 0;
		uint8 score; // 0 ~ 60
		uint l = lower.length;
		uint32[] memory table = new uint32[](lower.length);
		for(i=0; i<l; i++)
		{
			// calculate tier-score
			// out of bound
			if (rsum < lower[i] || rsum > upper[i]){
				score = 0;
			}
			// at the guard (lower)
			else if (rsum < lower[i] + span[i]){
				score = 5 + slope[i] * (rsum - lower[i]);
			}
			// at the guard (upper)
			else if (rsum > upper[i] - span[i]){
				score = 5 + slope[i] * (upper[i] - rsum);
			}
			// at the safe zone
			else{
				score = 60;
			}
			table[i] = score;
			ssum += score;
		}
		// pop the seed
		seed *= 3;
		seed %= 101; // 1 ~ 100

		uint8 rarity = 1;
		uint32 rand = seed * ssum; // ssum ~ ssum*100		
		uint32 target = 0;
		for(i=0; i<maxRarity; i++)
		{
			target += (table[i] * 100);
			if(rand <= target){
				break;
			}
			else{
				rarity++;
			}
		}
		uint32 idx = seed % uint32(rd[rarity].length);
		return rd[rarity][idx];
	}
}