Use AdventureWorks
Go

create or alter procedure uspUpdateProductAuctionStatus

as 
BEGIN

SELECT *
FROM AdventureWorks.dbo.AuctionStatus;

END;

exec uspUpdateProductAuctionStatus;
