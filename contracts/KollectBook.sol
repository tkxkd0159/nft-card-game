// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./KollectAccess.sol";
import "./KollectCard.sol";
/*
 --------- data types -----------
 book ID 			    : uint16
 ndesigns, rows, cols   : uint8
 book status            : uint256
 --------------------------------
*/

contract KollectBook is KollectAccess {
    KollectCard kc;

    constructor(address kc_a) KollectAccess() {
        kc = KollectCard(kc_a);
        // reserve 'nada' book
        BookDesign memory book0 = BookDesign({
            text: bytes32(0x0),
            nDesigns: 0,
            rows: 0,
            cols: 0,
            isPublic: false,
            designs: new uint16[](0)
            });
        books.push(book0); // reserved
    }

    struct BookDesign{
        bytes32 text;
        uint8 nDesigns;
        uint8 rows;
        uint8 cols;
        bool isPublic;
        uint16[] designs; // note that did is uint16 (KollectCard.sol)
    }
    BookDesign[] books; // bid : index of BookDesign var

    // private book's status: represented by 64-bit
    mapping(address => mapping(uint16 => uint256)) bookstatus;

    // public book's status
    mapping(uint16 => uint256) pubBookstatus;

    // card-side 'inbook' status
    struct CardInBook{
        uint16 bid;
        uint8 pos;
    }
    mapping(uint256 => CardInBook) cardInBooks;

    // modifiers (same with KollectCard)
    modifier isOwner(uint256 cid, address owner){
        require(kc.ownerOf(cid) == owner, "not owner");
        _;
    }

    modifier validBid(uint16 bid){
        require((bid < books.length) && (bid != 0), "invalid bid");
        _;
    }

    function getCardInBook(uint256 cid) external view isOwner(cid, msg.sender) returns(uint16 bid, uint8 pos){
        bid = cardInBooks[cid].bid;
        pos = cardInBooks[cid].pos;
    }

    // registering book design
    function defineBook(uint16[] calldata dids, bytes32 text, uint8 cols, uint8 rows, bool isPublic) isCEO external {
        uint256 l = dids.length;
        require(cols * rows == l, "incorrect params");
        BookDesign memory newbd = BookDesign({
            text: text,
            nDesigns: uint8(l),
            rows: rows,
            cols: cols,
            isPublic: isPublic,
            designs: new uint16[](l)
            });
        for(uint8 i = 0; i < l; i++){
            newbd.designs[i] = dids[i];            
        }
        books.push(newbd);
    }

    function getBookCount() external view returns(uint256){
        return books.length-1; // books[0] is reserved
    }
    function getBookInfo(uint16 bid) external view validBid(bid) returns(
        bytes32 text, uint8 rows, uint8 cols, bool isPublic,
        uint16[] memory designs, uint256 status) {

        uint16 l = uint16(books.length);
                
        text = books[bid].text;
        rows = books[bid].rows;
        cols = books[bid].cols;
        isPublic = books[bid].isPublic;
        designs = books[bid].designs; 
        if(books[bid].isPublic){
            status = pubBookstatus[bid];
        }
        else{
            status = bookstatus[msg.sender][bid];
        }
    }

    // card & book interaction
    function addCardToBook(uint256 cid, uint16 bid) validBid(bid) external {
        BookDesign memory bd = books[bid];
        bool isSwitch = false;

        // check if card is already added to other book
        if(cardInBooks[cid].bid != 0){            
            removeCardFromBook(cid, cardInBooks[cid].bid);
            isSwitch = true;            
        }        

        // get did of this card
        uint16 did = kc.getDesignOf(cid, msg.sender);

        // check what pos this card will be added
        uint8 pos;
        for(pos = 0; pos < bd.nDesigns; pos++){
            if(bd.designs[pos] == did)
                break;
        }

        require(pos < bd.nDesigns,"No room for this design");

        uint mask = uint(1 << pos); // mask: b'00100 for pos 3

        // change book status
        if (bd.isPublic){         
            require((pubBookstatus[bid] & mask) == 0, "Word is already filled");
            pubBookstatus[bid] |= mask; // change the book status
        }
        else{            
            require((bookstatus[msg.sender][bid] & mask) == 0, "Word is already filled");
            bookstatus[msg.sender][bid] |= mask; // change the book status
        }
        cardInBooks[cid].bid = bid;
        cardInBooks[cid].pos = pos;
    }

    function removeCardFromBook(uint256 cid, uint16 bid) validBid(bid) public {
        BookDesign memory bd = books[bid];
        uint8 pos = cardInBooks[cid].pos;
        uint mask = uint(1 << pos);

        // change book status
        if (bd.isPublic){            
            require((pubBookstatus[bid] & mask) != 0, "Word is not in here");
            pubBookstatus[bid] &= ~mask;
        }
        else{
            require((bookstatus[msg.sender][bid] & mask) != 0, "Word is not in here");
            bookstatus[msg.sender][bid] &= ~mask;
        }

        // change cards' state
        cardInBooks[cid].bid = 0;
        cardInBooks[cid].pos = 0;
    }
    
}