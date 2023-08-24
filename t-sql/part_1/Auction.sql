Use AdventureWorks
GO


----------------------------------------------Stock Clearance-----------------------------------------------
-- 1. Setup
-- 1.1 Schema Creation
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Auction')
BEGIN
    EXEC('CREATE SCHEMA Auction')
END
GO

-- 1.2 Tables Creation

-- Auction.Thresholds table 

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BidThresholds' AND schema_id = SCHEMA_ID('Auction'))
BEGIN 
    CREATE TABLE Auction.BidThresholds(
        BidThresholdID INT IDENTITY(1,1) PRIMARY KEY,
        MinimumBidIncrease MONEY, 
        InitialBidPrice_p DECIMAL (4,2),
        MaximumBidPrice_p DECIMAL (4,2)
    )
END 
GO 

-- Auction.Thresholds table 

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DateThresholds' AND schema_id = SCHEMA_ID('Auction'))
BEGIN 
    CREATE TABLE Auction.DateThresholds(
        DateThresholdID INT IDENTITY(1,1) PRIMARY KEY, 
        StartBidDate DATE,
        StopBidDate DATE,
    )
END 
GO 

-- Auction.AuctionInfo table 

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuctionInfo' AND schema_id = SCHEMA_ID('Auction'))
BEGIN 
    CREATE TABLE Auction.AuctionInfo (
        AuctionID INT PRIMARY KEY IDENTITY(1,1),
        BidThresholdID INT FOREIGN KEY REFERENCES Auction.BidThresholds(BidThresholdID),
        --DateThresholdID INT FOREIGN KEY REFERENCES Auction.DateThresholds(DateThresholdID), 
        ProductID INT FOREIGN KEY REFERENCES Production.Product(ProductID), 
        InitialBidPrice MONEY,
        MaximumBidPrice MONEY,
        ExpireDate DATE,
        Status VARCHAR(10),
        CurrentPrice MONEY,
        Winner INT
    )
END 
GO 

-- Auction.Bids table

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Bids' AND schema_id = SCHEMA_ID('Auction'))
BEGIN
    CREATE TABLE Auction.Bids(
        BidID INT IDENTITY(1,1) PRIMARY KEY,
        AuctionID INT FOREIGN KEY REFERENCES Auction.AuctionInfo(AuctionID),
        CustomerID INT FOREIGN KEY REFERENCES Person.Person(BusinessEntityID),
        BidAmount MONEY,
        Date DATETIME,
    )
END 
GO

-- 1.3 Tables Default Values Insertion

-- BidThresholds Insertion
IF NOT EXISTS (SELECT * FROM Auction.BidThresholds) 
BEGIN
    INSERT INTO Auction.BidThresholds(MinimumBidIncrease, InitialBidPrice_p, MaximumBidPrice_p ) VALUES(0.05, 0.5,1), (0.05, 0.75,1);
END

-- DateThresholds Insertion
IF NOT EXISTS (SELECT * FROM Auction.DateThresholds) 
BEGIN
    INSERT INTO Auction.DateThresholds(StartBidDate, StopBidDate) VALUES('2023-11-13', '2023-11-26')
END

GO

-- 2 Store Procedures

-- 2.1 uspAddProductToAuction Procedure 

CREATE OR ALTER PROCEDURE uspAddProcuctToAuction
    @ProductID INT, 
    @ExpireDate DATE = NULL, 
    @InitialBidPrice MONEY  = NULL
 
AS
BEGIN 
SET NOCOUNT ON;


-- Declare Variables 
        DECLARE @BidThresholdID INT = CASE WHEN (SELECT p.MakeFlag FROM Production.Product as p WHERE p.ProductID = @ProductID) = 0 THEN 2 ELSE 1 END;
        --DECLARE @DateThresholdID INT = 1;
        DECLARE @MaximumBidPrice MONEY = (SELECT p.ListPrice * bt.MaximumBidPrice_p
                                            FROM Production.Product AS p
                                            JOIN Auction.BidThresholds AS bt ON bt.BidThresholdID = @BidThresholdID
                                            WHERE p.ProductID = @ProductID);
        DECLARE @MinimumBidPrice MONEY = (SELECT p.ListPrice * bt.InitialBidPrice_p
                                          FROM Production.Product AS p
                                          JOIN Auction.BidThresholds AS bt ON bt.BidThresholdID = @BidThresholdID
                                          WHERE p.ProductID = @ProductID);
        DECLARE @StartBidDate DATE = (SELECT StartBidDate FROM Auction.DateThresholds);
        DECLARE @StopBidDate DATE = (SELECT StopBidDate FROM Auction.DateThresholds);
        DECLARE @Status VARCHAR(10) = 'Active';
        
        
