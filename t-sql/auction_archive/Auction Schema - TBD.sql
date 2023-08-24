-- Create schema for auction
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Auction')
BEGIN
    EXEC('CREATE SCHEMA Auction')
END
GO

-- Functional Specifications Information related 

-- MakeFlag = 0 -> Products outsource manufactured (initial bid price - 75% of Product.ListPrice)
-- MakeFlag = 1 -> Products manufactured in-house (initial bid price - 50% of Product.ListPrice)

-- All products (504) and Manufactured source 

SELECT ProductID, Name, MakeFlag
FROM Production.Product 

-- Amount of commercialized products: 406 

SELECT ProductID, Name, MakeFlag, ListPrice
FROM Production.Product
WHERE SellEndDate IS NULL and DiscontinuedDate IS NULL; 

-- Quantity of currently commercialized products 

SELECT p.ProductID, p.Name, p.MakeFlag, pi.Quantity
FROM Production.Product AS p
JOIN Production.ProductInventory AS pi 
ON p.ProductID = pi.ProductID
WHERE p.SellEndDate IS NULL AND p.DiscontinuedDate IS NULL; -- AND pi.Quantity IS NULL;

-- Of 406 the amount of in-house/outsourced manufactured: 243 in-house / 163 outsourced  

SELECT MakeFlag, COUNT(*) AS ProductCount
FROM Production.Product
WHERE SellEndDate IS NULL and DiscontinuedDate IS NULL
GROUP BY MakeFlag;

-- 200 products with Price 0 = things not for sale 

SELECT ProductID, Name, MakeFlag, ListPrice
FROM Production.Product
WHERE SellEndDate IS NULL and DiscontinuedDate IS NULL and ListPrice = '0';

-- 206 products for sale 

SELECT ProductID, Name, MakeFlag, ListPrice
FROM Production.Product
WHERE SellEndDate IS NULL AND DiscontinuedDate IS NULL AND ListPrice > 0;

-- Auction.Thresholds table 

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Thresholds' AND schema_id = SCHEMA_ID('Auction'))
BEGIN 
    CREATE TABLE Auction.Thresholds(
        ThresholdID INT IDENTITY(1,1) PRIMARY KEY, -- Identity = auto-increment 
        MinimumBidIncrease MONEY, 
        DiscountPercentage DECIMAL (2,2),
    )
END 
GO 

-- Auction.AuctionInfo table 

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuctionInfo' AND schema_id = SCHEMA_ID('Auction'))
BEGIN 
    CREATE TABLE Auction.AuctionInfo (
        AuctionID INT PRIMARY KEY IDENTITY(1,1),
        ThresholdID INT FOREIGN KEY REFERENCES Auction.Thresholds(ThresholdID),
        ProductID INT FOREIGN KEY REFERENCES Production.Product(ProductID), 
        InitialBidPrice MONEY,
        ExpireDate DATE,
        Status VARCHAR(10)
    )
END 
GO 

-- Auction.Bids table

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Bids' AND schema_id = SCHEMA_ID('Auction'))
BEGIN
    CREATE TABLE Auction.Bids(
        AuctionID INT FOREIGN KEY REFERENCES Auction.AuctionInfo(AuctionID),
        CustomerID INT FOREIGN KEY REFERENCES Sales.Customer(CustomerID),
        BidAmount MONEY,
        Date DATE,
    )
END 
GO


-- Insert rows in Auction.ProductsAuction

IF NOT EXISTS (SELECT * FROM Auction.Thresholds) -- to check if the table is empty. If it is empty values are added
BEGIN
    INSERT INTO Auction.Thresholds(MinimumBidIncrease, DiscountPercentage) VALUES(0.05, 0.5), (0.05, 0.75);
END

-- uspAddProductToAuction Procedure 

create or alter procedure uspAddProcuctToAuction
    @ProductID int, 
    @ExpireDate_ datetime = NULL, 
    @InitialBidPrice money = NULL 

AS
BEGIN
SET NOCOUNT ON;

	-- Check if the product exists in the Product.ProductID in the Production Schema 
   IF Not EXISTS (SELECT * FROM Production.Product WHERE ProductID = @ProductID)
	   BEGIN
		    RAISERROR('Invalid ProductID', 16, 1, @PRODUCTID);
		    RETURN;
	    END

    -- Check if the product is being currently being commercialized
   IF EXISTS (SELECT * FROM Production.Product WHERE ProductID = @ProductID and SellEndDate is not NULL and DiscontinuedDate is not null)
	   BEGIN
		    RAISERROR('PRODUCT ID %d is not currently being commercialized', 16, 1, @PRODUCTID);
		    RETURN;
	    END 

    -- Check if the product ID already exists on AuctionInfo table 
	IF EXISTS (SELECT * FROM Auction.AuctionInfo WHERE ProductID = @ProductID AND Status = 'Active')
	BEGIN
		    RAISERROR('That product is already being auctioned', 16, 1, @PRODUCTID);
		    RETURN;
	    END
END


drop procedure uspAddProcuctToAuction;
                                

select * from Auction.Bids;
select * from Auction.Thresholds;
select * from Auction.AuctionInfo;
