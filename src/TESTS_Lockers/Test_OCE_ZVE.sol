// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCE/OCE_ZVE.sol";

contract Test_OCE_ZVE is Utility {

    OCE_ZVE OCE_ZVE_Live;

    function setUp() public {

        deployCore(false);

        simulateITO(10_000_000 * WAD, 10_000_000 * WAD, 10_000_000 * USD, 10_000_000 * USD);

        claimITO_and_approveTokens_and_stakeTokens(false);

        // Initialize and whitelist OCE_ZVE_Live locker.
        OCE_ZVE_Live = new OCE_ZVE(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(OCE_ZVE_Live), true));
        
        // DAO pushes 100k $ZVE to OCE_ZVE_Live.
        assert(god.try_push(address(DAO), address(OCE_ZVE_Live), address(ZVE), 100_000 ether, ""));

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function assignRandomDistributionRatio(uint256 random) public returns (uint256[3] memory settings) {

        uint256 random_0 = random % 10000;
        uint256 random_1 = random % (10000 - random_0);
        uint256 random_2 = 10000 - random_0 - random_1;

        settings[0] = random_0;
        settings[1] = random_1;
        settings[2] = random_2;

        assert(god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), settings));

    }



    // ------------------
    //    Unit Testing
    // ------------------

    function test_OCE_ZVE_init() public {

        // Ownership.
        assertEq(OCE_ZVE_Live.owner(), address(DAO));

        // State variables.
        assertEq(OCE_ZVE_Live.GBL(), address(GBL));
        assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp);
        assertEq(OCE_ZVE_Live.exponentialDecayPerSecond(), RAY * 99999999 / 100000000);

        uint256[3] memory _preDistribution;
        _preDistribution[0] = OCE_ZVE_Live.distributionRatioBIPS(0);
        _preDistribution[1] = OCE_ZVE_Live.distributionRatioBIPS(1);
        _preDistribution[2] = OCE_ZVE_Live.distributionRatioBIPS(2);

        assertEq(OCE_ZVE_Live.distributionRatioBIPS(0), 3334);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(1), 3333);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(2), 3333);

        assert(OCE_ZVE_Live.canPush());
        assert(OCE_ZVE_Live.canPull());
        assert(OCE_ZVE_Live.canPullPartial());

        // $ZVE balance 100k from setUp().
        assertEq(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), 100_000 ether);

    }

    // Validate pushToLocker() restrictions.
    // This includes:
    //  - The asset pushed from DAO => OCE_ZVE must be $ZVE.

    function test_OCE_ZVE_pushToLocker_restrictions_wrongAsset() public {

        // Can't push non-ZVE asset to OCE_ZVE.
        hevm.startPrank(address(god));
        hevm.expectRevert("OCE_ZVE::pushToLocker() asset != IZivoeGlobals_OCE_ZVE(GBL).ZVE()");
        DAO.push(address(OCE_ZVE_Live), address(FRAX), 10_000 ether, "");
        hevm.stopPrank();
    }

    // Validate updateDistributionRatioBIPS() state changes.
    // Validate updateDistributionRatioBIPS() restrictions.
    // This includes:
    //  - Sum of all values in _distributionRatioBIPS must equal 10000.
    //  - _msgSender() must equal TLC (governance contract, "god").

    function test_OCE_ZVE_updateDistributionRatioBIPS_restrictions_sumGreaterThan10000() public {

        // Sum must equal 10000 (a.k.a. BIPS).
        uint256[3] memory initDistribution = [uint256(0), uint256(0), uint256(0)];
        hevm.startPrank(address(god));
        hevm.expectRevert("OCE_ZVE::updateDistributionRatioBIPS() sum(_distributionRatioBIPS[0-2]) != BIPS");
        OCE_ZVE_Live.updateDistributionRatioBIPS(initDistribution);
        hevm.stopPrank();
    }

    function test_OCE_ZVE_updateDistributionRatioBIPS_restrictions_sumLessThan10000() public {

        // Sum must equal 10000 (a.k.a. BIPS).
        uint256[3] memory initDistribution = [uint256(4999), uint256(5000), uint256(0)];
        hevm.startPrank(address(god));
        hevm.expectRevert("OCE_ZVE::updateDistributionRatioBIPS() sum(_distributionRatioBIPS[0-2]) != BIPS");
        OCE_ZVE_Live.updateDistributionRatioBIPS(initDistribution);
        hevm.stopPrank();
    }

    function test_OCE_ZVE_updateDistributionRatioBIPS_restrictions_msgSender() public {

        // Does work for 10000 (a.k.a. BIPS).
        uint256[3] memory initDistribution = [uint256(4999), uint256(5000), uint256(1)];
        assert(god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), initDistribution));

        // Caller must be TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCE_ZVE::updateDistributionRatioBIPS() _msgSender() != IZivoeGlobals_OCE_ZVE(GBL).TLC()");
        OCE_ZVE_Live.updateDistributionRatioBIPS(initDistribution);
        hevm.stopPrank(); 
    }

    function test_OCE_ZVE_updateDistributionRatioBIPS_state(uint256 random) public {

        uint256 random_0 = random % 10000;
        uint256 random_1 = random % (10000 - random_0);
        uint256 random_2 = 10000 - random_0 - random_1;

        // Pre-state.
        uint256[3] memory _preDistribution;
        _preDistribution[0] = OCE_ZVE_Live.distributionRatioBIPS(0);
        _preDistribution[1] = OCE_ZVE_Live.distributionRatioBIPS(1);
        _preDistribution[2] = OCE_ZVE_Live.distributionRatioBIPS(2);

        assertEq(OCE_ZVE_Live.distributionRatioBIPS(0), 3334);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(1), 3333);
        assertEq(OCE_ZVE_Live.distributionRatioBIPS(2), 3333);

        _preDistribution[0] = random_0;
        _preDistribution[1] = random_1;
        _preDistribution[2] = random_2;

        assertEq(random_0 + random_1 + random_2, 10000);

        assert(god.try_updateDistributionRatioBIPS(address(OCE_ZVE_Live), _preDistribution));

        // Post-state.
        uint256[3] memory _postDistribution;
        _postDistribution[0] = OCE_ZVE_Live.distributionRatioBIPS(0);
        _postDistribution[1] = OCE_ZVE_Live.distributionRatioBIPS(1);
        _postDistribution[2] = OCE_ZVE_Live.distributionRatioBIPS(2);

        assertEq(_postDistribution[0] + _postDistribution[1] + _postDistribution[2], 10000);

    }

    // Validate forwardEmissions() state changes.

    function test_OCE_ZVE_Live_forwardEmissions_state(uint256 random) public {
        
        uint256[3] memory settings = assignRandomDistributionRatio(random);

        uint256 amountDecaying = IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live));
        uint256 amountDecayed = 0;
        uint256 i = 0;

        uint256 interval = 7 days;
        uint256 intervals = 52;

        uint256[6] memory balanceData = [
            IERC20(address(ZVE)).balanceOf(address(stZVE)),
            IERC20(address(ZVE)).balanceOf(address(stZVE)),
            IERC20(address(ZVE)).balanceOf(address(stJTT)),
            IERC20(address(ZVE)).balanceOf(address(stJTT)),
            IERC20(address(ZVE)).balanceOf(address(stSTT)),
            IERC20(address(ZVE)).balanceOf(address(stSTT))
        ];

        while (i < intervals) {

            // Warp forward 1 interval.
            hevm.warp(block.timestamp + interval);

            // Pre-state.
            assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp - interval);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), amountDecaying);
            balanceData[0] = IERC20(address(ZVE)).balanceOf(address(stZVE));
            balanceData[2] = IERC20(address(ZVE)).balanceOf(address(stSTT));
            balanceData[4] = IERC20(address(ZVE)).balanceOf(address(stJTT));

            amountDecayed = amountDecaying - OCE_ZVE_Live.decay(amountDecaying, interval);

            OCE_ZVE_Live.forwardEmissions();

            // Post-state.
            assertEq(ZVE.allowance(address(OCE_ZVE_Live), address(stZVE)), 0);
            assertEq(ZVE.allowance(address(OCE_ZVE_Live), address(stSTT)), 0);
            assertEq(ZVE.allowance(address(OCE_ZVE_Live), address(stJTT)), 0);

            balanceData[1] = IERC20(address(ZVE)).balanceOf(address(stZVE));
            balanceData[3] = IERC20(address(ZVE)).balanceOf(address(stSTT));
            balanceData[5] = IERC20(address(ZVE)).balanceOf(address(stJTT));

            assertEq(OCE_ZVE_Live.lastDistribution(), block.timestamp);
            withinDiff(
                IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live)), 
                OCE_ZVE_Live.decay(amountDecaying, interval),
                3
            );
            withinDiff(
                balanceData[1] - balanceData[0],
                amountDecayed * settings[0] / 10000,
                3
            );
            withinDiff(
                balanceData[3] - balanceData[2],
                amountDecayed * settings[1] / 10000,
                3
            );
            withinDiff(
                balanceData[5] - balanceData[4],
                amountDecayed * settings[2] / 10000,
                3
            );

            amountDecaying = IERC20(address(ZVE)).balanceOf(address(OCE_ZVE_Live));

            i++;
        }

    }
    
    // Validate updateExponentialDecayPerSecond() state changes.
    // Validate updateExponentialDecayPerSecond() restrictions.
    // This includes:
    //  - Only governance contract (TLC / "god") may call this function.

    function test_OCE_ZVE_Live_updateExponentialDecayPerSecond_restrictions_msgSender(uint256 random) public {

        hevm.startPrank(address(bob));
        hevm.expectRevert("OCE_ZVE::updateExponentialDecayPerSecond() _msgSender() != IZivoeGlobals_OCE_ZVE(GBL).TLC()");
        OCE_ZVE_Live.updateExponentialDecayPerSecond(random);
        hevm.stopPrank();
    }

    function test_OCE_ZVE_Live_updateExponentialDecayPerSecond_state(uint256 random) public {
        
        hevm.assume(random >= RAY * 99999999 / 100000000);

        // Pre-state.
        assertEq(OCE_ZVE_Live.exponentialDecayPerSecond(), RAY * 99999999 / 100000000);

        assert(god.try_updateExponentialDecayPerSecond(address(OCE_ZVE_Live), random));
        
        // Post-state.
        assertEq(OCE_ZVE_Live.exponentialDecayPerSecond(), random);

    }

    // Examine amountDistributable() values.

    function test_OCE_ZVE_Live_amountDistributable_null(uint96 random) public {

        uint256 amount = uint256(random);

        // This should indicate that if 0 seconds have passed, i.e. a contract
        // is atomically calling functions, there will be no decay, such that
        // the full value supplied is returned.
        assertEq(OCE_ZVE_Live.decay(amount, 0), amount);
    }

    function test_OCE_ZVE_Live_amountDistributable_schedule_hourlyEmissions() public {

        uint256 amountDecaying = 100000 ether;
        uint256 amountDecayed = 0;
        uint256 i = 0;

        uint256 interval = 1 hours;
        uint256 intervals = 360 * 24;

        while (i < intervals) {
            amountDecayed = amountDecaying - OCE_ZVE_Live.decay(amountDecaying, interval);
            amountDecaying = OCE_ZVE_Live.decay(amountDecaying, interval);
            emit Debug('a', amountDecaying);
            emit Debug('a', amountDecayed);
            i++;
        }

        // After 360 days ... 53682667269999381549237 remains (53.68k $ZVE).

    }

    function test_OCE_ZVE_Live_amountDistributable_schedule_dailyEmissions() public {

        uint256 amountDecaying = 100000 ether;
        uint256 amountDecayed = 0;
        uint256 i = 0;

        uint256 interval = 1 days;
        uint256 intervals = 360;

        while (i < intervals) {
            amountDecayed = amountDecaying - OCE_ZVE_Live.decay(amountDecaying, interval);
            amountDecaying = OCE_ZVE_Live.decay(amountDecaying, interval);
            emit Debug('a', amountDecaying);
            emit Debug('a', amountDecayed);
            i++;
        }

        // After 360 days ... 53682667269999381552324 (53.68k $ZVE)

    }

}