-- Input Parameters Checks
    
-- ProductID Checks
    -- NULL
    IF @ProductID IS NULL
    BEGIN
        RAISERROR('ProductID cannot be null', 16, 1);
    END

    -- Check if the product exists in the Product.ProductID in the Production Schema 
   IF Not EXISTS (SELECT * FROM Production.Product WHERE ProductID = @ProductID AND ListPrice > 0 )
	   BEGIN
		    RAISERROR('Invalid ProductID', 16, 1, @ProductID);
		    RETURN;
	    END
    -- Check if the product is being currently being commercialized
   IF EXISTS (SELECT * FROM Production.Product WHERE ProductID = @ProductID and SellEndDate is not NULL and DiscontinuedDate is not null AND ListPrice > 0)
	   BEGIN
		    RAISERROR('PRODUCT ID %d is not currently being commercialized', 16, 1, @ProductID);
		    RETURN;
	    END 
    -- Check if the product ID already exists on AuctionInfo table 
	IF EXISTS (SELECT * FROM Auction.AuctionInfo WHERE ProductID = @ProductID  AND Status = 'Active')
	BEGIN
		    RAISERROR('That product is already being auctioned', 16, 1, @ProductID);
		    RETURN;
	    END

-- ExpireDate Checks

    -- Check if ExpireDate is not in the past
    IF @ExpireDate IS NOT NULL AND @ExpireDate < GETDATE()
    BEGIN
    RAISERROR('Expire date cannot be in the past', 16, 1);
    RETURN;
    END

       -- Check if ExpireDate is before StartBidDate
    IF @ExpireDate IS NOT NULL AND @ExpireDate < @StartBidDate
    BEGIN
    RAISERROR('Expire date cannot be before the beginning date of the auction', 16, 1);
    RETURN;
    END

    -- Products can be added to auction at any time that is earlier than StopBidDate value
    IF GETDATE() > @StopBidDate
    BEGIN
    RAISERROR('Auction must had been created before the end of auction period', 16, 1);
    RETURN;
    END

-- InitialBidPrice Checks
    IF @InitialBidPrice < @MinimumBidPrice OR  @InitialBidPrice > @MaximumBidPrice 
    BEGIN
    RAISERROR('Initial bid price should be below or equal to the listed price', 16, 1);
    RETURN;
    END

-- Setting Default Parameters

    -- ExpireDate
    IF @ExpireDate IS NULL
    BEGIN   
    SET @ExpireDate = DATEADD(DAY, 7, @StartBidDate);
    END
   
    -- InitialBidPrice
    IF @InitialBidPrice IS NULL
    BEGIN
    SET @InitialBidPrice = @MinimumBidPrice;
    END
    
BEGIN TRY
BEGIN TRANSACTION
-- Insert Values into table
    INSERT INTO Auction.AuctionInfo (BidThresholdID, ProductID, InitialBidPrice, MaximumBidPrice,  ExpireDate, Status, CurrentPrice)
    VALUES(@BidThresholdID, @ProductID, @InitialBidPrice, @MaximumBidPrice, @ExpireDate, @Status, @InitialBidPrice ) 

-- Success message
SELECT CONCAT('Product ', @PRoductID, ' added to auction successfully') AS Message;
COMMIT TRANSACTION
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0
BEGIN
ROLLBACK TRANSACTION
END
    RAISERROR('It was''t possible to add the product to auction', 16, 1);
END CATCH;
END
GO


-- 2.2 uspTryBidProduct Procedure 

CREATE OR ALTER PROCEDURE uspTryBidProduct
    @ProductID INT, 
    @CustomerID INT, 
    @BidAmount MONEY = NULL
AS
BEGIN 
SET NOCOUNT ON;

