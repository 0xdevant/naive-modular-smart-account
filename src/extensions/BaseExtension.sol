// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IExtension} from "../interfaces/extensions/IExtension.sol";

abstract contract BaseExtension is IExtension, ERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IExtension).interfaceId || super.supportsInterface(interfaceId);
    }
}
