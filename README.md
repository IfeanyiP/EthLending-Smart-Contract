# EthLend: A Transparent P2P Lending Protocol 🚀

Welcome to **EthLend**, a decentralized, peer-to-peer lending protocol built on the Ethereum blockchain. This project is designed to fundamentally change the lending game by removing intermediaries and creating a trustless financial system where the rules are transparent, immutable, and auditable by anyone.

Our smart contract acts as an autonomous digital vault, allowing users to lend ETH to a common pool and others to borrow from it by providing ERC20 tokens as collateral. The entire process is governed by code, not by a corporation, ensuring fairness and security for all participants.

## 💡 Core Concepts

The protocol is built around two key roles:

  * **Lenders:** Users who have spare ETH can deposit it into the contract's lending pool. In a future version, they would earn interest on their deposits as borrowers pay back their loans.
  * **Borrowers:** Users who need ETH can deposit a valuable ERC20 token (like wrapped Bitcoin - WBTC, or a stablecoin - DAI) as collateral. Based on the value of their collateral, they can borrow ETH from the pool.

The value of the collateral is determined in real-time by an impartial and decentralized **Chainlink Price Feed**, ensuring that the loan-to-value calculations are always based on current market data, not on anyone's opinion.

-----

## 🔧 How It Works: A Deep Dive into the Code

The `EthLending.sol` smart contract is the heart of the protocol. Let's break down its essential parts step-by-step.

### The Blueprint: `constructor`

The constructor sets the immutable rules of our lending pool when it's first deployed. These rules cannot be changed later, guaranteeing predictability and security.

```solidity
constructor(address _collateralTokenAddress, address _priceFeedAddress) {
    collateralToken = IERC20(_collateralTokenAddress);
    priceFeed = AggregatorV3Interface(_priceFeedAddress);
    owner = msg.sender;
}
```

  * **`_collateralTokenAddress`**: We permanently define which ERC20 token will be accepted as collateral.
  * **`_priceFeedAddress`**: We set the specific Chainlink Price Feed that the contract will trust to get the value of the collateral token against ETH.
  * **`owner`**: We assign the deployer of the contract as the `owner`, who has limited administrative privileges like setting the LTV ratio.

-----

### For Lenders: Powering the Pool

#### `lendEth()`

This function is the entry point for lenders. It's a `payable` function, meaning it's designed to receive ETH.

```solidity
function lendEth() external payable {
    require(msg.value > 0, "Must lend more than 0 ETH.");
    ethPoolBalance += msg.value;
    emit EthLent(msg.sender, msg.value);
}
```

  * **How it works:** A user sends a transaction to this function along with some ETH. The contract increases its internal counter `ethPoolBalance`, effectively adding the user's funds to the total lending pool available for borrowing.

-----

### For Borrowers: Securing a Loan

The borrowing process is a three-step dance: deposit, borrow, and repay.

#### 1\. `depositCollateral(uint256 _amount)`

Before a user can borrow, they must deposit their ERC20 collateral into the contract for safekeeping.

```solidity
function depositCollateral(uint256 _amount) external nonReentrant {
    collateralDeposits[msg.sender] += _amount;
    
    // Pull the collateral from the user's wallet to this contract.
    bool success = collateralToken.transferFrom(msg.sender, address(this), _amount);
    require(success, "Collateral transfer failed.");
}
```

  * **How it works:** This function uses the ERC20 `transferFrom` method. This requires the borrower to have **first `approve`d** our contract to spend their tokens. The contract then securely pulls the approved amount and locks it inside, updating the `collateralDeposits` mapping to remember who owns what.

#### 2\. `borrowEth(uint256 _amount)`

This is the core function for borrowers. It checks if the user is eligible to borrow and, if so, sends them the ETH.

```solidity
function borrowEth(uint256 _amount) external nonReentrant {
    uint256 maxBorrowableEth = getmaxBorrowableEth(msg.sender);
    // ...
    require(currentBorrows + _amount <= maxBorrowableEth, "Borrow amount exceeds LTV limit.");
    require(ethPoolBalance >= _amount, "Not enough ETH in the pool.");
    // ...
    (bool success, ) = msg.sender.call{value: _amount}("");
    require(success, "ETH transfer failed.");
}
```

  * **How it works:**
    1.  It first calls `getmaxBorrowableEth()`, our helper function that consults the Chainlink oracle to find the real-time value of the user's deposited collateral.
    2.  It calculates the maximum amount of ETH the user can borrow based on the **Loan-to-Value (`ltvRatio`)**, which is set to 75% by default.
    3.  It ensures the user isn't trying to borrow more than they are allowed and that the pool has enough ETH.
    4.  If all checks pass, it sends the requested ETH to the borrower.

#### 3\. `repayLoan()` and `withdrawCollateral(uint256 _amount)`

Once the borrower is ready, they can repay the loan and get their collateral back.

```solidity
function repayLoan() external payable nonReentrant {
    // ... checks if the user sent enough ETH to cover the loan ...
    ethBorrows[msg.sender] = 0;
    ethPoolBalance += borrowedAmount;
}

function withdrawCollateral(uint256 _amount) external nonReentrant {
    require(ethBorrows[msg.sender] == 0, "Repay your loan before withdrawing collateral.");
    // ... sends the collateral back to the user ...
}
```

  * **How it works:** The user calls `repayLoan()` and sends the borrowed ETH back to the contract. Once their loan balance is zero, they are free to call `withdrawCollateral()` to retrieve the ERC20 tokens they initially deposited.

-----

## 🔐 The Transparency Revolution

How does this smart contract change the lending game?

  * **Immutable Rules:** The core logic—how loans are calculated, who can withdraw, and how collateral is handled—is permanently baked into the blockchain. It cannot be altered by a company or a bad actor.
  * **Public Ledger:** Every single transaction—every deposit, every borrow, every repayment—is publicly recorded on the Ethereum blockchain. Anyone can audit the contract's entire history to verify its solvency and fairness.
  * **Verifiable Logic:** You don't have to trust a bank's hidden software. Our entire codebase is open-source. Anyone can read it to understand exactly how the `ltvRatio` is calculated and applied. What you see is what you get.
  * **No Intermediaries:** The contract is the bank. There's no loan officer to deny you based on personal bias, no company taking a hidden cut, and no one who can freeze your assets. Your ability to borrow is based purely on the value of your collateral, as determined by impartial data.

## 🔮 Future Improvements & Security Considerations

This contract is a powerful proof-of-concept. For a production-ready system, the following features are on our roadmap:

  * **Liquidation Engine:** An automated mechanism to sell a borrower's collateral if its value drops too low, ensuring lenders' funds are always protected.
  * **Dynamic Interest Rates:** An algorithm to calculate interest for lenders and borrowing fees for borrowers based on supply and demand.
  * **Professional Security Audit:** Before handling real user funds, this contract must undergo a rigorous security audit by a reputable firm.

We invite you to explore the code, test it, and join us in building a more transparent and equitable financial future.
