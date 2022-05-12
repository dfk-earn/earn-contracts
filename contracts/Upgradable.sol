// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Upgradable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    function upgradeScheduler() public view returns (address) {
        return _getAdmin();
    }

    function setUpgradeScheduler(address _upgradeScheduler) public onlyOwner {
        require(upgradeScheduler() == address(0), "Upgradable: upgradeScheduler exist");
        _changeAdmin(_upgradeScheduler);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyUpgradeScheduler() {
        require(upgradeScheduler() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function _authorizeUpgrade(address) internal override onlyUpgradeScheduler {}
}
