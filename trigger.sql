USE BankDatabase
/*
Wyzwalacz na operacji na aktualizacji danych w tabeli Currency który nowe zaktualizowane wartości walut dodaje do tabeli z historią wartości walut
*/
CREATE TRIGGER OnCurrencyUpdate ON Currency
AFTER UPDATE
AS
BEGIN
	DECLARE @iter int = 1
	DECLARE @val int = (SELECT COUNT(C.currencyID) FROM Inserted C)
	WHILE (@iter <= @val)
	BEGIN
		DECLARE @currencyID nvarchar(3) = (
			SELECT TOP 1 A.currencyID FROM (
				SELECT TOP(@iter) * FROM Inserted I
				ORDER BY I.currencyID ASC
			) A ORDER BY A.currencyID DESC
		)
		DECLARE @buyRate decimal(7,5) = (
			SELECT TOP 1 A.buyRate FROM (
				SELECT TOP(@iter) * FROM Inserted I
				ORDER BY I.currencyID ASC
			) A ORDER BY A.currencyID DESC
		)
		DECLARE @sellRate decimal(7,5) = (
			SELECT TOP 1 A.sellRate FROM (
				SELECT TOP(@iter) * FROM Inserted I
				ORDER BY I.currencyID ASC
			) A ORDER BY A.currencyID DESC
		)
		EXEC AddRatesHistory @currencyID, @buyRate, @sellRate
		SET @iter = @iter + 1
	END
END
GO


/*
Wyzwalacz na operacji na dodaniu danych do tabeli Currency który nowe dodane wartości nowej walut dodaje do tabeli z historią wartości walut
*/
CREATE TRIGGER OnCurrencyInsert ON Currency
AFTER INSERT
AS 
BEGIN
	DECLARE @iter int = 1
	DECLARE @val int = (SELECT COUNT(C.currencyID) FROM Inserted C)
	WHILE (@iter <= @val)
	BEGIN
		DECLARE @currencyID nvarchar(3) = (
			SELECT TOP 1 A.currencyID FROM (
				SELECT TOP(@iter) * FROM Inserted I
				ORDER BY I.currencyID ASC
			) A ORDER BY A.currencyID DESC
		)
		DECLARE @buyRate decimal(7,5) = (
			SELECT TOP 1 A.buyRate FROM (
				SELECT TOP(@iter) * FROM Inserted I
				ORDER BY I.currencyID ASC
			) A ORDER BY A.currencyID DESC
		)
		DECLARE @sellRate decimal(7,5) = (
			SELECT TOP 1 A.sellRate FROM (
				SELECT TOP(@iter) * FROM Inserted I
				ORDER BY I.currencyID ASC
			) A ORDER BY A.currencyID DESC
		)
		EXEC AddRatesHistory @currencyID, @buyRate, @sellRate
		SET @iter = @iter + 1
	END
END 
GO


/*
Wyzwalacz na operacji dodania danych do tabeli z loginami klientów, który sprawdza czy nowy login nie istnieje juz w tabeli i zwraca ewentualną informację o niedostępności loginu
*/
CREATE TRIGGER LoginCheck ON LogInData
INSTEAD OF INSERT
AS 
    SELECT L.customerLogin FROM LogInData L WHERE L.customerLogin = (SELECT TOP 1 A.customerLogin FROM Inserted A)
    IF (@@ROWCOUNT > 0)
    BEGIN
        RAISERROR('Login niedostepny', 16, 1)
        ROLLBACK TRANSACTION
    END
	ELSE 
	BEGIN
		INSERT INTO LogInData SELECT * FROM Inserted
	END 
GO

/*
Sprawdza czy wprowadzona do danych klienta (CustomerData) data urodzenia jest zgodna z numerem PESEL. 
W przypadku błędnych danych operacja wstawiania nowego klienta jest wycofywana.
*/
CREATE TRIGGER peselCheck ON CustomerData
INSTEAD OF INSERT
AS
BEGIN
	DECLARE @pesel char(11), @dateOfBirth date, @year int, @month int, @day int;
	SELECT @pesel = pesel FROM INSERTED;
	SET @year = CAST(SUBSTRING(@pesel, 1, 2) AS INT);
	SET @month = CAST(SUBSTRING(@pesel, 3, 2) AS INT);
	SET @day = CAST(SUBSTRING(@pesel, 5, 2) AS INT);

    IF @month > 20
	BEGIN
        SET @year = @year + 2000;
		SET @month = @month - 20;
	END
    ELSE
	BEGIN
        SET @year = @year + 1900;
	END

    SET @dateOfBirth = DATEFROMPARTS(@year, @month, @day);

	IF @dateOfBirth <> (SELECT dateOfBirth FROM Inserted)
	BEGIN
        RAISERROR('Niepoprawny PESEL lub data urodzenia', 16, 1)
        ROLLBACK TRANSACTION
    END
	ELSE 
	BEGIN
		INSERT INTO CustomerData SELECT * FROM Inserted;
	END 
END
GO

/*
Fakt otworzenia lokaty (dodanie wiersza do Deposits) jest zapisywany w historii klienta (CustomerHistory).
*/
CREATE TRIGGER insertDeposit ON Deposits 
AFTER INSERT
AS
BEGIN
	DECLARE @accountID int, @customerID int;
	SELECT @accountID = accountID FROM Inserted;
	SET @customerID = (SELECT TOP 1 customerID FROM CustomerAccount WHERE accountID = @accountID); -- jesli wiecej wlascicieli, wez pierwszego

	INSERT INTO CustomerHistory VALUES (@customerID, 3, 2, GETDATE());	-- 2-'OPEN DEPOSIT'
END
GO

/*
Zamknięcie lokaty, analogicznie jak insertDeposit.
*/
CREATE TRIGGER deleteDeposit ON Deposits 
AFTER DELETE
AS
BEGIN
	DECLARE @accountID int, @customerID int;
	SELECT @accountID = accountID FROM Deleted;
	IF @accountID IS NOT NULL
	BEGIN
		SET @customerID = (SELECT TOP 1 customerID FROM CustomerAccount WHERE accountID = @accountID);	-- jesli wiecej wlascicieli, wez pierwszego
		INSERT INTO CustomerHistory VALUES (@customerID, 4, 2, GETDATE());	-- 2-'CLOSE DEPOSIT'
	END
END
GO
