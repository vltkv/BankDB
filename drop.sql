USE BankDatabase

ALTER TABLE LogInData DROP CONSTRAINT FK_LogInData_CustomerData;
ALTER TABLE CustomerHistory DROP CONSTRAINT FK_CustomerHistory_CustomerData;
ALTER TABLE CustomerHistory DROP CONSTRAINT FK_CustomerHistory_Employees;
ALTER TABLE CustomerHistory DROP CONSTRAINT FK_CustomerHistory_RequestsTypes;
ALTER TABLE CustomerAccount DROP CONSTRAINT FK_CustomerAccount_CustomerData;
ALTER TABLE CustomerAccount DROP CONSTRAINT FK_CustomerAccount_Accounts;
ALTER TABLE CustomerData DROP CONSTRAINT FK_CustomerData_AddressDetails;
ALTER TABLE Employees  DROP CONSTRAINT FK_Employees_Departments;
ALTER TABLE Accounts DROP CONSTRAINT FK_Accounts_AccountsTypes;
ALTER TABLE Deposits DROP CONSTRAINT FK_Deposits_Accounts;
ALTER TABLE Deposits DROP CONSTRAINT FK_Cards_Accounts;
ALTER TABLE AccountsTypes DROP CONSTRAINT FK_AccountsTypes_Currency;
ALTER TABLE TransferDetails DROP CONSTRAINT FK_TransferDetails_TransfersHistory;
ALTER TABLE RatesHistory DROP CONSTRAINT FK_RatesHistory_Currency;

DROP INDEX Accounts.accountNrIdx;
DROP INDEX AddressDetails.addressIdx;

DROP TRIGGER OnCurrencyUpdate;
DROP TRIGGER OnCurrencyInsert;
DROP TRIGGER LoginCheck;
DROP TRIGGER insertDeposit;
DROP TRIGGER deleteDeposit; 
DROP TRIGGER peselCheck;

DROP TABLE dbo.Accounts
DROP TABLE dbo.AccountsTypes
DROP TABLE dbo.AddressDetails
DROP TABLE dbo.Currency
DROP TABLE dbo.CustomerAccount
DROP TABLE dbo.CustomerData
DROP TABLE dbo.CustomerHistory
DROP TABLE dbo.Departments
DROP TABLE dbo.Deposits
DROP TABLE dbo.Cards
DROP TABLE dbo.Employees
DROP TABLE dbo.LogInData
DROP TABLE dbo.RatesHistory
DROP TABLE dbo.RequestsTypes
DROP TABLE dbo.TransferDetails
DROP TABLE dbo.TransfersHistory

DROP PROCEDURE AddRatesHistory;
DROP PROCEDURE AddAddressDetails;
DROP PROCEDURE AddCustomerData;
DROP PROCEDURE AddCustomer;
DROP PROCEDURE AddAccount;
DROP PROCEDURE makeTransfer;
DROP PROCEDURE checkCurrency;
DROP PROCEDURE openDeposit;
DROP PROCEDURE closeDeposit;
DROP PROCEDURE calculateAvg;
DROP PROCEDURE withdrawalInterest;