--USE BankDatabase

--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--SET XACT_ABORT ON;


/*
Procedura dodająca nową wartość waluty do tabeli z historią wartości walut
*/
CREATE PROC AddRatesHistory
( 
	@currencyID nvarchar(3),
	@buyRate decimal(7,5),
	@sellRate decimal(7,5)
)
AS
    INSERT INTO RatesHistory VALUES(@currencyID, SYSDATETIME(), @buyRate, @sellRate)
GO
 
/*
Procedura dodająca adres do tabeli adresów i zwracająca w argumencie wyjściowym wartość przypisanego mu ID, w przypadku istnienia już danego adresu w tabeli
procedura nie dodaje go na nowo a jedynie zwraca przypisane do niego ID
*/
CREATE PROC AddAddressDetails
(
	@country nvarchar(20),
	@region nvarchar(40),
	@city nvarchar(58),
	@postalCode nvarchar(6),
	@street nvarchar(85),
	@streetNumber nvarchar(10),
	@houseNumber nvarchar(3),
	@addressID int OUTPUT
)
AS
BEGIN
	SET @addressID = NULL
	SET @addressID = (
		SELECT A.addressID FROM AddressDetails A
		WHERE (A.country = @country) AND (A.region = @region OR ((A.region IS NULL) AND (@region IS NULL)))
		AND (A.city = @city) AND (A.postalCode = @postalCode) AND (A.street = @street) AND (A.streetNumber = @streetNumber)
		AND (A.houseNumber = @houseNumber OR ((A.houseNumber IS NULL) AND (@houseNumber IS NULL)))
	)
	IF (@addressID IS NULL)
	BEGIN
		SET @addressID = (
			SELECT MAX(A.addressID) FROM AddressDetails A
		) + 1
		IF (@addressID IS NULL)
		BEGIN
			SET @addressID = 1
		END
		INSERT INTO AddressDetails VALUES(@addressID, @country, @region, @city, @postalCode, @street, @streetNumber, @houseNumber)--uzupelnij
	END
END
GO


/*
Procedura dodająca informacje o kliencie do tabeli z klientami i zwracająca w argumencie wyjściowym przypisane mu ID
*/
CREATE PROC AddCustomerData
(
	@pesel char(11),
	@firstName nvarchar(50),
	@lastName nvarchar(50),
	@addressId int,
	@phoneNr  int,
	@dateOfBirth date,
	@customerID int OUTPUT
)
AS
BEGIN
	SET @customerID = NULL
	SET @customerID = (
		SELECT MAX(C.customerID) FROM CustomerData C
	) + 1
	IF (@customerID IS NULL)
	BEGIN
		SET @customerID = 1
	END
	INSERT INTO CustomerData VALUES(@customerID, @pesel, @firstName, @lastName, @addressId, @phoneNr, @dateOfBirth)
END
GO

/*
Procedura dodająca klienta, w tym dodająca jego dane do tabeli CustomerData, jego adres do tabeli AddressDetails, oraz jego login do tabeli LogInData
oraz wpisująca wykonanie owego działania do CustomerHistory
*/
CREATE PROC AddCustomer
( 
	@employeeID int,
	@pesel char(11),
	@firstName nvarchar(50),
	@lastName nvarchar(50),
	@phoneNr  int,
	@dateOfBirth date,
	@country nvarchar(20),
	@region nvarchar(40),
	@city nvarchar(58),
	@postalCode nvarchar(6),
	@street nvarchar(85),
	@streetNumber nvarchar(10),
	@houseNumber nvarchar(3),
	@customerLogin nvarchar(10),
	@passwordHash BIGINT
)
AS
BEGIN
	DECLARE @addressID int
	EXEC AddAddressDetails @country, @region, @city, @postalCode, @street, @streetNumber, @houseNumber, @addressID = @addressID OUTPUT

	BEGIN TRANSACTION
		DECLARE @customerID int
		EXEC AddCustomerData @pesel, @firstName, @lastName, @addressId, @phoneNr, @dateOfBirth, @customerID = @customerID OUTPUT

		INSERT INTO CustomerHistory VALUES(@customerID, @employeeID, 1, GETDATE())

		INSERT INTO LogInData VALUES(@customerID, @customerLogin, @passwordHash)--uzupelnij hashowaniem hasla klienta
		IF ((@@ERROR = 0) AND (@@ROWCOUNT > 0))
		BEGIN
			COMMIT TRANSACTION
		END
		ELSE 
		BEGIN
			ROLLBACK TRANSACTION
		END
END
GO


/*
Procedura dodająca konto do tabeli Accounts, łącząca konto z odpowiednimi klientami do niego przypisanymi
oraz wpisująca wykonanie owego działania do CustomerHistory
*/
CREATE PROC AddAccount
(
	@employeeID int,
	@accountNr nvarchar(26),
	@typeID int,
	@customerID1 int,
	@customerID2 int = NULL,
	@customerID3 int = NULL,
	@customerID4 int = NULL
)
AS 
BEGIN
	DECLARE @accountID int = NULL
	SET @accountID = (
		SELECT MAX(A.accountID) FROM Accounts A
	) + 1
	IF (@accountID IS NULL)
	BEGIN
		SET @accountID = 1
	END

	INSERT INTO Accounts VALUES(@accountID, @accountNr, @typeID, 0)--uzupelnij


	INSERT INTO CustomerAccount VALUES(@customerID1, @accountID)
	IF (@customerID2 IS NOT NULL)
	BEGIN
		INSERT INTO CustomerAccount VALUES(@customerID2, @accountID)
	END
	IF (@customerID3 IS NOT NULL)
	BEGIN
		INSERT INTO CustomerAccount VALUES(@customerID3, @accountID)
	END
	IF (@customerID4 IS NOT NULL)
	BEGIN
		INSERT INTO CustomerAccount VALUES(@customerID4, @accountID)
	END

	INSERT INTO CustomerHistory VALUES(@customerID1, @employeeID, 2, SYSDATETIME())

