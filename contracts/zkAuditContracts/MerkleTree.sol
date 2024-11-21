// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./MiMC.sol";

contract MerkleTree {
    uint256 public constant ZERO_VALUE =
        64344675111657410415633911327018423030456209651036339190874744485150123954841;

    uint256 public levels;

    uint256 private root;
    uint256 private nextIndex;
    mapping(uint256 => uint256) private filledSubtrees;

    constructor(uint256 _levels) {
        require(_levels > 0, "_levels should be greater than zero");
        require(_levels < 11, "_levels should be less than 11");

        levels = _levels;

        for (uint32 i = 0; i < levels; i++) {
            filledSubtrees[i] = zeros(i);
        }

        root = zeros(levels - 1);
    }

    function hashLeftRight(
        uint256 left,
        uint256 right
    ) public pure returns (uint256) {
        uint[] memory input = new uint[](2);
        input[0] = left;
        input[1] = right;
        return MiMC.hash(input);
    }

    function insert(uint256 leaf) internal {
        require(nextIndex != 2 ** levels, "tree is full");
        uint256 left;
        uint256 right;
        uint256 currentIndex = nextIndex;
        uint256 currentHash = leaf;

        for (uint i = 0; i < levels; i++) {
            if (currentIndex % 2 == 0) {
                left = currentHash;
                right = zeros(i);
                filledSubtrees[i] = currentHash;
            } else {
                left = filledSubtrees[i];
                right = currentHash;
            }
            currentHash = hashLeftRight(left, right);
            currentIndex /= 2;
        }

        root = currentHash;

        nextIndex += 1;
    }

    function update(
        uint256 leaf,
        uint256[] memory path,
        uint256[] memory helper
    ) internal {
        require(nextIndex == 2 ** levels, "tree not full");
        require(verify(path, helper), "leaf to update not included");
        path[0] = leaf;
        root = computeRootFromPath(path, helper);
    }

    function verify(
        uint256[] memory path,
        uint256[] memory helper
    ) public view returns (bool) {
        uint[] memory input = new uint[](1);
        input[0] = path[0];
        uint256 computedHash = MiMC.hash(input);
        for (uint256 i = 1; i < path.length; i++) {
            if (helper[i - 1] == 1) {
                computedHash = hashLeftRight(computedHash, path[i]);
            } else {
                computedHash = hashLeftRight(path[i], computedHash);
            }
        }
        return computedHash == root;
    }

    function computeRootFromPath(
        uint256[] memory path,
        uint256[] memory helper
    ) public pure returns (uint256) {
        uint[] memory input = new uint[](1);
        input[0] = path[0];
        uint256 computedHash = MiMC.hash(input);
        for (uint256 i = 1; i < path.length; i++) {
            if (helper[i - 1] == 1) {
                computedHash = hashLeftRight(computedHash, path[i]);
            } else {
                computedHash = hashLeftRight(path[i], computedHash);
            }
        }
        return computedHash;
    }

    function getRoot() public view returns (uint256) {
        return root;
    }

    function setRoot(uint256 _root) internal {
        root = _root;
    }

    function getLevels() public view returns (uint256) {
        return levels;
    }

    function getNextLeafIndex() public view returns (uint256) {
        return nextIndex;
    }

    function zeros(uint256 i) public pure returns (uint256) {
        if (i == 0)
            return
                64344675111657410415633911327018423030456209651036339190874744485150123954841;
        else if (i == 1)
            return
                14419694244362721544943858897931474467632654955318263294734466139732519292147;
        else if (i == 2)
            return
                7214433609833766680386585288204170342070908259260188993090967221432577907405;
        else if (i == 3)
            return
                350058383718813365392004927025474590697634285266444909592954063146796054615;
        else if (i == 4)
            return
                18737524142928478662797750315324035156983069273736644237186822424583039865241;
        else if (i == 5)
            return
                1546678032441257452667456735582814959992782782816731922691272282333561699760;
        else if (i == 6)
            return
                1972863456667024398772035903687220518837351663509052485012641216494682508602;
        else if (i == 7)
            return
                9611412080873348783566596813804493841001829309052384028625550113278958945925;
        else if (i == 8)
            return
                908392320216315061725805563256174876641449245675489135871222045112367541982;
        else if (i == 9)
            return
                6015473723573947011242319449574096531214388449504088707704953656696366286765;
        else if (i == 10)
            return
                2164842665949219122196093716395459809063406812952512664194369749863592743588;
        else revert("index out of bounds");
    }
}
