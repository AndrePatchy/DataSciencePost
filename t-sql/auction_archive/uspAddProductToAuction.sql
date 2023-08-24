Use AdventureWorks
Go

create or alter procedure uspAddProcuctToAuction

@ProductID int, 
@ExpireDate_ datetime = NULL, 
@InitialBidPrice money  = NULL 

as
Begin
	If OBJECT_ID(N'[AdventureWorks].[dbo].[AUCTIONS]', N'U') IS NULL
		Begin
			create table [AdventureWorks].[dbo].[AUCTIONS] (
				ProductID int not null primary key, 
				ExpireDate_ datetime, 
				InitialBidPrice money
				);
		End
end

Begin
	If OBJECT_ID(N'[AdventureWorks].[dbo].[AuctionStatus]', N'U') IS NULL
		Begin
			create table [AdventureWorks].[dbo].AuctionStatus (
				ProductID int not null, 
				AuctionStatus varchar(255)

				);
		End
end

	Insert into AdventureWorks.dbo.AuctionStatus (ProductID, AuctionStatus)
	values (@ProductID, 'Active')

BEGIN 

	SET NOCOUNT ON;

	-- Check if the product ID exists on SalesOrderDetail table
   IF Not EXISTS (SELECT * FROM Sales.SalesOrderDetail WHERE ProductID = @ProductID)
	   BEGIN
		  RAISERROR('PRODUCT ID %d does not exists', 16, 1, @PRODUCTID);
		  RETURN;
	   END
   IF EXISTS (SELECT * FROM Production.Product WHERE ProductID = @ProductID and SellEndDate is not NULL )
	   BEGIN
		  RAISERROR('PRODUCT ID %d is not on sale anymore', 16, 1, @PRODUCTID);
		  RETURN;
	   END 
   -- Check if the product was discontinued 
   IF EXISTS (SELECT * FROM Production.Product WHERE ProductID = @ProductID and DiscontinuedDate is not NULL )
	   BEGIN
		  RAISERROR('PRODUCT ID %d was discontinued', 16, 1, @PRODUCTID);
		  RETURN;
	   END 
	-- Check if the product ID already exists on Auctions table 
		IF EXISTS (SELECT * FROM AdventureWorks.dbo.AUCTIONS WHERE ProductID = @ProductID)
		BEGIN
			RAISERROR('PRODUCT ID %d already exists', 16, 1, @PRODUCTID);
			RETURN;
		END
   -- Check if the product is on sale

   BEGIN
	   IF @ExpireDate_ IS NULL and @InitialBidPrice is null 

			Insert into AdventureWorks.dbo.AUCTIONS (ProductID, ExpireDate_, InitialBidPrice)
			values (@ProductID, DATEADD(WEEK,1 ,GETDATE()), (Select distinct ( Case when b.MakeFlag = 0 then  Min(UnitPrice) * 0.25
																 Else Min(UnitPrice) * 0.5
																 end) as InitialBidPrice
											   from sales.SalesOrderDetail as a 
											   left join Production.Product as b
											   on a.ProductID = b.ProductID
											   where @ProductID = a.ProductID
											   group by b.MakeFlag))
		
	   ELSE IF @ExpireDate_ IS NULL and @InitialBidPrice is not null 

			Insert into AdventureWorks.dbo.AUCTIONS (ProductID, ExpireDate_, InitialBidPrice)
			values (@ProductID, DATEADD(WEEK,1 ,GETDATE()), @InitialBidPrice)
	   
	   ELSE IF @ExpireDate_ IS not NULL and @InitialBidPrice is null 

			Insert into AdventureWorks.dbo.AUCTIONS (ProductID, ExpireDate_, InitialBidPrice)
			values (@ProductID, @ExpireDate_, (Select distinct ( Case when b.MakeFlag = 0 then  Min(UnitPrice) * 0.25
																 Else Min(UnitPrice) * 0.5
																 end) as InitialBidPrice
											   from sales.SalesOrderDetail as a 
											   left join Production.Product as b
											   on a.ProductID = b.ProductID
											   where @ProductID = a.ProductID 
											   group by b.MakeFlag))
	   ELSE 
			Insert into AdventureWorks.dbo.AUCTIONS (ProductID, ExpireDate_, InitialBidPrice)
			values (@ProductID, @ExpireDate_, @InitialBidPrice)

   end

END;

EXEC uspAddProcuctToAuction  998;


SELECT *
FROM AdventureWorks.dbo.AUCTIONS;

SELECT *
FROM AdventureWorks.dbo.AuctionStatus;



SELECT *
FROM Sales.SalesOrderDetail
where ProductID = 999;


SELECT *
FROM Production.Product
where DiscontinuedDate is null;

drop table [AdventureWorks].[dbo].[AUCTIONS]