-- Variables Declaration
    DECLARE @AuctionID INT = (SELECT AuctionID FROM Auction.AuctionInfo WHERE ProductID = @ProductID AND Status = 'Active');
    DECLARE @Date DATETIME = GETDATE();
    DECLARE @CurrentPrice MONEY = (SELECT CurrentPrice FROM Auction.AuctionInfo WHERE ProductID = @ProductID  AND Status = 'Active' );
    DECLARE @MaximumBidPrice MONEY = (SELECT MaximumBidPrice FROM Auction.AuctionInfo WHERE ProductID = @ProductID  AND Status = 'Active' );
    DECLARE @StartBidDate DATE = (SELECT StartBidDate FROM Auction.DateThresholds);
    DECLARE @StopBidDate DATE = (SELECT StopBidDate FROM Auction.DateThresholds);
    

-- Input Parameters Checks

    --NULLS
   IF @ProductID IS NULL
    BEGIN
        RAISERROR('ProductID cannot be null', 16, 1);
    END

   IF @CustomerID IS NULL
    BEGIN
        RAISERROR('CustomerID cannot be null', 16, 1);
    END

    -- CustomerID
    IF NOT EXISTS (SELECT * FROM Person.Person WHERE BusinessEntityID = @CustomerID AND PersonType IN ('SC', 'IN'))
    BEGIN
        RAISERROR('Invalid CustomerID', 16, 1);
    END
    -- ProductID
	IF NOT EXISTS (SELECT * FROM Auction.AuctionInfo WHERE ProductID = @ProductID  AND Status = 'Active')
	    BEGIN
		RAISERROR('That product isn''t currently being auctioned', 16, 1);
		RETURN;
	    END


    -- BidAmount
    IF @BidAmount <= @CurrentPrice OR @BidAmount > @MaximumBidPrice
    BEGIN
    RAISERROR('Bid amount should be greater than the current price and less than the maximum bid price', 16, 1);
	END

-- Other Bidding Conditions

    -- Check Bid Date
    IF @Date NOT BETWEEN @StartBidDate AND @StopBidDate
    BEGIN
    RAISERROR('Bids are''nt currently being accepted', 16, 1);
    RETURN;
    END

-- Setting Default Parameter

    -- BidAmount 
    IF @BidAmount IS NULL
    BEGIN
    IF @CurrentPrice = @MaximumBidPrice -- If an auction is created with minprice = max price 
    BEGIN
    SET @BidAmount =  @CurrentPrice -- don't add bid increase
    END
    ELSE
    SET @BidAmount = (SELECT t.MinimumBidIncrease + @CurrentPrice
                     FROM Auction.BidThresholds as t
                     JOIN Auction.AuctionInfo as i ON t.BidThresholdID = i.BidThresholdID
                     WHERE i.AuctionID = @AuctionID)
    END

BEGIN TRY
BEGIN TRANSACTION

-- Insert Values into tables
    -- Bids
    INSERT INTO Auction.Bids (AuctionID, CustomerID,  BidAmount, Date)
    VALUES(@AuctionID, @CustomerID , @BidAmount, @Date) 

    -- AuctionInfo
    UPDATE Auction.AuctionInfo
    SET CurrentPrice = @BidAmount
    WHERE AuctionID = @AuctionID

    -- Close Auction if it reaches the max price
    IF @BidAmount = @MaximumBidPrice
BEGIN
  UPDATE Auction.AuctionInfo
  SET Status = 'Ended', Winner = @CustomerID
  WHERE AuctionID = @AuctionID
END

COMMIT TRANSACTION
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0
BEGIN
ROLLBACK TRANSACTION
END
RAISERROR('It''s wasn''t possible to place your bid', 16, 1);
END CATCH;
END
GO 


-- 2.3 uspRemoveProductFromAuction Procedure 

CREATE OR ALTER PROCEDURE uspRemoveProductFromAuction
    @ProductID INT
AS
BEGIN 
SET NOCOUNT ON;

-- Input Parameters Checks
    --NULLS
   IF @ProductID IS NULL
    BEGIN
        RAISERROR('ProductID cannot be null', 16, 1);
    END

    -- ProductID
    IF NOT EXISTS (SELECT ProductID FROM Auction.AuctionInfo WHERE ProductID = @ProductID AND Status = 'Active')
    BEGIN
        RAISERROR('There isn''t any current active auction for product %d', 16, 1,@ProductID);
    END

-- Variables Declaration
    DECLARE @AuctionID INT = (SELECT AuctionID FROM Auction.AuctionInfo WHERE ProductID = @ProductID AND Status = 'Active');
    
-- Set status to cancelled
BEGIN TRY
BEGIN TRANSACTION
    UPDATE Auction.AuctionInfo
    SET Status = 'Cancelled'
    WHERE AuctionID = @AuctionID
