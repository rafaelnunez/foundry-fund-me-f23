// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");
    uint private constant SEND_VALUE = 0.1 ether;
    uint private constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        fundMe = new DeployFundMe().run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18, "Minimum dollar is not five");
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender, "Owner is not msg.sender");
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4, "Price feed version is not accurate");
    }

    function testFundfailsWithoutEnoughETH() public {
        vm.expectRevert(); // expected failure in the next call
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // the next line will be send by USER
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE, "Amount funded is not accurate");
    }

    modifier funded {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testAddsFunderToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);

        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded{
        vm.expectRevert(); // expected failure in the next call
        vm.prank(USER);
        fundMe.withdraw();
        
    }

    function testWithdrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startFundMeBalance = address(fundMe).balance;
        
        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        
        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0, "FundMe balance is not zero");
        assertEq(endingOwnerBalance, startingOwnerBalance + startFundMeBalance, "Owner balance is not accurate");
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank new address
            
            // vm.deal new address

            // address()
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
            // fund the fundMe
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startFundMeBalance = address(fundMe).balance;
        
        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(fundMe.getOwner().balance == startingOwnerBalance + startFundMeBalance);
    }
}
