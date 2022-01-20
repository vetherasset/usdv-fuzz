// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.9;

import "ds-test/test.sol";
import "./IHevm.sol";
import "./Vader.sol";
import "./UnlockValidator.sol";
import "../tokens/USDV.sol";
import "../interfaces/shared/IERC20Extended.sol";

contract User {
    Vader private vader;
    USDV private usdv;

    constructor(Vader _vader, USDV _usdv) {
        vader = _vader;
        usdv = _usdv;
    }

    function approve(address spender, uint amount) external {
        vader.approve(spender, amount);
    }

    function claim(uint i) external {
        usdv.claim(i);
    }

    function claimAll() external returns (uint, uint) {
        return usdv.claimAll();
    }
}

contract Minter {
    USDV private usdv;

    constructor(USDV _usdv) {
        usdv = _usdv;
    }

    function mint(
        address account,
        uint256 vAmount,
        uint256 uAmount,
        uint256 exchangeFee,
        uint256 window
    ) external returns (uint) {
        return usdv.mint( account, vAmount, uAmount, exchangeFee, window);
    }

    function burn(
        address account,
        uint256 uAmount,
        uint256 vAmount,
        uint256 exchangeFee,
        uint256 window
    ) external returns (uint) {
        return usdv.burn( account, uAmount, vAmount, exchangeFee, window);
    }
}

function bound(uint x, uint a, uint b) pure returns (uint) {
    if (x < a) {
        return a;
    }
    if (x > b) {
        return b;
    }
    return x;
}

function calcFee(uint amount, uint fee) pure returns (uint) {
    return amount * fee / 1e4;
}

uint constant MAX_LOCK_DURATION = 30 days;