COMMIT TRANSACTION
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0
BEGIN
ROLLBACK TRANSACTION
END
    RAISERROR('It wasn''t possible to remove product %d from auction', 16, 1,@ProductID);
END CATCH
END
GO


-- 2.4 uspListBidsOffersHistory Procedure 

CREATE OR ALTER PROCEDURE uspListBidsOffersHistory
    @CustomerID INT, 
    @StartTime DATETIME,
    @EndTime DATETIME, 
    @Active BIT = 1
AS
BEGIN 
SET NOCOUNT ON;

-- Input Parameters Checks

    --NULLS
   IF @CustomerID IS NULL
    BEGIN
        RAISERROR('CustomerID cannot be null', 16, 1);
    END

    IF @StartTime IS NULL
    BEGIN
        RAISERROR('StartTime cannot be null', 16, 1);
    END

    IF @EndTime IS NULL
    BEGIN
        RAISERROR('EndTime cannot be null', 16, 1);
    END

-- CustomerID
    IF NOT EXISTS (SELECT * FROM Person.Person WHERE BusinessEntityID = @CustomerID AND PersonType IN ('SC', 'IN'))
    BEGIN
        RAISERROR('Invalid CustomerID', 16, 1);
    END
-- Dates
    IF @EndTime < @StartTime
    BEGIN
        RAISERROR('Invalid time interval: EndTime must be greater than or equal to StartTime', 16, 1);
    END

BEGIN TRY
    IF @Active = 1
    BEGIN
    SELECT b.BidID, b.AuctionID, b.BidAmount, b.Date
    FROM Auction.Bids as b
    JOIN Auction.AuctionInfo as i on b.AuctionID = i.AuctionID
    WHERE b.Date >= @StartTime AND b.Date < DATEADD(day, 1, @EndTime) AND b.CustomerID = @CustomerID AND i.Status = 'Active' 
    END

    ELSE
    BEGIN
    SELECT BidID, AuctionID, BidAmount, Date
    FROM Auction.Bids
    WHERE Date >= @StartTime AND Date < DATEADD(day, 1, @EndTime) AND CustomerID = @CustomerID 
    END
END TRY
BEGIN CATCH
    RAISERROR('An error occurred while retriving you bid history.', 16, 1);
END CATCH 
END
GO


-- 2.5 uspUpdateProductAuctionStatus Procedure 

CREATE OR ALTER PROCEDURE uspUpdateProductAuctionStatus
AS
BEGIN 
    SET NOCOUNT ON;

BEGIN TRY
BEGIN TRANSACTION
-- Update the status of auctions that have ended
        UPDATE Auction.AuctionInfo
        SET Status = 'Ended'
        WHERE ExpireDate < GETDATE() AND Winner IS NULL; 

-- Update the winners of auctions that have ended and haven't been updated yet
        IF @@ROWCOUNT> 0
        BEGIN
            UPDATE Auction.AuctionInfo
            SET Winner = ab.CustomerID
            FROM Auction.AuctionInfo AS ai
            JOIN (
                SELECT AuctionID, CustomerID 
                FROM Auction.Bids AS b
                WHERE BidAmount = (
                    SELECT MAX(BidAmount) 
                    FROM Auction.Bids 
                    WHERE AuctionID = b.AuctionID)) 
            AS ab ON ai.AuctionID = ab.AuctionID
            WHERE ai.Status = 'Ended'
            AND ai.Winner IS NULL;
        END
COMMIT TRANSACTION
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0
BEGIN
ROLLBACK TRANSACTION
END
    RAISERROR('An error occurred while updating auction status.', 16, 1);
END CATCH;
END
GO

----------------------------------------------Brick and Mortar Stores-----------------------------------------------

-- How many customers of AW are stores? 
-- A: 753

SELECT 
  COUNT(*) AS Resellers
FROM 
  Person.Person
WHERE 
  PersonType = 'SC';

-- How many customers of AW are individuals? 
-- A: 18484

SELECT 
  COUNT(*) AS Individuals
FROM 
  Person.Person
WHERE 
  PersonType = 'IN';

-- How many individual customers are the US? 
-- A: 7843 

