USE BankDatabase

INSERT INTO Departments VALUES	(1, 'Dział Obsługi Klienta - otwieranie i zamykanie kont'),
								(2, 'Dział Obsługi Klienta - lokaty'),
								(3, 'Dział IT'),
								(4, 'Dział Kredytowy'),
								(5, 'Dział Obsługi Klienta - nowi klienci');
INSERT INTO Employees VALUES	(1, 'Jan', 'Kowalski', '2020-01-15', 1),
								(2, 'Anna', 'Nowak', '2019-05-20', 5),
								(3, 'Piotr', 'Wiśniewski', '2021-02-10', 2),
								(4, 'Maria', 'Dąbrowska', '2018-11-30', 2),
								(5, 'Andrzej', 'Lewandowski', '2022-03-05', 3),
								(6, 'Magdalena', 'Wójcik', '2017-09-18', 4);
EXEC AddCustomer   
   @employeeID = 1,
   @pesel = '80010112375',
   @firstName = 'Jan',
   @lastName = 'Kowalski',
   @phoneNr = 123456789,
   @dateOfBirth = '1980-01-01',
   @country = 'Polska',
   @region = 'Mazowieckie',
   @city = 'Warszawa',
   @postalCode = '00-001',
   @street = 'Aleje Jerozolimskie',
   @streetNumber = '1',
   @houseNumber = 'A',
   @customerLogin = 'jkowalski',
   @passwordHash = 12345678901;

 EXEC AddCustomer
   @employeeID = 2,
   @pesel = '90020223456',
   @firstName = 'Adam',
   @lastName = 'Nowak',
   @phoneNr = 987654321,
   @dateOfBirth = '1990-02-02',
   @country = 'Polska',
   @region = 'Małopolskie',
   @city = 'Kraków',
   @postalCode = '30-001',
   @street = 'Rynek Główny',
   @streetNumber = '10',
   @houseNumber = 'B',
   @customerLogin = 'anowak',
   @passwordHash = 98765432;

-- Zły pesel
EXEC AddCustomer
   @employeeID = 3,
   @pesel = '12345678912',
   @firstName = 'Michał',
   @lastName = 'Adamczewski',
   @phoneNr = 555123456,
   @dateOfBirth = '1975-03-03',
   @country = 'Polska',
   @region = 'Śląskie',
   @city = 'Katowice',
   @postalCode = '40-001',
   @street = 'ul. Armii Krajowej',
   @streetNumber = '5',
   @houseNumber = 'C',
   @customerLogin = 'madamczewski',
   @passwordHash = 55512345;

EXEC AddCustomer
   @employeeID = 3,
   @pesel = '75030334567',
   @firstName = 'Michał',
   @lastName = 'Adamczewski',
   @phoneNr = 555123456,
   @dateOfBirth = '1975-03-03',
   @country = 'Polska',
   @region = 'Śląskie',
   @city = 'Katowice',
   @postalCode = '40-001',
   @street = 'ul. Armii Krajowej',
   @streetNumber = '5',
   @houseNumber = 'C',
   @customerLogin = 'madamczewski',
   @passwordHash = 5551234;


INSERT INTO Currency VALUES ('PLN', 1, 1);
INSERT INTO Currency VALUES ('EUR', 0.23, 4.35);
UPDATE Currency SET buyRate = 0.19, sellRate = 4.41 WHERE currencyID = 'EUR';

INSERT INTO AccountsTypes VALUES (1, 'Normalne', 0.05, 'PLN');
INSERT INTO AccountsTypes VALUES (2, 'Euro', 0.0, 'EUR');

INSERT INTO RequestsTypes VALUES (1, 'Accounts', 'Open or close');
INSERT INTO RequestsTypes VALUES (2, 'Deposits', 'Open or close');

EXEC AddAccount @employeeID = 1, @accountNr = 'numerKonta1', @typeID = 1, @customerID1 = 1;
EXEC AddAccount @employeeID = 1, @accountNr = 'numerKonta2', @typeID = 2, @customerID1 = 1;
EXEC AddAccount @employeeID = 1, @accountNr = 'numerKonta3', @typeID = 1, @customerID1 = 2;

EXEC makeTransfer @title = 'przelew środków', @accountNr = 'InnyBank', @payeeAccountNr = 'numerKonta1', @amount = 500, @payeeNameAndAddress = 'Jan Kowalski';
EXEC makeTransfer @title = 'przelew środków na konto walutowe', @accountNr = 'InnyBank', @payeeAccountNr = 'numerKonta2', @amount = 100, @payeeNameAndAddress = 'Jan Kowalski';
EXEC makeTransfer @title = 'przelew środków', @accountNr = 'InnyBank', @payeeAccountNr = 'numerKonta3', @amount = 1000, @payeeNameAndAddress = 'Adam Nowak';

EXEC openDeposit 1, 300, 0.065, 12;
EXEC closeDeposit 1;

EXEC withdrawalInterest;

EXEC makeTransfer 'przelew pierwszy', 'numerKonta1', 'numerKonta3', 100, 'Adam Nowak';
EXEC makeTransfer 'przelew drugi walutowy', 'numerKonta1', 'numerKonta2', 100, 'Jan Kowalski';
EXEC makeTransfer 'przelew trzeci, nie uda się, zle waluty', 'numerKonta2', 'numerKonta3', 100, 'Adam Nowak';
EXEC makeTransfer 'przelew czwarty, na nieznane konto', 'numerKonta3', 'numerKonta10', 400, 'Ada Mrzilek';

EXEC withdrawInterest;

SELECT * FROM Employees;
SELECT * FROM CustomerData;
SELECT * FROM CustomerAccount;
SELECT * FROM Currency;
SELECT * FROM AccountsTypes;
SELECT * FROM RequestsTypes;
SELECT * FROM Accounts;
SELECT * FROM CustomerHistory;
SELECT * FROM CustomerData;