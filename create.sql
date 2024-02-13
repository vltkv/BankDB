USE BankDatabase

CREATE TABLE CustomerData(
	customerID int PRIMARY KEY,
	pesel char(11) UNIQUE NOT NULL,
	firstName nvarchar(50) NOT NULL,
	lastName nvarchar(50) NOT NULL,
	addressID int NOT NULL,
	phoneNr  int NOT NULL,
	dateOfBirth date NOT NULL
);

CREATE TABLE AddressDetails(
	addressID int PRIMARY KEY,
	country nvarchar(20) NOT NULL,
	region nvarchar(40),
	city nvarchar(58) NOT NULL,
	postalCode nvarchar(6) NOT NULL,
	street nvarchar(85) NOT NULL,
	streetNumber nvarchar(10) NOT NULL,
	houseNumber nvarchar(3)
);

CREATE TABLE Employees(
	employeeID int PRIMARY KEY,
	firstName nvarchar(50) NOT NULL,
	lastName nvarchar(50) NOT NULL,
	hireDate date NOT NULL,
	departmentID int NOT NULL
);

CREATE TABLE Departments(
	departmentID int PRIMARY KEY,
	departmentName nvarchar(100) NOT NULL
);

CREATE TABLE CustomerHistory(
	requestID int PRIMARY KEY,
	customerID int NOT NULL,
	employeeID int NOT NULL,
	requestTypeID int NOT NULL,
	requestDate date NOT NULL
);

CREATE TABLE RequestsTypes(
	requestID int PRIMARY KEY,
	requestName nvarchar(50) NOT NULL,	--create type?
	requestDesc nvarchar(100)
);

CREATE TABLE LogInData(
	customerID int PRIMARY KEY,
	customerLogin nvarchar(10) NOT NULL,
	passwordHash BIGINT NOT NULL
);

CREATE TABLE CustomerAccount(
	customerID int NOT NULL,
	accountID int NOT NULL,
	PRIMARY KEY(customerID, accountID)
);

CREATE TABLE Accounts(
	accountID int PRIMARY KEY,
	accountNr nvarchar(26) UNIQUE NOT NULL,
	typeID int NOT NULL,
	currentBalance money DEFAULT 0,
	--availableBalance money DEFAULT 0
);

CREATE TABLE TransfersHistory(
	transferID int PRIMARY KEY,
	title nvarchar(140) NOT NULL,
	accountNr nvarchar(26),
	payeeAccountNr nvarchar(26),
	amount money NOT NULL
);

CREATE TABLE TransferDetails(
	transferID int PRIMARY KEY,
	payeeNameAndAddress nvarchar(140) NOT NULL,
	--type -> private or normal transfer
	dateOfTransfer date NOT NULL
);

CREATE TABLE AccountsTypes(
	typeID int PRIMARY KEY,
	typeName nvarchar(30) NOT NULL,
	bankRate decimal(4,2) NOT NULL
);

CREATE TABLE Currency(
	currencyID nvarchar(3) PRIMARY KEY,
	buyRate decimal(7,5) NOT NULL,
	sellRate decimal(7,5) NOT NULL
);

CREATE TABLE RatesHistory(
	currencyID nvarchar(3) NOT NULL,
	rateDate date NOT NULL,
	buyRate decimal(7,5) NOT NULL,
	sellRate decimal(7,5) NOT NULL,
	PRIMARY KEY(currencyID, rateDate)
);

ALTER TABLE LogInData
ADD CONSTRAINT FK_LogInData_CustomerData 
FOREIGN KEY (customerID) REFERENCES CustomerData(CustomerID);

ALTER TABLE CustomerHistory
ADD CONSTRAINT FK_CustomerHistory_CustomerData 
FOREIGN KEY (customerID) REFERENCES CustomerData(CustomerID) ON DELETE CASCADE;

ALTER TABLE CustomerHistory
ADD CONSTRAINT FK_CustomerHistory_Employees 
FOREIGN KEY (employeeID) REFERENCES Employees(employeeID);

ALTER TABLE CustomerHistory
ADD CONSTRAINT FK_CustomerHistory_RequestsTypes 
FOREIGN KEY (requestID) REFERENCES RequestsTypes(requestID);

ALTER TABLE CustomerAccount
ADD CONSTRAINT FK_CustomerAccount_CustomerData
FOREIGN KEY (customerID) REFERENCES CustomerData(CustomerID) ON DELETE CASCADE;

ALTER TABLE CustomerAccount
ADD CONSTRAINT FK_CustomerAccount_Accounts
FOREIGN KEY (accountID) REFERENCES Accounts(accountID) ON DELETE CASCADE;

ALTER TABLE CustomerData
ADD CONSTRAINT FK_CustomerData_AddressDetails
FOREIGN KEY (addressID) REFERENCES AddressDetails(addressID);

ALTER TABLE Employees 
ADD CONSTRAINT FK_Employees_Departments
FOREIGN KEY (departmentID) REFERENCES Departments(departmentID);

ALTER TABLE Accounts
ADD CONSTRAINT FK_Accounts_AccountsTypes
FOREIGN KEY (typeID) REFERENCES AccountsTypes(typeID);

ALTER TABLE TransfersHistory
ADD CONSTRAINT FK_TransfersHistory_Accounts
FOREIGN KEY (accountNr) REFERENCES Accounts(accountNr);

ALTER TABLE TransfersHistory
ADD CONSTRAINT FK_TransfersHistory_TransferDetails
FOREIGN KEY (transferID) REFERENCES TransferDetails(transferID);

ALTER TABLE RatesHistory
ADD CONSTRAINT FK_RatesHistory_Currency
FOREIGN KEY (currencyID) REFERENCES Currency(currencyID);
