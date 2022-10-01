/***
Cleaing Data Form AAM Cutomer Service Center 
i remved date time stamp from date column by add new colum
to table and convert date time stamp to date as standardize Date Format
Deleted unwanted column after cleansing data 
***/

----------------------------------------------------------------
-- -- Standardize Date Format

SELECT [initiation date]
FROM AAMCSC.dbo.Transactions

ALTER TABLE Transactions 
ADD TransactionDate DATE

UPDATE Transactions 
SET TransactionDate = CONVERT(DATE,[initiation date])

-----------------------------------------------------------------
--- Delete unused column after modify data

ALTER TABLE Transactions
DROP COLUMN [initiation date]

-----------------------------------------------------------------

/*****
Select data that we are going to use after apply filtter on it & stored on 
another table for more explorer & visulazation on power bi 
*****/
----- apply filter on data and extrect what's need to future use --------
SELECT 
[Application ID] AS ApplcationID, 
[system] AS [System], 
[employee(created by)] AS EmplyeeName, 
[service] AS [Services], 
[ center] AS [AAMCenter],
[TransactionDate]
FROM AAMCSC.dbo.Transactions
WHERE [CS-staff - center] <> 'No'
AND [CS-Services] <> 'No'
AND [ center] <> 'Lands'

------- created fact table store filttred data --------------
DROP TABLE IF EXISTS FactTransactions
CREATE TABLE FactTransactions
(
[ApplcationID] VARCHAR(255) NOT NULL,
[System] VARCHAR(255),
[EmplyeeName] NVARCHAR(255),
[Services] NVARCHAR(255),
[AAMCenter] VARCHAR(255),
[TransactionDate] DATE
)
------- insert our fact data into new table --------------
INSERT INTO FactTransactions
SELECT 
[Application ID], [system],[employee(created by)],[service],[ center],[TransactionDate]
FROM AAMCSC..Transactions
WHERE [CS-staff - center] <> 'No'
AND [CS-Services] <> 'No'
AND [ center] <> 'Lands'
-----------------------------------------------------------------

-----statistics for collecting and analyzing numerical and aggregation for insight from sql -----

-- Total transactions per center group by centers name
CREATE VIEW VwReportTotalTransPerCenter AS
SELECT AAMCenter, COUNT(ApplcationID) AS TotalTransPerCenter
FROM AAMCSC.dbo.FactTransactions
GROUP BY AAMCenter

------------------------------------------------------
-- Total Percentage for CSC Centers & Total Center percentage %Transactions 
CREATE VIEW VwRepTansPercentage AS
WITH CenterValue(CsCenter, TotalTransPerCenter)
AS
(
SELECT AAMCenter, COUNT(ApplcationID) AS TotalTransPerCenter
FROM AAMCSC.dbo.FactTransactions
GROUP BY AAMCenter
),
TotalTrans (TotalTrans)
AS
(
SELECT Count(ApplcationID) AS TotalTrans
FROM AAMCSC.dbo.FactTransactions
)
SELECT CsCenter, TotalTransPerCenter, --TotalValueTrans,
CONVERT(FLOAT,TotalTrans)/CONVERT(FLOAT,TotalTransPerCenter)*100 AS TotalPercentage
FROM CenterValue,TotalTrans



----------------------------------------------------------------------------
----- Total Transactions By Services --------
CREATE VIEW  VmTotalTansPerServices AS
SELECT   [Services], AAMCenter,
COUNT(ApplcationID) Over (PARTITION BY  [Services]) AS TotalTransPerServices
FROM AAMCSC.dbo.FactTransactions
GROUP BY  [Services], AAMCenter, ApplcationID

----------------------------------------------------------------------------
-- ---- Total Transactins per Employee and center -----
CREATE VIEW VmTotalEmpTrans AS
SELECT  EmplyeeName, COUNT(ApplcationID) AS TotalTransPerEmp, 
AAMCenter
FROM AAMCSC.dbo.FactTransactions a
GROUP BY EmplyeeName, AAMCenter


---------------------------------------------------------------------------- 
---- Employee Margain line for tatal trans per cenetr % employee total trans 
CREATE VIEW VmMarginLineEmpTransPerCenter AS
WITH CentersTotalTrans (AAMCenter, TotalTansPerCenter)
AS
(
SELECT AAMCenter, Count(ApplcationID) AS TotalTansPerCenter
FROM AAMCSC..FactTransactions
GROUP BY AAMCenter
),
TotalEmplTans(EmplyeeName, TotalTransPerEmp, AAMCenter)
AS
(
SELECT  a.EmplyeeName, COUNT(a.ApplcationID) AS TotalTransPerEmp, 
AAMCenter
FROM AAMCSC.dbo.FactTransactions a
GROUP BY a.EmplyeeName, AAMCenter
)
SELECT EmplyeeName, TotalTansPerCenter,TotalTransPerEmp,
(CONVERT(FLOAT,TotalTansPerCenter)/CONVERT(FLOAT,TotalTransPerEmp))*100 AS EmpMarginLine 
FROM TotalEmplTans a 
JOIN CentersTotalTrans b
 ON a.AAMCenter = b.AAMCenter
--ORDER BY EmplyeeName

-----------------------------------------------------------------------------------
--- Create dim table for date to filter data on diffrent catg basid on date period 
-- and extract data for our dim table from fact table bases on transactin date column -------
--- dim table for date created ------
DROP TABLE IF EXISTS DimDate
CREATE TABLE DimDate
(
  [Datekey] INT IDENTITY(100,1)  PRIMARY KEY,
  [Date] DATE NOT NULL,
  [DayName] TEXT NOT NULL,
  [DayofMonth] INT NOT NULL,
  [DayOfYear] INT NOT NULL,
  [MonthNo] INT NOT NULL,
  [MonthName] TEXT NOT NULL,
  [MonthNameShort] TEXT NOT NULL,
  [Year] INT NOT NULL,
  [Quarter] TEXT NOT NULL,
)

-----------  extrac date table data from FactTransactions table columns--------------

INSERT INTO DimDate
SELECT  
TransactionDate as [Date],    
DATENAME(DW, TransactionDate) AS [DayName],  
DATEPART(DAY FROM TransactionDate) AS [DayofMonth],   
DATEPART(dayofyear FROM TransactionDate) AS [DayOfYear],   
DATEPART(MONTH FROM TransactionDate) AS [MonthNo],   
DATENAME(MONTH,TransactionDate) AS [MonthName],   
FORMAT(TransactionDate, 'MMM') AS [MonthNameShort],   
DATENAME(YEAR FROM TransactionDate) AS [Year], 
DATENAME(Quarter, TransactionDate) AS [Quarter]  
FROM AAMCSC.dbo.FactTransactions
ORDER BY TransactionDate ASC


/*First, the CTE uses the ROW_NUMBER() function to find the duplicate rows 
specified by values in the date value.
Then, the DELETE statement deletes all the duplicate rows but keeps only one occurrence of each duplicate group*/

WITH CTe AS 
(
SELECT [Date], 
ROW_NUMBER() OVER(PARTITION  BY [Date] ORDER BY [Date]) AS Row_Num   
FROM DimDate
)
DELETE FROM CTe
WHERE Row_Num > 1