pragma solidity 0.8.6;

import '../JBTieredNFTRewardDelegate.sol';
import 'forge-std/Test.sol';

contract TestJBTieredNFTRewardDelegate is Test {
    address caller = address(69420);
    address owner = address(42069);
    address mockJBDirectory = address(1);
    address mockTokenUriResolver = address(2);
    address mockContributionToken = address(3);
    address mockTerminalAddress = address(4);

    uint256 projectId = 69;

    string name = 'NAME';
    string symbol = 'SYM';
    string baseUri = 'http://www.null.com';
    string contractUri = 'ipfs://null';

    JBTieredLimitedNFTRewardDataSource delegate;

    function setUp() public {
        vm.label(caller, 'caller');
        vm.label(owner, 'owner');
        vm.label(mockJBDirectory, 'mockJBDirectory');
        vm.label(mockTokenUriResolver, 'mockTokenUriResolver');
        vm.label(mockContributionToken, 'mockContributionToken');
        vm.label(mockTerminalAddress, 'mockTerminalAddress');

        vm.etch(mockJBDirectory, new bytes(0x69));
        vm.etch(mockTokenUriResolver, new bytes(0x69));
        vm.etch(mockContributionToken, new bytes(0x69));
        vm.etch(mockTerminalAddress, new bytes(0x69));
    }

    function testJBTieredNFTRewardDelegate_deployIfTiersSorted(uint8 nbTiers) public {
        vm.assume(nbTiers < 10);

        JBNFTRewardTier[] memory _tiers = new JBNFTRewardTier[](nbTiers);
        for(uint256 i; i < nbTiers; i++) {
            _tiers[i] = JBNFTRewardTier({
                contributionFloor: uint128(i*10),
                idCeiling: uint48((i*100) + 1),
                remainingAllowance: uint40(i*100),
                initialAllowance: uint40(i*100)
            });
        }

        delegate = new JBTieredLimitedNFTRewardDataSource(
            projectId,
            IJBDirectory(mockJBDirectory),
            name,
            symbol,
            IToken721UriResolver(mockTokenUriResolver),
            baseUri,
            contractUri,
            mockTerminalAddress,
            owner,
            mockContributionToken,
            _tiers
        );
    }
}