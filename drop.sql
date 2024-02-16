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
ALTER TABLE TransfersHistory DROP CONSTRAINT FK_TransfersHistory_Accounts;
ALTER TABLE TransfersHistory DROP CONSTRAINT FK_TransfersHistory_Accounts2;
ALTER TABLE TransferDetails DROP CONSTRAINT FK_TransferDetails_TransfersHistory;
ALTER TABLE RatesHistory DROP CONSTRAINT FK_RatesHistory_Currency;

DROP TABLE dbo.Accounts
DROP TABLE dbo.AccountsTypes
DROP TABLE dbo.AddressDetails
DROP TABLE dbo.Currency
DROP TABLE dbo.CustomerAccount
DROP TABLE dbo.CustomerData
DROP TABLE dbo.CustomerHistory
DROP TABLE dbo.Departments
DROP TABLE dbo.Employees
DROP TABLE dbo.LogInData
DROP TABLE dbo.RatesHistory
DROP TABLE dbo.RequestsTypes
DROP TABLE dbo.TransferDetails
DROP TABLE dbo.TransfersHistory
