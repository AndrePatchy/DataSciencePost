Use AdventureWorks
go

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
  )

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