// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./KollectAccess.sol";
import "./token/ERC20/extensions/ERC20Burnable.sol";

contract KLT is ERC20Burnable, KollectAccess {
    // KLT and ether is stored in this contract, address(this)
    address payable vault;

    constructor() ERC20("Kollect", "KLT") {
        vault = payable(address(this));
        _mint(vault, 1000000000); // 1G KLT in vault
    }

    function decimals() public pure override returns (uint8) {
        return 3;
    }

    /* --- about trade --- */
    // 1 ETH = 1000,000 KLT = 1G gwei
    // 1 KLT = about 1~3 won

    // 1,000 gwei <-> 1 KLT
    // account     -(eth)  -> vault
    // vault(self) -(klt)  -> account
    function ethToKlt() public payable{
        uint amount = msg.value / 1000000000000; // total 12-decimal shifting
        issue(amount);
    }

    // Vault sends KLT to user
    function issue(uint klt) internal {
        _approve(vault, msg.sender, klt);
        transferFrom(vault, msg.sender, klt);
    }

    // 1 KLT <-> 1,000 gwei
    // account     -(klt)  -> vault
    // vault(self) -(eth)  -> account
    function kltToEth(uint klt) public payable{
        uint amount = klt * 1000000000000; // total 12-decimal shifting
        transfer(address(this), klt);
        (bool sent, bytes memory data) = msg.sender.call{value: amount}(""); // contract -> account        
        require(sent, "eth transfer failed");
    }

    // generate 1G KLT at this contract
    function mint() external isCEO {
        _mint(address(this), 1000000000);
    }

    // KLT
    function getVault() external view isCEO returns(uint){
        return balanceOf(vault);
    }
}