SELECT COUNT(Person.PersonType) AS Individuals, sp.CountryRegionCode
FROM Person.Person 
JOIN Person.BusinessEntity AS be 
ON Person.BusinessEntityID = be.BusinessEntityID
JOIN Person.BusinessEntityAddress as bea
ON be.BusinessEntityID = bea.BusinessEntityID
JOIN Person.Address as pa 
ON pa.AddressID = bea.AddressID
JOIN Person.StateProvince as sp 
ON sp.StateProvinceID = pa.StateProvinceID
WHERE Person.PersonType = 'IN' AND sp.CountryRegionCode = 'US'
GROUP BY sp.CountryRegionCode;


-- How many individual clients per city in the US?

SELECT COUNT(Person.PersonType) AS Individuals, pa.City
FROM Person.Person 
JOIN Person.BusinessEntity AS be 
ON Person.BusinessEntityID = be.BusinessEntityID
JOIN Person.BusinessEntityAddress as bea
ON be.BusinessEntityID = bea.BusinessEntityID
JOIN Person.Address as pa 
ON pa.AddressID = bea.AddressID
JOIN Person.StateProvince as sp 
ON sp.StateProvinceID = pa.StateProvinceID
WHERE Person.PersonType = 'IN' AND sp.CountryRegionCode = 'US'
GROUP BY pa.City;

-- What are the 2 cities in the US with the most individual clients? 
-- A: Beaverton and Burien (Bellingham also have 210 but is included in the top 30 cities) 



-- Merge between individual clients and total revenue of customers grouped by city

SELECT 
  a.City, a.PostalCode, 
  COUNT(pe.BusinessEntityID) AS IndividualClients,  
  sum(Sales.SalesOrderHeader.TotalDue) as Money_
FROM 
  Person.Person AS pe
JOIN Person.BusinessEntity AS be ON pe.BusinessEntityID = be.BusinessEntityID
JOIN Person.BusinessEntityAddress AS bea ON be.BusinessEntityID = bea.BusinessEntityID
JOIN Person.Address AS a ON bea.AddressID = a.AddressID
Join Sales.SalesOrderHeader
ON Sales.SalesOrderHeader.BillToAddressID = a.AddressID
JOIN Sales.SalesTerritory 
ON Sales.SalesTerritory.TerritoryID = Sales.SalesOrderHeader.TerritoryID
JOIN Person.StateProvince AS sp ON a.StateProvinceID = sp.StateProvinceID
WHERE 
  pe.PersonType = 'IN' AND sp.CountryRegionCode = 'US'  
  AND a.City NOT IN(
  SELECT TOP 30 City 
  FROM Sales.SalesOrderHeader
  JOIN Person.Address
  ON Address.AddressID = SalesOrderHeader.BillToAddressID
  GROUP BY City
  ORDER BY SUM(SubTotal) DESC
)
GROUP BY 
  a.City, sp.StateProvinceCode, a.PostalCode
ORDER BY 
IndividualClients desc,
  Money_ DESC;


-- Of 753 stores clients how many are in the US?
-- A: 391

SELECT COUNT(*) AS StoreCustomersInUS
FROM Person.Person AS p
JOIN Sales.Customer AS c 
ON p.BusinessEntityID = c.PersonID
JOIN Sales.SalesTerritory AS t 
ON c.TerritoryID = t.TerritoryID
WHERE p.PersonType = 'SC' AND t.CountryRegionCode = 'US'; 

-- How many reselers per city in the US (including the best 30)? 

SELECT count(Person.PersonType) AS Resellers,  Address.City  
FROM Person.Person
JOIN Sales.Customer 
ON Customer.PersonID = Person.BusinessEntityID
JOIN Sales.SalesTerritory
ON Customer.TerritoryID = SalesTerritory.TerritoryID
JOIN Sales.SalesOrderHeader 
ON SalesOrderHeader.TerritoryID = SalesTerritory.TerritoryID
JOIN Person.Address
ON Address.AddressID = SalesOrderHeader.ShipToAddressID
WHERE Person.PersonType = 'SC' AND SalesTerritory.CountryRegionCode = 'US' 
GROUP BY Address.City
order by resellers desc;

