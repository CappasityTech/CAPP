// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OFTUpgradeable} from "@zodomo/oapp-upgradeable/oft/OFTUpgradeable.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

contract OFT is OFTUpgradeable, UUPSUpgradeable {
    using BytesLib for bytes;

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, address _lzEndpoint, address _owner)
        public
        initializer
    {
        _initializeOFT(_name, _symbol, _lzEndpoint, _owner);
    }

    /** ========= CAPP specific code ============ */

    /**
     * @dev Retrieves the shared decimals of the OFT.
     * @return The shared decimals of the OFT.
     *
     * @dev Sets an implicit cap on the amount of tokens, over uint64.max() will need some sort of outbound cap / totalSupply cap
     * Lowest common decimal denominator between chains.
     * Defaults to 6 decimal places to provide up to 18,446,744,073,709.551615 units (max uint64).
     * For tokens exceeding this totalSupply(), they will need to override the sharedDecimals function with something smaller.
     * ie. 4 sharedDecimals would be 1,844,674,407,370,955.1615
     */
    function sharedDecimals() public pure virtual override returns (uint8) {
        return 2;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 2;
    }

    /* ========== Premint Helper ========= */

    /**
     * @dev Admin method, which allows for batch minting of tokens
     */
    function batchMint(bytes memory _data) public onlyOwner {
        // internally will check for OOB data
        uint16 arrSize = BytesLib.toUint16(_data, 0);
        // we've consumed 2 bytes
        uint256 start = 2;

        // verify that length matches up and we'd be able to decode data
        require(_data.length == arrSize * 24 + 2, "Malformed Calldata");
        
        address tempAddr;
        uint256 tempTokens;

        for (uint16 i = 0; i < arrSize; ++i) {
            tempAddr = BytesLib.toAddress(_data, start);
            start += 20;
            tempTokens = uint256(BytesLib.toUint32(_data, start));
            start += 4;
            _mint(tempAddr, tempTokens);
        }
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
}
