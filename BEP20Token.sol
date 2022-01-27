pragma solidity 0.5.16;

/****************************************
 *                                      *
 *       AFROFOUNDATION AFRO TOKEN      *
 *                                      *
 ****************************************/

import "./Context.sol";
import "./IBEP20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract BEP20Token is Context, IBEP20, Ownable {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 private _totalSupply;
  uint8 private _decimals;
  string private _symbol;
  string private _name;

  address private _fundWallet;
  address private _previousFundWallet = _fundWallet;

  //taxfee beetween 0 and 500 to get 2 decimals (5=0.05% // 200=2% // 500=5%)
  uint256 private _taxFee = 0;
  uint256 private _previoustaxFee = _taxFee;

  mapping (address => bool) private _isExcludedFromFee;

  constructor() public {
    _name = "AFRO";
    _symbol = "AFRO";
    _decimals = 8;


    _isExcludedFromFee[msg.sender] = true;
    _isExcludedFromFee[address(this)] = true;

    //if fundwallet is different from '' when launching AFRO TOKEN
    //_isExcludedFromFee[_fundWallet] = true;

    _mint(msg.sender, 764860000000 * (10 ** 8));
  }

  /**
   * @dev Returns the bep token owner.
   */
  function getOwner() external view returns (address) {
    return owner();
  }

  /**
   * @dev Returns the token decimals.
   */
  function decimals() external view returns (uint8) {
    return _decimals;
  }

  /**
   * @dev Returns the token symbol.
   */
  function symbol() external view returns (string memory) {
    return _symbol;
  }

  /**
  * @dev Returns the token name.
  */
  function name() external view returns (string memory) {
    return _name;
  }

  /**
   * @dev See {BEP20-totalSupply}.
   */
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev See {BEP20-balanceOf}.
   */
  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  /**
   * @dev See {BEP20-transfer}.
   *
   * Requirements:
   *
   * - `recipient` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address recipient, uint256 amount) external returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  /**
   * @dev See {BEP20-allowance}.
   */
  function allowance(address owner, address spender) external view returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @dev See {BEP20-approve}.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) external returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  /**
   * @dev See {BEP20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {BEP20};
   *
   * Requirements:
   * - `sender` and `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   * - the caller must have allowance for `sender`'s tokens of at least
   * `amount`.
   */
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }

  /**
   * @dev Atomically increases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  /**
   * @dev Atomically decreases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `spender` must have allowance for the caller of at least
   * `subtractedValue`.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  /**
   * @dev Burn `amount` tokens and decreasing the total supply.
   *
   * Requirements
   *
   * - `msg.sender` must be the token owner
   */
  function burn(uint256 amount) public {
       _burn(_msgSender(), amount);
   }


  /**
   * @dev Moves tokens `amount` from `sender` to `recipient`.
   *
   * This is internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `sender` cannot be the zero address.
   * - `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   */
  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "BEP20: transfer from the zero address");
    require(recipient != address(0), "BEP20: transfer to the zero address");

    _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");

    //check if fee should be deducted from transfer
    uint fee;
    uint taxedValue;

    //if any account belongs to _isExcludedFromFee account or if _taxFee=0 then remove the fee
    if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient] || _taxFee == 0){
      fee = 0;
      taxedValue = amount;
    } else {
      fee = SafeMath.div(SafeMath.mul(amount, SafeMath.div(_taxFee,100)), 100);
      taxedValue = SafeMath.sub(amount, fee);

      //as we have a tax, we send it to the tax smartcontract
      _balances[_fundWallet] = _balances[_fundWallet].add(fee);
      emit Transfer(sender, _fundWallet, fee);
    }

    _balances[recipient] = _balances[recipient].add(taxedValue);
    emit Transfer(sender, recipient, taxedValue);
  }

  /** @dev Creates `amount` tokens and assigns them to `account`, increasing
   * the total supply.
   *
   * Emits a {Transfer} event with `from` set to the zero address.
   *
   * Requirements
   *
   * - `to` cannot be the zero address.
   */
  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: mint to the zero address");

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Transfer} event with `to` set to the zero address.
   *
   * Requirements
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens.
   */
  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: burn from the zero address");

    _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");

    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  /**
   * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
   *
   * This is internal function is equivalent to `approve`, and can be used to
   * e.g. set automatic allowances for certain subsystems, etc.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `owner` cannot be the zero address.
   * - `spender` cannot be the zero address.
   */
  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
   * from the caller's allowance.
   *
   * See {_burn} and {_approve}.
   */
  function _burnFrom(address account, uint256 amount) internal {
    _burn(account, amount);
    _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance"));
  }

  //test dev  taxable token
  function calculateTaxFee(uint256 _amount) external view returns (uint256) {
      return _amount.mul(SafeMath.div(_taxFee,100)).div(
          100
      );
  }

  function getTaxFee() external view returns(uint256) {
      return _taxFee;
  }

  function setTaxFee(uint256 taxFee) external onlyOwner() {
      require(taxFee >= 0 && taxFee <= 500, 'taxFee should be in 0 - 500');
      _taxFee = taxFee;
  }

  function getFundWallet() external view returns(address) {
      return _fundWallet;
  }

  function getPreviousFundWallet() external view returns(address) {
      return _previousFundWallet;
  }

  function setFundWallet(address fundWallet) external onlyOwner() {
    require(fundWallet != address(0), "BEP20: fundwallet from the zero address");

      _previousFundWallet = _fundWallet;
      _fundWallet = fundWallet;

      _isExcludedFromFee[_fundWallet] = true;
      _isExcludedFromFee[_previousFundWallet] = false;

  }

  function excludeFromFee(address account) public onlyOwner() {
      _isExcludedFromFee[account] = true;
  }

  function includeInFee(address account) public onlyOwner() {
      _isExcludedFromFee[account] = false;
  }

  function isExcludedFromFee(address account) external view returns(bool) {
      return _isExcludedFromFee[account];
  }
}
