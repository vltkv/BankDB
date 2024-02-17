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
	requestName nvarchar(50) NOT NULL,
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
);

CREATE TABLE Deposits(
	depositID int PRIMARY KEY IDENTITY(1,1),
	accountID int UNIQUE NOT NULL,
	balance money NOT NULL,
	bankRate decimal(4,2) NOT NULL,
	openDate date NOT NULL,
	duration int NOT NULL -- in months
);

CREATE TABLE TransfersHistory(
	transferID int PRIMARY KEY IDENTITY(1,1),
	title nvarchar(140) NOT NULL,
	accountNr nvarchar(26) NOT NULL,
	payeeAccountNr nvarchar(26) NOT NULL,
	amount money NOT NULL
);

CREATE TABLE TransferDetails(
	transferID int PRIMARY KEY,
	payeeNameAndAddress nvarchar(140) NOT NULL,
	transferDate date NOT NULL,
	cardID int
);

CREATE TABLE AccountsTypes(
	typeID int PRIMARY KEY,
	typeName nvarchar(30) NOT NULL, -- normal, curr (for each currency), savings
	bankRate decimal(4,2) DEFAULT 0.0,
	currencyID nvarchar(3) NOT NULL
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

---------- foreign keys --------------------
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

ALTER TABLE Deposits
ADD CONSTRAINT FK_Deposits_Accounts
FOREIGN KEY (accountID) REFERENCES Accounts(accountID);

ALTER TABLE AccountsTypes
ADD CONSTRAINT FK_AccountsTypes_Currency
FOREIGN KEY (currencyID) REFERENCES Currency(currencyID);

ALTER TABLE TransferDetails
ADD CONSTRAINT FK_TransferDetails_TransfersHistory
FOREIGN KEY (transferID) REFERENCES TransfersHistory(transferID);

ALTER TABLE RatesHistory
ADD CONSTRAINT FK_RatesHistory_Currency
FOREIGN KEY (currencyID) REFERENCES Currency(currencyID);

----------- procedures and triggers ---------------------
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SET XACT_ABORT ON;


CREATE PROCEDURE checkCurrency
	@accountNr nvarchar(26),
	@payeeAccountNr nvarchar(26),
	@amount money OUTPUT
AS
BEGIN
	DECLARE @accID int, @payeeAccID int; -- find accountID
	SELECT @accID = accountID FROM Accounts WHERE accountNr = @accountNr;
	SELECT @payeeAccID = accountID FROM Accounts WHERE accountNr = @payeeAccountNr;

	DECLARE @currID nvarchar(3), @payeeCurrID nvarchar(3); -- find currency
	SET @currID = (SELECT currencyID FROM Accounts JOIN AccountsTypes ON Accounts.typeID = AccountsTypes.typeID WHERE accountID = @accID)
	SET @payeeCurrID = (SELECT currencyID FROM Accounts JOIN AccountsTypes ON Accounts.typeID = AccountsTypes.typeID WHERE accountID = @payeeAccID)

	DECLARE @payerID int, @payeeID int;
	SELECT @payerID = customerID FROM CustomerAccount WHERE accountID = @accID;
	SELECT @payeeID = customerID FROM CustomerAccount WHERE accountID = @payeeAccID;

	IF @currID <> @payeeCurrID 
	BEGIN
		IF @payerID <> @payeeID
		BEGIN
			PRINT 'Niezgodność walut. Spróbuj wykonać przelew z konta walutowego.';
			RETURN -1;
		END
		ELSE	-- one customer's transfer
		BEGIN
			DECLARE @sell decimal(7,5), @buy decimal(7,5);
			SELECT @sell = sellRate FROM Currency WHERE currencyID = @currID;
			SELECT @buy = buyRate FROM Currency WHERE currencyID = @payeeCurrID;
			SET @amount = @amount * @sell * @buy;
		END
	END
END;

-- DROP PROCEDURE makeTransfer;

CREATE PROCEDURE makeTransfer
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
	DECLARE @id int, @balance money;

	IF NOT EXISTS (SELECT * FROM Accounts WHERE accountNr = @accountNr)	-- transfer from external account
	BEGIN
		IF  NOT EXISTS (SELECT * FROM Accounts WHERE accountNr = @payeeAccountNr) -- transfer between two external accounts
		BEGIN
			PRINT 'Nie można wykonać przelewu pomiędzy dwoma kontami spoza banku'
			RETURN -1;
		END
		BEGIN TRANSACTION
			UPDATE Accounts SET currentBalance = currentBalance + @amount WHERE accountNr =  @payeeAccountNr;
			INSERT INTO TransfersHistory VALUES (@title, @accountNr, @payeeAccountNr, @amount);
			SELECT @id = IDENT_CURRENT('TransfersHistory')
			INSERT INTO TransferDetails VALUES (@id, @payeeNameAndAddress, @transferDate, @cardID);
		COMMIT;	
		RETURN;
	END
	
	DECLARE @status int, @amount2 money;	-- check if there are any problems with currency
	SET @amount2 = @amount;
	EXEC @status = checkCurrency @accountNr, @payeeAccountNr, @amount2 OUTPUT;

	IF @status <> 0
		RETURN -1;

	BEGIN TRANSACTION
		SELECT @balance = currentBalance FROM Accounts WHERE accountNr = @accountNr;
			IF @balance < @amount
			BEGIN
				PRINT 'Nie masz wystarczających środków na koncie.';
				RETURN -1;
			END	
			UPDATE Accounts SET currentBalance = currentBalance - @amount WHERE accountNr = @accountNr;
			IF EXISTS (SELECT * FROM Accounts WHERE accountNr = @payeeAccountNr)		-- transfer on account in our bank
				UPDATE Accounts SET currentBalance = currentBalance + @amount2 WHERE accountNr = @payeeAccountNr;						
			INSERT INTO TransfersHistory VALUES (@title, @accountNr, @payeeAccountNr, @amount);
			SELECT @id = IDENT_CURRENT('TransfersHistory')
			INSERT INTO TransferDetails VALUES (@id, @payeeNameAndAddress, @transferDate, @cardID)
	COMMIT;
END;


CREATE TRIGGER insertDeposit
ON Deposits AFTER INSERT
AS
BEGIN
	DECLARE @accountID int;
	SELECT @accountID = @accountID FROM Inserted;
	DECLARE @customerID int;
	SELECT @customerID = @customerID FROM CustomerAccount WHERE accountID = @accountID;	-- co zrobic jak jest dwoch cusomerow?

	-- tutaj uzupelnic to podobnie do tego jak Kuba wstawia tworzenie kont :))
