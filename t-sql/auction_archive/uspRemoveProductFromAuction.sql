Use AdventureWorks
Go

create or alter procedure uspRemoveProductFromAuction

@ProductID int

as 

   IF EXISTS (Select ProductID from AdventureWorks.dbo.AUCTIONS where ProductID = @ProductID)
	   BEGIN
		  DELETE from AdventureWorks.dbo.AUCTIONS where ProductID = @ProductID
		  Update AdventureWorks.dbo.AuctionStatus
		  set AuctionStatus = 'Canceled' where ProductID = @ProductID
	   END
   ELSE 
	   BEGIN
		  RAISERROR('PRODUCT ID %d is not on auction', 16, 1, @PRODUCTID);
		  RETURN;
	   END;

exec uspRemoveProductFromAuction 996


SELECT *
FROM AdventureWorks.dbo.AUCTIONS;

SELECT *
FROM AdventureWorks.dbo.AuctionStatus;