END
GO

 /* 
 Pomocnicza procedura dla makeTransfer. sprawdza czy konta, które biorą udział w przelewie, przechowują pieniądze 
 tej samej waluty. Jeśli właścicielem obu kont jest ta sama osoba, to oblicza i zwraca wartość przelewu po wymianie walut. 
 Jeśli przelew jest pomiędzy różnymi klientami, to jest on blokowany.
*/
 CREATE PROCEDURE checkCurrency
 (
	@accountNr nvarchar(26),
	@payeeAccountNr nvarchar(26),
	@amount money OUTPUT
)
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
END
GO

/*
Wykonuje przelew z jednego konta na drugie. Sprawdza czy przynajmniej jedno konto istnieje w naszym banku, 
czy waluty są zgodne, czy na koncie są wystarczające środki do wykonania przelewu.
*/
CREATE PROCEDURE makeTransfer
(
	@title nvarchar(140),
	@accountNr nvarchar(26),
	@payeeAccountNr nvarchar(26),
	@amount money,
	@payeeNameAndAddress nvarchar(140),
	@cardID int = NULL
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @id int, @balance money, @currentDate date;
	SELECT @currentDate = CAST(GETDATE() AS date);

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
			INSERT INTO TransferDetails VALUES (@id, @payeeNameAndAddress, @currentDate, @cardID);
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
			INSERT INTO TransferDetails VALUES (@id, @payeeNameAndAddress, @currentDate, @cardID)
	COMMIT;
END
GO

/*
Tworzy lokatę na konkretny okres.
*/
CREATE PROCEDURE openDeposit
	@accountID int,
	@balance money,
	@bankRate decimal (4,2),
	@duration int
AS
BEGIN
	BEGIN TRANSACTION
		DECLARE @status int, @accountNr nvarchar(26), @currentDate date;
		SELECT @accountNr = accountNr FROM Accounts WHERE accountID = @accountID;
		SELECT @currentDate = CAST(GETDATE() AS date);
		EXEC @status = makeTransfer 'open deposit', @accountNr, 'BANK-DEPOSIT', @balance, 'BANK-DEPOSIT', NULL;
		IF @status <> 0
			RETURN -1;
		INSERT INTO Deposits VALUES (@accountID, @balance, @bankRate, @currentDate, @duration);
	COMMIT;
END
GO

/*
Zamyka lokatę. Jeśli upłynął okres jej trwania, to przelewa środki na konto razem z odsetkami, 
w przeciwnym razie na konto klienta wraca jedynie suma przechowywana na lokacie.
*/
CREATE PROCEDURE closeDeposit
(
	@depositID int
)
AS
BEGIN
	DECLARE @accountID int, @openDate date, @duration int, @amount money, @accountNr nvarchar(26), @currentDate date;
	SELECT @accountID = accountID FROM Deposits WHERE depositID = @depositID;
	SELECT @openDate = openDate FROM Deposits WHERE depositID = @depositID;
	SELECT @duration = duration FROM Deposits WHERE depositID = @depositID;
	SELECT @amount = balance FROM Deposits WHERE depositID = @depositID;
	SELECT @accountNr = accountNr FROM Accounts WHERE accountID = @accountID;
	SELECT @currentDate = CAST(GETDATE() AS date);

	IF @currentDate >= DATEADD(month, @duration, @openDate)
	BEGIN
		DECLARE @rate decimal(4,2);
		SELECT @rate = bankRate FROM Deposits WHERE depositID = @depositID;
		SET @amount = @amount + (@amount * @rate * @duration /12);
	END
	 
	BEGIN TRANSACTION
		DECLARE @status int;
		EXEC @status = makeTransfer 'close deposit', 'BANK-DEPOSIT', @accountNr,  @amount, 'BANK-DEPOSIT', NULL;
		IF @status <> 0
			RETURN;
		DELETE FROM Deposits WHERE depositID = @depositID;
	COMMIT;
END
GO


/*
Pomocnicza procedura dla withdrawalInterest. Dla podanego konta oblicza średnią ilość pieniędzy, 
która była przechowywana na koncie w ciągu ostatniego miesiąca.
*/
CREATE PROCEDURE calculateAvg
(
	@accountID int,
	@currentDate date,
	@avgBalance money OUTPUT
)
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

		SET @duration = DATEDIFF(DAY, @prevDate, @currentDate);
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
GO

/*
Oblicza i przelewa odsetki. które zostały naliczone w ciągu miesiąca. Następnie pobiera podatek z tej sumy.
*/
CREATE PROCEDURE withdrawalInterest
AS
BEGIN
	DECLARE @currentDate date;
	SELECT @currentDate = CAST(GETDATE() AS date);
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
				EXEC @status = makeTransfer 'Interest', 'BANK-INTEREST', @accountNr,  @interest, 'BANK-INTEREST', NULL;
				IF @status <> 0
					RETURN -1;
				SET @interest = @interest * 0.19;	-- 19% tax
				EXEC @status = makeTransfer 'Interest-tax', @accountNr, 'BANK-INTEREST', @interest, 'BANK-INTEREST', NULL;
				IF @status <> 0
					RETURN -1;
			COMMIT;
		END
		FETCH accountCursor INTO @accountID
	END
	CLOSE accountCursor
	DEALLOCATE accountCursor
END
GO