-- How many reselers per city in the US (excluding the best 30)? 
/*
Acho estranho por exemplo em Daly City existirem 13225 Reselers.... mas acho que o c�digo est� bem... HELP pls
*/
SELECT COUNT(Person.PersonType) AS Resellers, Address.City  
FROM Person.Person
/*join Sales.Store
on Person.BusinessEntityID = Store.BusinessEntityID*/
JOIN Sales.Customer 
ON Customer.PersonID = Person.BusinessEntityID
JOIN Sales.SalesTerritory
ON Customer.TerritoryID = SalesTerritory.TerritoryID
JOIN Sales.SalesOrderHeader 
ON SalesOrderHeader.TerritoryID = SalesTerritory.TerritoryID
JOIN Person.Address
ON Address.AddressID = SalesOrderHeader.BillToAddressID
WHERE Person.PersonType = 'SC' AND SalesTerritory.CountryRegionCode = 'US'
AND Address.City NOT IN(
  SELECT TOP 30 City 
  FROM Sales.SalesOrderHeader
  JOIN Person.Address
  ON Address.AddressID = SalesOrderHeader.BillToAddressID
  GROUP BY City
  ORDER BY SUM(SubTotal) DESC
)
GROUP BY Address.City
order by Resellers desc;

-- Vis�o por Store

SELECT COUNT(a.BusinessEntityID) AS Resellers, Address.City  
from Sales.Store as a
join Sales.SalesOrderHeader as b	
ON a.SalesPersonID = b.SalesPersonID
join Sales.SalesTerritory as c
on b.TerritoryID = c.TerritoryID
JOIN Person.Address
ON Address.AddressID = b.BillToAddressID
where c.CountryRegionCode = 'US' AND Address.City NOT IN(
  SELECT TOP 30 City 
  FROM Sales.SalesOrderHeader
  JOIN Person.Address
  ON Address.AddressID = SalesOrderHeader.BillToAddressID
  GROUP BY City
  ORDER BY SUM(SubTotal) DESC
)
group by Address.City
order by Resellers desc


-- best 30 stores customers according with the SubTotal col (Sales.SalesOrderHeader table)

SELECT TOP 30 
  c.CustomerID,
  p.FirstName + ' ' + p.LastName AS Name,
  a.City,
  SUM(s.SubTotal) AS TotalRevenue
FROM 
  Person.Person AS p
JOIN Sales.Customer AS c 
  ON p.BusinessEntityID = c.PersonID
JOIN Sales.SalesOrderHeader AS s 
  ON c.CustomerID = s.CustomerID
JOIN Sales.SalesTerritory AS t 
  ON c.TerritoryID = t.TerritoryID
JOIN Person.Address AS a 
  ON s.ShipToAddressID = a.AddressID
WHERE 
  p.PersonType = 'SC' AND t.CountryRegionCode = 'US'
GROUP BY 
  c.CustomerID, p.FirstName, p.LastName, a.City
ORDER BY 
  TotalRevenue DESC;

-- How many stores customers without the best 30 stores customers?
-- A: 369 and not 361 because some best stores are located in the same city 

SELECT COUNT(*) AS StoreCustomersWithoutTop30
FROM Person.Person AS p
JOIN Sales.Customer AS c 
  ON p.BusinessEntityID = c.PersonID
JOIN Sales.SalesTerritory AS t 
  ON c.TerritoryID = t.TerritoryID
WHERE p.PersonType = 'SC' 
  AND t.CountryRegionCode = 'US'
  AND c.CustomerID NOT IN (
    SELECT TOP 30 CustomerID
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
    ORDER BY SUM(SubTotal) DESC
  );

-- Which cities are we working with? (Based on that it has been decided that cities where the best 30 customers are located are excluded)
-- 336 (no duplicated rows)

WITH TopCities AS (
  SELECT TOP 30 
    a.City, 
    SUM(o.SubTotal) AS TotalRevenue
  FROM 
    Person.Address AS a
  JOIN Sales.SalesOrderHeader AS o ON a.AddressID = o.ShipToAddressID
  GROUP BY a.City
  ORDER BY TotalRevenue DESC
)
SELECT 
  c.CustomerID,
  p.FirstName + ' ' + p.LastName AS Name,
  a.City,
  SUM(s.SubTotal) AS TotalRevenue
FROM 
  Person.Person AS p
JOIN Sales.Customer AS c ON p.BusinessEntityID = c.PersonID
JOIN Sales.SalesOrderHeader AS s ON c.CustomerID = s.CustomerID
JOIN Sales.SalesTerritory AS t ON c.TerritoryID = t.TerritoryID
JOIN Person.Address AS a ON s.ShipToAddressID = a.AddressID
WHERE 
  p.PersonType = 'SC' AND t.CountryRegionCode = 'US' and a.City NOT IN (
    SELECT City FROM TopCities
  )
