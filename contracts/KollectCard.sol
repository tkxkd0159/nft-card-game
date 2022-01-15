// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./token/ERC721/ERC721.sol";
import "./KollectAccess.sol";
import "./KollectPack.sol";
import "./KollectRecipe.sol";
import "./KollectCard.sol";

/*
 --------- data types -----------
 release ID 			: uint16  
 release price 			: uint16
 design ID 				: uint16
 card ID 				: uint256 (ERC721) 
 card/release count 	: uint256
 --------------------------------
*/

contract KollectCard is KollectAccess, ERC721{

	// external contracts
	KollectPack kp;
	KollectRecipe kr;

	bool dev = true;

	constructor(address kp_a, address kr_a) ERC721("Kollect.Cards", "KLC") KollectAccess() {
		cardPublishers[ceo] = true;
		kp = KollectPack(kp_a);
		kr = KollectRecipe(kr_a);
	}

	/* --- access control --- */
	// cardPublishers: card publisher releases **card design** to the system
	mapping(address => bool) cardPublishers;
	modifier isCardPublisher{
		require(cardPublishers[msg.sender] == true);
		_;
	}
	function addCardPublisher(address addr) external isCEO{		
		cardPublishers[addr] = true;
	}
	modifier isOwner(uint256 cid, address owner){
		require(ownerOf(cid) == owner, "not owner");
		_;
	}
	/* ----------------------- */

	modifier onDev{
		require(dev);
		_;
	}
	
	// events
	// new card recipe is found by a user
	event Found(address by, uint16 did, uint32 cardId);

	// Card design (abstract) definition
	struct CardDesign{
		bytes32 url; // url of resource
		bytes32 text; // text explanation
		uint8 rarity; // rarity of the card
		address designer; // the one who publish cards
	}
	CardDesign[] cardDesigns;
	mapping(bytes32 => bool) url_exists;
	uint256[] redeemValues = [0,1,3,5,10,20,50,100];

	// Card (NFT) definition 
	struct Card{
		uint16 design;		// which design this card has (=did)
		uint32 lifetime;	// remaining lifetime of card
		address creator; 	// first creator of this card
	}
	Card[] cards;

	// overriding ERC721
	mapping(uint256 => address) cowner;
	function _mint(address to, uint256 tokenId) internal override {
		cowner[tokenId] = to;
	}
	function ownerOf(uint256 tokenId) public view override returns (address) {
		return cowner[tokenId];
	}	
	function _burn(uint256 tokenId) internal override {
		cowner[tokenId] = address(0);
	}

	function setRecipe(address kr_a) isCEO validAddr(kr_a) external {		
		kr = KollectRecipe(kr_a);
	}

	// releasing new pack is pack publisher's action
	function registerDesign(bytes32 url, bytes32 text, uint8 rarity, address designer) isCardPublisher external {
		// check redundancy
		require(!url_exists[url], "URL already exists");
		url_exists[url] = true;
		cardDesigns.push(CardDesign({
			url: url,
			text: text,
			rarity: rarity,
			designer: designer
			})
		);
		kr.propagate(uint16(cardDesigns.length-1), rarity);
	}

	function registerDeck(bytes32[] calldata urls, bytes32[] calldata texts, uint8[] calldata rarities, address designer) isCardPublisher external{
		uint l = urls.length;
		uint dl = cardDesigns.length;
		for(uint i = 0; i < l; i++){
			if (url_exists[urls[i]]) continue;
			url_exists[urls[i]] = true;
			cardDesigns.push(CardDesign({
				url: urls[i],
				text: texts[i],
				rarity: rarities[i],
				designer: designer
				})
			);
			kr.propagate(uint16(dl+i), rarities[i]);
		}
	}

	// only in dev stage, designs can be deleted
	// deletion does not change the index of other designs
	function deleteDesign(uint16 did) onDev isCEO external {
		require(did < cardDesigns.length, "invalid design id");		
		delete cardDesigns[did];
	}

	// only in dev stage, designs can be modified
	function modifyDesign(uint16 did, bytes32 url, bytes32 text, uint8 rarity) onDev isCEO external {
		require(did < cardDesigns.length, "invalid design id");		
		cardDesigns[did].url = url;
		cardDesigns[did].text = text;
		cardDesigns[did].rarity = rarity;
	}

	// maybe should be hidden?
	function getDesignCount() external view returns(uint16) {		
		return uint16(cardDesigns.length);
	}

	// maybe should be hidden?
	function getDesignByDid(uint16 did) public view returns(
		bytes32 url, bytes32 txt, uint8 rarity, address designer) {

		require(cardDesigns[did].rarity != 0, "deleted design");
		url = cardDesigns[did].url;
		txt = cardDesigns[did].text;
		rarity = cardDesigns[did].rarity;
		designer = cardDesigns[did].designer;
	}

	function getDesignOf(uint256 cid, address owner) public view isOwner(cid, owner) returns(uint16 did){
		did = cards[cid].design;
		require(cardDesigns[did].rarity != 0, "deleted design");
	}

	// get personal card's design
	function getDesignByCid(uint256 cid) isOwner(cid, msg.sender) external view returns(
		bytes32 url, bytes32 txt, uint8 rarity, uint16 did, address designer) {

		did = getDesignOf(cid, msg.sender);
		(url, txt, rarity, designer) = getDesignByDid(did);
	}

	// get personal card's info
	// only owner can show this card
	function getCardInfo(uint256 cid) public view isOwner(cid, msg.sender) returns(
		uint16 design, uint32 lifetime, address creator) {
		
		return(cards[cid].design,
			   cards[cid].lifetime,
			   cards[cid].creator
			   );
	}

	// get sender's cards
	function getMyCards() external view returns(uint256[] memory cids){
		address owner = msg.sender;
		uint l = 0;
		uint i;
		// find count
		for(i=0; i<cards.length; i++){
			if (ownerOf(i) == owner)
				l++;
		}

		// allocate array
		cids = new uint256[](l);

		// scan again for set value..
		uint c = 0;
		for(i=0; i<cards.length; i++){
			if (ownerOf(i) == owner){
				cids[c] = i;
				c++;
				// require(c<=l, "c exceeds l. something wrong!");
			}
		}
		return cids;
	}	

	function getRedeemValue(uint256 cid) external view returns(uint256){
		return redeemValues[cardDesigns[cards[cid].design].rarity];
	}

	function burnCards(uint256[] calldata cids, address owner) public {
		for(uint i=0; i<cids.length; i++){			
			require(ownerOf(cids[i]) == owner, 'Not owner');
			_burn(cids[i]);
		}
	}

	// cross-action of Card + Pack
	function callUnpack(uint16 rid, uint32 amount) validAddr(msg.sender) external {
		uint16[] memory dids = kp.unpack(msg.sender, rid, amount);
		uint l = amount * 10;
		for(uint i=0;i<l;i++){
			uint256 newCid = cards.length;
			cards.push(Card({
				design: dids[i],
				lifetime: 100,
				creator: msg.sender
				})
			);
			_mint(msg.sender, newCid);
		}
	}

	// synth by rarity-sum
	function synthesize(uint256[] calldata cids) external {
		uint8 rsum = 0;
		uint256 l = cids.length;
		uint8 i;
		require(l<=5);
		for(i=0; i<l; i++){
			_burn(cids[i]); 
			rsum += cardDesigns[cards[cids[i]].design].rarity;
		}
		uint16 did = kr.do_synthesize(rsum);
		uint256 newCid = cards.length;
		cards.push(Card({			design: did,
			lifetime: 100,
			creator: msg.sender
			})
		);
		_mint(msg.sender, newCid);
		// emit Found(owner, did, newCid);
	}


}