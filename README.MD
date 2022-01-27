AFRO FOUNDATION TOKEN

The Smart contract is based on the OpenZepellin Smart Contract for ERC20.
Few functionnalities has been added:
- ability to add a tax on every TX, send to the FundWallet that contains the PaymentSplitter
- ability to adjust tax rate beetween 0-5%
- ability to exclude/include wallet in Tax Fees (typically the FundWallet)
- Ability to change the adress of the FundWallet (PaymentSplitter), in case we need to change the smartcontract or else.


The PaymentSplitter smart contract, is based on OpenZepellin smart contract. It has the ability to collect 'tax' and split it on differents wallet,
based on the ratio for each address. Release of funds is done on request to avoid Transactions Fees.