END;
CREATE TRIGGER deleteDeposit
ON Deposits AFTER DELETED
AS
BEGIN
	-- a tutaj tez wstaienie do CustomerHistory, ale tym razem ze lokata zostala zamknieta
END;

-- DROP PROCEDURE openDeposit
CREATE PROCEDURE openDeposit
	@accountID int,
	@balance money,
	@bankRate decimal (4,2),
	@openDate date,
	@duration int
AS
BEGIN
	BEGIN TRANSACTION
		DECLARE @status int, @accountNr nvarchar(26);
		SELECT @accountNr = accountNr FROM Accounts WHERE accountID = @accountID;
		EXEC @status = makeTransfer 'open deposit', @accountNr, 'BANK-DEPOSIT', @balance, 'BANK-DEPOSIT', @openDate, NULL;
		IF @status <> 0
			RETURN -1;
		INSERT INTO Deposits VALUES (@accountID, @balance, @bankRate, @openDate, @duration);
	COMMIT;
END;

-- DROP PROCEDURE closeDeposit
CREATE PROCEDURE closeDeposit
	@depositID int,
	@currDate date
AS
BEGIN
	DECLARE @accountID int, @openDate date, @duration int, @amount money, @accountNr nvarchar(26);
	SELECT @accountID = accountID FROM Deposits WHERE depositID = @depositID;
	SELECT @openDate = openDate FROM Deposits WHERE depositID = @depositID;
	SELECT @duration = duration FROM Deposits WHERE depositID = @depositID;
	SELECT @amount = balance FROM Deposits WHERE depositID = @depositID;
	SELECT @accountNr = accountNr FROM Accounts WHERE accountID = @accountID;

	IF @currDate >= DATEADD(month, @duration, @openDate)
	BEGIN
		DECLARE @rate decimal(4,2);
		SELECT @rate = bankRate FROM Deposits WHERE depositID = @depositID;
		SET @amount = @amount + (@amount * @rate * @duration /12);
	END
	 
	BEGIN TRANSACTION
		DECLARE @status int;
		EXEC @status = makeTransfer 'close deposit', 'BANK-DEPOSIT', @accountNr,  @amount, 'BANK-DEPOSIT', @currDate, NULL;
		IF @status <> 0
			RETURN;
		DELETE FROM Deposits WHERE depositID = @depositID;
	COMMIT;
END;


-- DROP PROCEDURE calculateAvg

CREATE PROCEDURE calculateAvg
	@accountID int,
	@currentDate date,
	@avgBalance money OUTPUT
