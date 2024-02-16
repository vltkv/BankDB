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
	transferDate date NOT NULL,
	cardID int
);

CREATE TABLE AccountsTypes(
	typeID int PRIMARY KEY,
	typeName nvarchar(30) NOT NULL, --normal, curr (for each currency), savings, deposit
	bankRate decimal(4,2) NOT NULL,
	currencyID nvarchar(3) NOT NULL
	-- for loan
	--depositDate date,
	--loanInstallment money,
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

ALTER TABLE AccountsTypes
ADD CONSTRAINT FK_AccountsTypes_Currency
FOREIGN KEY (currencyID) REFERENCES Currency(currencyID);

ALTER TABLE TransfersHistory
ADD CONSTRAINT FK_TransfersHistory_Accounts
FOREIGN KEY (accountNr) REFERENCES Accounts(accountNr);

ALTER TABLE TransfersHistory
ADD CONSTRAINT FK_TransfersHistory_Accounts2
FOREIGN KEY (payeeAccountNr) REFERENCES Accounts(accountNr);

ALTER TABLE TransferDetails
ADD CONSTRAINT FK_TransferDetails_TransfersHistory
FOREIGN KEY (transferID) REFERENCES TransfersHistory(transferID);

ALTER TABLE RatesHistory
ADD CONSTRAINT FK_RatesHistory_Currency
FOREIGN KEY (currencyID) REFERENCES Currency(currencyID);

---procedures
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SET XACT_ABORT ON;


--DROP PROCEDURE makeTransfer;

CREATE PROCEDURE makeTransfer
	@transferID int,
	@title nvarchar(140),
	@accountNr nvarchar(26),
	@payeeAccountNr nvarchar(26),
	@amount money,
	@payeeNameAndAddress nvarchar(140),
	@transferDate date,
	@cardID int = NULL
AS
BEGIN
	SET NOCOUNT ON;

	IF NOT EXISTS (SELECT * FROM Accounts WHERE accountNr = @accountNr)	-- transfer from external account
	BEGIN
		IF  NOT EXISTS (SELECT * FROM Accounts WHERE accountNr = @payeeAccountNr) -- transfer between two external accounts
		BEGIN
			PRINT 'Nie można wykonać przelewu pomiędzy dwoma kontami spoza banku'
			RETURN
		END
		BEGIN TRANSACTION
			UPDATE Accounts SET currentBalance = currentBalance + @amount WHERE accountNr =  @payeeAccountNr;
			INSERT INTO TransfersHistory VALUES (@transferID, @title, NULL, @payeeAccountNr, @amount);
			INSERT INTO TransferDetails VALUES (@transferID, @payeeNameAndAddress, @transferDate, @cardID);
		COMMIT;	
	END

	ELSE IF NOT EXISTS (SELECT * FROM Accounts WHERE accountNr = @payeeAccountNr) -- transfer on external account
	BEGIN
		BEGIN TRANSACTION
			DECLARE @balance1 money;
			SELECT @balance1 = currentBalance FROM Accounts WHERE accountNr = @accountNr;
			IF @balance1 < @amount
			BEGIN
				PRINT 'Nie masz wystarczających środków na koncie.';
			END	
			ELSE
			BEGIN
				UPDATE Accounts SET currentBalance = currentBalance - @amount WHERE accountNr = @accountNr;
				INSERT INTO TransfersHistory VALUES (@transferID, @title, @accountNr, NULL, @amount);
				INSERT INTO TransferDetails VALUES (@transferID, @payeeNameAndAddress, @transferDate, @cardID);
			END
		COMMIT;	
	END

	ELSE
	BEGIN
		DECLARE @accID int, @payeeAccID int; -- find accountID
		SELECT @accID = accountID FROM Accounts WHERE accountNr = @accountNr;
		SELECT @payeeAccID = accountID FROM Accounts WHERE accountNr = @payeeAccountNr;

		DECLARE @currID nvarchar(3), @payeeCurrID nvarchar(3); -- find currency
		SET @currID = (SELECT currencyID FROM Accounts JOIN AccountsTypes ON Accounts.typeID = AccountsTypes.typeID
					   WHERE accountID = @accID)
		SET @payeeCurrID = (SELECT currencyID FROM Accounts JOIN AccountsTypes ON Accounts.typeID = AccountsTypes.typeID
					   WHERE accountID = @payeeAccID)

		DECLARE @payerID int, @payeeID int;
		SELECT @payerID = customerID FROM CustomerAccount WHERE accountID = @accID;
		SELECT @payeeID = customerID FROM CustomerAccount WHERE accountID = @payeeAccID;

		IF @currID <> @payeeCurrID 
		BEGIN
			IF @payerID <> @payeeID
			BEGIN
				PRINT 'Niezgodność walut. Spróbuj wykonać przelew z konta walutowego.';
			END
			ELSE	-- one customer's transfer
			BEGIN
				DECLARE @sell decimal(7,5), @buy decimal(7,5);
				SELECT @sell = sellRate FROM Currency WHERE currencyID = @currID;
				SELECT @buy = buyRate FROM Currency WHERE currencyID = @payeeCurrID;

				BEGIN TRANSACTION
					DECLARE @balance2 money;
					SELECT @balance2 = currentBalance FROM Accounts WHERE accountNr = @accountNr;
					IF @balance2 < @amount
					BEGIN
						PRINT 'Nie masz wystarczających środków na koncie.';
					END
					ELSE
					BEGIN
						UPDATE Accounts SET currentBalance = currentBalance - @amount WHERE accountNr = @accountNr;
						SET @amount = @amount * @sell * @buy;
						UPDATE Accounts SET currentBalance = currentBalance + @amount WHERE accountNr = @payeeAccountNr;
						INSERT INTO TransfersHistory VALUES (@transferID, @title, @accountNr, @payeeAccountNr, @amount);
						INSERT INTO TransferDetails VALUES (@transferID, @payeeNameAndAddress, @transferDate, @cardID);
					END
				COMMIT;
			END
		END
		ELSE
		BEGIN
			BEGIN TRANSACTION
				DECLARE @balance3 money;
				SELECT @balance3 = currentBalance FROM Accounts WHERE accountNr = @accountNr;
				IF @balance3 < @amount
				BEGIN
					PRINT 'Nie masz wystarczających środków na koncie.';
				END
				ELSE
				BEGIN
					UPDATE Accounts SET currentBalance = currentBalance - @amount WHERE accountNr = @accountNr;
					UPDATE Accounts SET currentBalance = currentBalance + @amount WHERE accountNr = @payeeAccountNr;
					INSERT INTO TransfersHistory VALUES (@transferID, @title, @accountNr, @payeeAccountNr, @amount);
					INSERT INTO TransferDetails VALUES (@transferID, @payeeNameAndAddress, @transferDate, @cardID);
				END
			COMMIT;
		END
	END
END;


--Tests

INSERT INTO Currency VALUES ('PLN', 1, 1);
INSERT INTO Currency VALUES ('EUR', 0.23, 4.35);

INSERT INTO AccountsTypes VALUES (1, 'Normalne', 1.0, 'PLN');
INSERT INTO AccountsTypes VALUES (2, 'Euro', 0.0, 'EUR');

INSERT INTO Accounts VALUES (1, 'numerKonta1', 1, 500);
INSERT INTO Accounts VALUES (2, 'numerKonta2', 2, 100);
INSERT INTO Accounts VALUES (3, 'numerKonta3', 1, 1000);

INSERT INTO CustomerAccount VALUES (1, 1);
INSERT INTO CustomerAccount VALUES (1, 2);
INSERT INTO CustomerAccount VALUES (2, 3);


SELECT * FROM CustomerAccount;
SELECT * FROM Currency;
SELECT * FROM AccountsTypes;
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 1, 'przelew pierwszy', 'numerKonta1', 'numerKonta3', 100, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 2, 'przelew drugi walutowy', 'numerKonta1', 'numerKonta2', 100, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 3, 'przelew trzeci, ma się nie udać, zle waluty', 'numerKonta2', 'numerKonta3', 100, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 4, 'przelew czwarty, z nieznanego konta', 'numerKonta20', 'numerKonta1', 400, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 5, 'przelew piąty, na nieznane konto', 'numerKonta3', 'numerKonta10', 400, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM TransfersHistory;
SELECT * FROM TransferDetails;

DELETE FROM TransferDetails;
DELETE FROM TransfersHistory;