GROUP BY 
  c.CustomerID, p.FirstName, p.LastName, a.City
ORDER BY 
  TotalRevenue DESC;

-- How many individuals are in each one of the 336 cities and what is the revenue of the city for Adventure Works? 

WITH TopCities AS (
  SELECT TOP 30 
    a.City, 
    SUM(o.SubTotal) AS TotalRevenue
  FROM 
    Person.Address AS a
  JOIN Sales.SalesOrderHeader AS o ON a.AddressID = o.ShipToAddressID
  GROUP BY a.City
  ORDER BY TotalRevenue DESC
),
IndividualsByCity AS (
  SELECT 
    a.City, 
    COUNT(DISTINCT p.BusinessEntityID) AS IndividualsInCity
  FROM 
    Person.Person AS p
  JOIN Person.BusinessEntity AS be ON p.BusinessEntityID = be.BusinessEntityID
  JOIN Person.BusinessEntityAddress AS bea ON be.BusinessEntityID = bea.BusinessEntityID
  JOIN Person.Address AS a ON bea.AddressID = a.AddressID
  JOIN Person.StateProvince AS sp ON a.StateProvinceID = sp.StateProvinceID
  WHERE 
    p.PersonType = 'IN' AND sp.CountryRegionCode = 'US'
  GROUP BY 
    a.City
)
SELECT 
  c.CustomerID,
  p.FirstName + ' ' + p.LastName AS Name,
  a.City,
  Individuals.IndividualsInCity,
  SUM(s.SubTotal) AS TotalRevenue
FROM 
  Person.Person AS p
JOIN Sales.Customer AS c ON p.BusinessEntityID = c.PersonID
JOIN Sales.SalesOrderHeader AS s ON c.CustomerID = s.CustomerID
JOIN Sales.SalesTerritory AS t ON c.TerritoryID = t.TerritoryID
JOIN Person.Address AS a ON s.ShipToAddressID = a.AddressID
JOIN IndividualsByCity AS Individuals ON a.City = Individuals.City
WHERE 
  p.PersonType = 'SC' AND t.CountryRegionCode = 'US' AND a.City NOT IN (
    SELECT City FROM TopCities
  )
GROUP BY 
  c.CustomerID, p.FirstName, p.LastName, a.City, Individuals.IndividualsInCity
ORDER BY 
  TotalRevenue DESC;


-- In which cities in the US are the 391 stores clients? 
-- 298 cities 

SELECT 
  a.City,
  COUNT(*) AS StoreCustomersInCity
FROM 
  Person.Person AS p
JOIN Sales.Customer AS c 
  ON p.BusinessEntityID = c.PersonID
JOIN Sales.SalesOrderHeader AS soh
  ON c.CustomerID = soh.CustomerID
JOIN Person.Address AS a
  ON soh.ShipToAddressID = a.AddressID
JOIN Sales.SalesTerritory AS t 
  ON c.TerritoryID = t.TerritoryID
WHERE 
  p.PersonType = 'SC'
  AND t.CountryRegionCode = 'US' -- Add column SubTotal na Table Sales.SalesorderHeader 
GROUP BY a.City
ORDER BY StoreCustomersInCity DESC;




select * 
from Person.StateProvince

select * 
from Person.Address



------------------------------------------------------

-- Revenue by city (All Customers)

SELECT  sum(TotalDue) as Money , Person.Address.City
FROM Sales.SalesOrderHeader
JOIN Person.Address  
ON Sales.SalesOrderHeader.ShipToAddressID = Person.Address.AddressID
JOIN Sales.SalesTerritory 
ON Sales.SalesTerritory.TerritoryID = Sales.SalesOrderHeader.TerritoryID
WHERE Sales.SalesTerritory.[CountryRegionCode] = 'US'
GROUP by Person.Address.City
ORDER BY sum(TotalDue) DESC

-- All customers in US  

SELECT CustomerID
FROM  Sales.SalesOrderHeader
JOIN Sales.SalesTerritory 
ON Sales.SalesTerritory.TerritoryID = Sales.SalesOrderHeader.TerritoryID
WHERE Sales.SalesTerritory.[CountryRegionCode] = 'US'

SELECT *
FROM  Sales.Customer


SELECT *
FROM Person.Address as p
JOIN Person.StateProvince as sp 
ON p.StateProvinceID = sp.StateProvinceID