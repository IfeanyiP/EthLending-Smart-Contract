//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/*@title LendingDapp with collateral
*@author Ifeanyi paul Ezendukaku
*@notice This contract is a lending/borrowing ETH protocol against ERC20 collateral, But it lacks a crucial
* intergral part, which is the absense of a proper interest rate model and a liquidation mechanism
*/

/*

_acceptedTokenAddress = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81
   _usdtTokenAddress     = 0x36484e9f776d9696ff1bf2cb2c1d6faa2da7b37b
   _acceptedTokenUsdtPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306
*/

contract EthLending is ReentrancyGuard {
    //-----State Variables----

    // The ERC20 token accepted as collateral
    IERC20 public immutable collateralToken;

    // Chainlink price feed to get the price of collateral in ETH
    AggregatorV3Interface public immutable priceFeed;

    // Address of the contract owner for admin tasks
    address public owner;

    // Loan-to-value ratio (e.g., 75 means 75%)
    uint256 public ltvRatio = 75;

    // Total Eth available in the lending pool
    uint256 public ethPoolBalance;

    // Mapping of how much collateral each user has deposited
    mapping(address => uint256) public collateralDeposits;

    // Mapping of how much Eth each user has borrowed
    mapping(address => uint256) public ethBorrows;

    //----Events----
    event EthLent(address indexed lender, uint256 amount);
    event EthWithdrawn(address indexed lender, uint256 amount);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event EthBorrowed(address indexed borrower, uint256 amount);
    event LoanRepaid(address indexed borrower,uint256 amount);
    event CollateralWithdrawn(address indexed borrower, uint256 amount);

    //----Modifiers----
    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner can call this function");
        _;
    }

    //--- Collateral functions ----

    /*
    * @param _collateralTokenAddress The address of the ERC20 token for collateral
    *@param _priceFeedAddress the chainlink Price Feed for collateral/Eth price
    */
    constructor(address _collateralTokenAddress, address _priceFeedAddress) {
        collateralToken = IERC20(_collateralTokenAddress);
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        owner = msg.sender;
    }

    //----Lender Function----
    /*
    *@notice Allows users to lend Eth to the pool
    */
    function lendEth() external payable {
        require(msg.value > 0, "Must end more than 0 Eth.");
        ethPoolBalance += msg.value;
        emit EthLent(msg.sender, msg.value);
    }

    // ----Borrower Functions----
    /*
    *@notice Allows users to deposit ERC20 collateral
    *@dev User must aprove the contract to spend their tokens first.
    */

    function depositCollateral(uint256 _amount) external nonReentrant {
        require(_amount > 0, "must deposit more than 0 collateral");
        collateralDeposits[msg.sender] += _amount;

        // Pull the collateral from the user's wallet to this contract
        bool success = collateralToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Collateral transfer failed.");

        emit CollateralDeposited(msg.sender, _amount);
    }

    /*
    *@notice Allows users with sufficient collateral to borrow Eth.
    */

    function borrowEth(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Must borrow more than 0 Eth");
        require(collateralDeposits[msg.sender] > 0, "No collateral deposited");

        uint256 maxBorrowableEth = getmaxBorrowableEth(msg.sender);
        uint256 currentBorrows = ethBorrows[msg.sender];

        require(currentBorrows + _amount <= maxBorrowableEth, "Borrow amount exceeds LTV limit");
        require(ethPoolBalance >= _amount, "Not enough Eth in the pool");

        ethPoolBalance -= _amount;
        ethBorrows[msg.sender] += _amount;

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Eth transfer failed");

        emit EthBorrowed(msg.sender, _amount);
    }

    /*
    * @notice Allows borrowers to repay their Eth loan
    * @dev For simplicity, this example does not include interest
    */

    function repayLoan() external payable nonReentrant {
        uint256 borrowedAmount = ethBorrows[msg.sender];
        require(borrowedAmount > 0, "Yoou have no outstanding loan");
        require(msg.value >= borrowedAmount, "Sent eth is less than borrowed amount");

        ethBorrows[msg.sender] = 0;
        ethPoolBalance += borrowedAmount;

        //Refund any overpayment
        if (msg.value > borrowedAmount) {
            (bool success, ) = msg.sender.call{value: msg.value - borrowedAmount}("");
            require(success, "Refund failed");
        }

        emit LoanRepaid(msg.sender, borrowedAmount);
    }

    /*
    * @notice Allows users to withhdraw their collateral after repaying loans
    */

    function withdrawCollateral(uint256 _amount) external nonReentrant {
        require(ethBorrows[msg.sender] == 0, "Repay your loan before withdrawing collatral");
        require(_amount > 0, "Withdraw amount must be positive");
        require(collateralDeposits[msg.sender] >= _amount, "Insufficient collateral balance");

        collateralDeposits[msg.sender] -= _amount;

        bool success = collateralToken.transfer(msg.sender, _amount);
        require(success, "Collateral transfer failed");

        emit CollateralWithdrawn(msg.sender, _amount);
    }

    //---Helper Functions----
    /*
    * @notice Calculates the maximum Eth a user can borrow based on their collateral
    */
    function getmaxBorrowableEth(address _user) public view returns (uint256) {
        uint256 collateralAmount = collateralDeposits[_user];
        if (collateralAmount == 0) {
            return 0;
        }

        //get the price of collateral in Eth from chainlink
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 collateralValueInEth = (collateralAmount * uint256(price)) / 1e18; // Assuming collateral has 18 decimals

        return (collateralValueInEth * ltvRatio) / 100; 
    }
}