AS
BEGIN
	DECLARE @accountNr varchar(26)
	SELECT @accountNr = accountNr FROM Accounts WHERE accountID = @accountID

	DECLARE transferCursor CURSOR FOR
    SELECT TH.transferID FROM TransfersHistory TH JOIN TransferDetails TD ON TH.transferID = TD.transferID
    WHERE (accountNr = @accountNr OR payeeAccountNr = @accountNr) ORDER BY transferDate DESC
	FOR READ ONLY;
	
	DECLARE @transferID int, @balance money, @amount money, @duration int, @dateLimit date, @prevDate date;
	SET @avgBalance = 0;
	SELECT @balance = currentBalance FROM Accounts WHERE accountID = @accountID;
	SELECT @dateLimit = DATEADD(month, -1, @currentDate);

	OPEN transferCursor
	FETCH transferCursor INTO @transferID

	SET @prevDate = @currentDate

	WHILE @@FETCH_STATUS = 0 AND @prevDate > @dateLimit
	BEGIN
		SET @currentDate = @prevDate;
		SELECT @prevDate = transferDate FROM TransferDetails WHERE transferID = @transferID;
		SELECT @amount = amount FROM TransfersHistory WHERE transferID = @transferID;

		SET @duration = DATEDIFF(DAY, @prevDate, @currentDate);		-- sprawdzic co się stanie w przypadku dwoch przelewow w tym samym dniu
		SET @avgBalance = @avgBalance + @duration*@balance;

		IF @accountNr = (SELECT accountNr FROM TransfersHistory WHERE transferID = @transferID)
		BEGIN	SET @balance = @balance + @amount;	END
		ELSE
		BEGIN	SET @balance = @balance - @amount;	END

		FETCH transferCursor INTO @transferID
	END
	
	SET @duration = DATEDIFF(DAY, @dateLimit, @prevDate);	
	SET @avgBalance = @avgBalance + @duration*@balance;

	CLOSE transferCursor
	DEALLOCATE transferCursor
END

-- DROP PROCEDURE withdrawalInterest
CREATE PROCEDURE withdrawalInterest
	@currentDate date
AS
BEGIN
	DECLARE accountCursor CURSOR 
		FOR SELECT accountID FROM Accounts
		FOR READ ONLY;

	DECLARE @accountID int;
	OPEN accountCursor
	FETCH accountCursor INTO @accountID

	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @bankRate decimal (4,2), @interest money;
		SELECT @bankRate = bankRate FROM Accounts A JOIN AccountsTypes AT ON A.typeID = AT.typeID WHERE accountID = @accountID;
		IF @bankRate <> 0.0
		BEGIN
			EXEC calculateAvg @accountID, @currentDate, @interest OUTPUT
			SET @interest = @interest / 365 * @bankRate;

			DECLARE @accountNr varchar(26)
			SELECT @accountNr = accountNr FROM Accounts WHERE accountID = @accountID
			BEGIN TRANSACTION
				DECLARE @status int;
				EXEC @status = makeTransfer 'Interest', 'BANK-INTEREST', @accountNr,  @interest, 'BANK-INTEREST', @currentDate, NULL;
				IF @status <> 0
					RETURN -1;
				SET @interest = @interest * 0.19;	-- 19% tax
				EXEC @status = makeTransfer 'Interest-tax', @accountNr, 'BANK-INTEREST', @interest, 'BANK-INTEREST', @currentDate, NULL;
				IF @status <> 0
					RETURN -1;
			COMMIT;
		END
		FETCH accountCursor INTO @accountID
	END
	CLOSE accountCursor
	DEALLOCATE accountCursor
END;


--Tests
EXEC withdrawalInterest '2022-03-01'

DELETE FROM TransferDetails;
DELETE FROM TransfersHistory;
DELETE FROM CustomerAccount;
DELETE FROM Deposits;
DELETE FROM Accounts;
DELETE FROM AccountsTypes;
DELETE FROM Currency;

INSERT INTO Currency VALUES ('PLN', 1, 1);
INSERT INTO Currency VALUES ('EUR', 0.23, 4.35);

INSERT INTO AccountsTypes VALUES (1, 'Normalne', 0.05, 'PLN');
INSERT INTO AccountsTypes VALUES (2, 'Euro', 0.0, 'EUR');

INSERT INTO Accounts VALUES (1, 'numerKonta1', 1, 500);
INSERT INTO Accounts VALUES (2, 'numerKonta2', 2, 100);
INSERT INTO Accounts VALUES (3, 'numerKonta3', 1, 1000);

INSERT INTO CustomerAccount VALUES (1, 1);
INSERT INTO CustomerAccount VALUES (1, 2);
INSERT INTO CustomerAccount VALUES (2, 3);

EXEC openDeposit 1, 300, 0.065, '2024-02-12', 12
SELECT * FROM Deposits

EXEC closeDeposit 12, '2026-02-12'

SELECT * FROM CustomerAccount;
SELECT * FROM Currency;
SELECT * FROM AccountsTypes;
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 'przelew pierwszy', 'numerKonta1', 'numerKonta3', 100, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 'przelew drugi walutowy', 'numerKonta1', 'numerKonta2', 100, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 'przelew trzeci, ma się nie udać, zle waluty', 'numerKonta2', 'numerKonta3', 100, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 'przelew czwarty, z nieznanego konta', 'numerKonta20', 'numerKonta1', 400, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

SELECT * FROM Accounts;
EXEC makeTransfer 'przelew piąty, na nieznane konto', 'numerKonta3', 'numerKonta10', 400, 'blabla', '2022-02-12';
SELECT * FROM Accounts;

EXEC withdrawInterest '2022-03-01'

SELECT * FROM TransfersHistory;
SELECT * FROM TransferDetails;
