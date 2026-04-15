pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  using SafeMath for uint256;

  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping(address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  // ----------------------------
  // ERC20 storage
  // ----------------------------
  mapping(address => mapping(address => uint256)) private _allowances;

  // ----------------------------
  // Holder tracking (1-based index)
  // ----------------------------
  address[] private holders; // index 0 unused
  mapping(address => uint256) private holderIndex;

  // ----------------------------
  // Dividend tracking
  // ----------------------------
  mapping(address => uint256) private dividends;

  constructor() {
    holders.push(address(0)); // dummy to make list 1-based
  }

  // ----------------------------
  // IERC20
  // ----------------------------
  function allowance(address owner, address spender)
    external
    view
    override
    returns (uint256)
  {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 value)
    external
    override
    returns (bool)
  {
    _allowances[msg.sender][spender] = value;
    return true;
  }

  function transfer(address to, uint256 value)
    external
    override
    returns (bool)
  {
    _transfer(msg.sender, to, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value)
    external
    override
    returns (bool)
  {
    require(_allowances[from][msg.sender] >= value, "Allowance exceeded");
    _allowances[from][msg.sender] =
      _allowances[from][msg.sender].sub(value);

    _transfer(from, to, value);
    return true;
  }

  function _transfer(address from, address to, uint256 value) internal {
    require(balanceOf[from] >= value, "Insufficient balance");

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _updateHolder(from);
    _addHolder(to);
  }

  // ----------------------------
  // Mint/Burn
  // ----------------------------
  function mint() external payable override {
    require(msg.value > 0, "No ETH");

    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);

    _addHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "Nothing to burn");

    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);

    _removeHolder(msg.sender);

    (bool ok, ) = dest.call{ value: amount }("");
    require(ok, "ETH send failed");
  }

  // ----------------------------
  // Dividends
  // ----------------------------
  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length - 1;
  }

  function getTokenHolder(uint256 index)
    external
    view
    override
    returns (address)
  {
    require(index > 0 && index < holders.length, "Invalid index");
    return holders[index];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Empty dividend");

    uint256 amount = msg.value;

    for (uint256 i = 1; i < holders.length; i++) {
      address h = holders[i];
      uint256 bal = balanceOf[h];
      if (bal > 0) {
        uint256 share = amount.mul(bal).div(totalSupply);
        dividends[h] = dividends[h].add(share);
      }
    }
  }

  function getWithdrawableDividend(address payee)
    external
    view
    override
    returns (uint256)
  {
    return dividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = dividends[msg.sender];
    require(amount > 0, "No dividend");

    dividends[msg.sender] = 0;

    (bool ok, ) = dest.call{ value: amount }("");
    require(ok, "ETH send failed");
  }

  // ----------------------------
  // Holder helpers
  // ----------------------------
  function _addHolder(address h) internal {
    if (h == address(0)) return;
    if (balanceOf[h] == 0) return;
    if (holderIndex[h] != 0) return;

    holderIndex[h] = holders.length;
    holders.push(h);
  }

  function _removeHolder(address h) internal {
    uint256 idx = holderIndex[h];
    if (idx == 0) return;

    uint256 lastIdx = holders.length - 1;
    if (idx != lastIdx) {
      address last = holders[lastIdx];
      holders[idx] = last;
      holderIndex[last] = idx;
    }

    holders.pop();
    holderIndex[h] = 0;
  }

  function _updateHolder(address h) internal {
    if (balanceOf[h] == 0) {
      _removeHolder(h);
    }
  }

  receive() external payable {
    revert("Direct ETH not allowed");
  }
}