contract USDVTest is DSTest {
    IHevm private hevm;
    Vader private vader;
    USDV private usdv;
    Minter private minter;
    UnlockValidator private validator;

    // Users
    User private alice;

    struct Balances {
        uint alice;
        uint usdv;
    }

    struct Snapshot {
        Balances vader;
        Balances usdv;
    }

    function setUp() public {
        hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        vader = new Vader();
        usdv = new USDV(IERC20Extended(address(vader)));
        minter = new Minter(usdv);
        validator = new UnlockValidator();

        usdv.setMinter(address(minter));
        usdv.setValidator(validator);

        // Users
        alice = new User(vader, usdv);
    }

    function snapshot() private view returns (Snapshot memory) {
        return Snapshot({
            usdv: Balances({
                alice: usdv.balanceOf(address(alice)),
                usdv: usdv.balanceOf(address(usdv))
            }),
            vader: Balances({
                alice: vader.balanceOf(address(alice)),
                usdv: vader.balanceOf(address(usdv))
            })
        });
    }

    function test_mint(uint vAmount, uint uAmount, uint fee, uint window) public {
        vAmount = bound(vAmount, 1, type(uint).max / 1e4);
        uAmount = bound(uAmount, 1, type(uint).max / 1e4);
        fee = bound(fee, 0, 1e4);
        window = bound(window, 0, MAX_LOCK_DURATION);

        // vAmount = 10 * 1e18;
        // uAmount = 1e18;
        // fee = 100;
        // window = 10;

        // Mint Vader to Alice
        vader.mint(address(alice), vAmount);
        alice.approve(address(usdv), vAmount);

        // Mint USDV
        Snapshot memory _before = snapshot();
        minter.mint(address(alice), vAmount, uAmount, fee, window);
        Snapshot memory _after = snapshot();

        uint uFee = calcFee(uAmount, fee);
        uint mintAmount = uAmount - uFee;

        assertEq(_after.vader.alice, _before.vader.alice - vAmount);
        assertEq(_after.vader.usdv, _before.vader.usdv);

        if (window > 0) {
            assertEq(_after.usdv.alice, _before.usdv.alice);
            assertEq(_after.usdv.usdv, _before.usdv.usdv + mintAmount);

            uint count = usdv.getLockCount(address(alice));
            assertGt(count, 0);
            uint i = count - 1;

            (IUSDV.LockTypes lockType, uint amount, uint release)= usdv.locks(address(alice), i);
            assertEq(uint(lockType), 0);
            assertEq(amount, mintAmount);
            assertEq(release, block.timestamp + window);

            // Claim USDV
            hevm.warp(release);

            _before = snapshot();
            alice.claim(i);
            _after = snapshot();

            assertEq(usdv.getLockCount(address(alice)), count - 1);
            assertEq(_after.usdv.alice, _before.usdv.alice + mintAmount);
            assertEq(_after.usdv.usdv, _before.usdv.usdv - mintAmount);
        } else {
            assertEq(_after.usdv.alice, _before.usdv.alice + mintAmount);
            assertEq(_after.usdv.usdv, _before.usdv.usdv);
        }
    }

    function test_burn(uint uAmount, uint vAmount, uint fee, uint window) public {
        vAmount = bound(vAmount, 1, type(uint).max / 1e4);
        uAmount = bound(uAmount, 1, type(uint).max / 1e4);
        fee = bound(fee, 0, 1e4);
        window = bound(window, 0, MAX_LOCK_DURATION);

        // uAmount = 100 * 1e18;
        // vAmount = 1000 * 1e18;
        // fee = 100;
        // window = 10;

        // Mint Vader to Alice
        vader.mint(address(alice), vAmount);
        alice.approve(address(usdv), vAmount);

        // Mint USDV to Alice
        // 0 fee, window set to 0 for instant mint
        minter.mint(address(alice), vAmount, uAmount, 0, 0);

        // Burn USDV
        Snapshot memory _before = snapshot();
        minter.burn(address(alice), uAmount, vAmount, fee, window);
        Snapshot memory _after = snapshot();

        uint vFee = calcFee(vAmount, fee);
        uint mintAmount = vAmount - vFee;

        assertEq(_after.usdv.alice, _before.usdv.alice - uAmount);
        assertEq(_after.usdv.usdv, _before.usdv.usdv);

        if (window > 0) {
            assertEq(_after.vader.alice, _before.vader.alice);
            assertEq(_after.vader.usdv, _before.vader.usdv + mintAmount);

            uint count = usdv.getLockCount(address(alice));
            assertGt(count, 0);
            uint i = count - 1;

            (IUSDV.LockTypes lockType, uint amount, uint release)= usdv.locks(address(alice), i);
            assertEq(uint(lockType), 1);
            assertEq(amount, mintAmount);
            assertEq(release, block.timestamp + window);

            // Claim Vader
            hevm.warp(release);

            _before = snapshot();
            alice.claim(i);
            _after = snapshot();

            assertEq(usdv.getLockCount(address(alice)), count - 1);
            assertEq(_after.vader.alice, _before.vader.alice + mintAmount);
            assertEq(_after.vader.usdv, _before.vader.usdv - mintAmount);
        } else {
            assertEq(_after.vader.alice, _before.vader.alice + mintAmount);
            assertEq(_after.vader.usdv, _before.vader.usdv);
        }
    }

    function test_claimAll() public {
        uint vAmount = 10 * 1e18;
        uint uAmount = 1e18;
        uint fee = 100;
        uint window = 10;

        // Mint USDV
        uint totalUsdv;
        for (uint i; i < 3; i++) {
            vader.mint(address(alice), vAmount);
            alice.approve(address(usdv), vAmount);
            totalUsdv += minter.mint(address(alice), vAmount, uAmount, fee, window);
        }

        uint last = usdv.getLockCount(address(alice)) - 1;
        (, , uint release)= usdv.locks(address(alice), last);

        hevm.warp(release);

        Snapshot memory _before = snapshot();
        (uint usdvAmount, uint vaderAmount) = alice.claimAll();
        Snapshot memory _after = snapshot();

        assertEq(usdvAmount, totalUsdv);
        assertEq(vaderAmount, 0);

        assertEq(usdv.getLockCount(address(alice)), 0);
        assertEq(_after.usdv.alice, _before.usdv.alice + totalUsdv);
        assertEq(_after.usdv.usdv, _before.usdv.usdv - totalUsdv);
    }
}
