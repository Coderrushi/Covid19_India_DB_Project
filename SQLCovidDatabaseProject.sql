USE COVID_DB;

SELECT * FROM dbo.StatewiseTestingDetails;
SELECT * FROM dbo.covid_19_india;
SELECT * FROM dbo.covid_vaccine_statewise;
SELECT * FROM dbo.StatewiseTestingDetails;

SELECT 
	[State],
	Updated_On,
	SUM(ISNULL(Covaxin_Doses_Administered,0)) AS Total_Covaxin,
	SUM(ISNULL(CoviShield_Doses_Administered, 0)) AS Total_Covishield,
	SUM(ISNULL(Sputnik_V_Doses_Administered, 0)) AS Total_SputnikV,
	(SUM(ISNULL(Covaxin_Doses_Administered,0))*100 / SUM(ISNULL(Total_Doses_Administered,0))) AS Covaxin_Percentage,
	(SUM(ISNULL(CoviShield_Doses_Administered, 0))*100 / SUM(ISNULL(Total_Doses_Administered, 0))) AS CoviShield_Percentage, 
	(SUM(ISNULL(Sputnik_V_Doses_Administered, 0))*100 / SUM(ISNULL(Total_Doses_Administered, 0))) AS Sputnik_Percentage
FROM dbo.covid_vaccine_statewise 
GROUP BY State, Updated_On;

--**Joins**

--1. Which state has the highest number of confirmed cases on a specific date?
SELECT  CI.State_UnionTerritory, CI.Confirmed AS Confirmed_Cases, CI.Date
FROM dbo.covid_19_india CI
JOIN dbo.StatewiseTestingDetails ST
ON CI.[Date] = ST.[Date]
GROUP BY  CI.State_UnionTerritory, CI.Confirmed, CI.Date
ORDER BY CI.Confirmed DESC
OFFSET 0 ROWS
FETCH NEXT 1 ROWS ONLY;

--2. Show the total number of deaths in each state for a given date.
SELECT CI.[Date], ST.[State], SUM(CI.Deaths) AS Total_Deaths 
FROM dbo.covid_19_india CI
JOIN dbo.StatewiseTestingDetails ST
ON CI.[Date] = ST.[Date]
GROUP BY CI.[Date], ST.[State]
ORDER BY CI.[Date]

--3. List the states along with the total number of confirmed cases, deaths, and recoveries.
SELECT s.[State], 
	SUM(CAST(c.Confirmed AS BIGINT)) AS Total_Confirmed_Cases,
	SUM(CAST(c.Deaths AS BIGINT)) AS Total_Deaths, 
	SUM(CAST(c.Cured AS BIGINT)) AS Total_Cured 
FROM covid_19_india c
INNER JOIN StatewiseTestingDetails s
ON c.[Date] = s.[Date]
GROUP BY s.[State];


--**Aggregate Functions**
--4. Claculate the average number of the  new deaths per day across all countries.
SELECT [Date], AVG(Deaths) AS AVG_DEATH_PER_DAY
FROM covid_19_india
GROUP BY [Date]
ORDER BY [Date] DESC;

--5. Find the maximum number of active cases recorded in any country on a specific date.
SELECT [Date], [State], MAX(Positive) as Active_Cases
FROM  dbo.StatewiseTestingDetails 
GROUP BY  [Date], [State]
ORDER BY Active_Cases DESC;

SELECT [Date], [State], Positive
FROM  dbo.StatewiseTestingDetails 
WHERE Positive = (SELECT MAX(Positive) FROM dbo.StatewiseTestingDetails);

--**Strored Procedure**
--6. Create a stored procedure that returns the total number of recovered cases for a given state and date.
GO
CREATE PROCEDURE proc_TotalNumberOfRecoveredCases
	@State VARCHAR(20),
	@Date DATE
	AS
		BEGIN
			SELECT State_UnionTerritory, SUM(Cured) AS Total_Recoveries, [Date]
			FROM covid_19_india
			WHERE State_UnionTerritory = @State AND [Date] = @Date
			GROUP BY State_UnionTerritory, [Date]
		END
GO
EXEC proc_TotalNumberOfRecoveredCases @State = 'Maharashtra', @Date = '2020-10-24'

GO
--7. Design a stored procedure to update the number of deaths for a specific state and date.
CREATE PROCEDURE proc_UpdateNumberOfDeaths
	@State VARCHAR(20),
	@Date DATE,
	@NumberOfDeaths INT
	AS
		BEGIN
			UPDATE covid_19_india
			SET Deaths = Deaths + @NumberOfDeaths
			WHERE State_UnionTerritory = @State AND [Date] = @Date
		END
GO
EXEC proc_UpdateNumberOfDeaths @State = Rajasthan, @Date = '2020-03-03', @NumberOfDeaths = 1;
GO
 --**Views**
 --8. Create a view that displays the total number of cases (confirmed, deaths, and recovered) for each state on a specific date.
 CREATE VIEW vw_TotalNumberOfCases
 AS
	SELECT State_UnionTerritory, [Date], SUM(Confirmed) AS Confirmed_Cases, SUM(Deaths) AS Total_Deaths, SUM(Cured) AS Total_Recovered
	FROM covid_19_india
	GROUP BY State_UnionTerritory, [Date]

SELECT * FROM vw_TotalNumberOfCases
GO
--9. Implement a view to show the latest data (confirmed, deaths, recovered) for each state.
CREATE OR ALTER VIEW vw_LatestDataForEachState
AS
	SELECT State_UnionTerritory, [Date], SUM(Confirmed) AS Confirmed_Cases, SUM(Deaths) AS Total_Deaths, SUM(Cured) AS Total_Recovered
	FROM covid_19_india
	WHERE [Date] >= DATEADD(DAY, -30, (SELECT MAX([Date]) FROM covid_19_india))
	GROUP BY State_UnionTerritory, [Date];

SELECT * FROM vw_LatestDataForEachState

--**T-SQL**
--10. Write a T-SQL query to calculate the total number of cases (confirmed + deaths + recovered) for each state
GO
BEGIN
		SELECT State_UnionTerritory AS [State], 
			CAST(SUM(CAST (Confirmed AS BIGINT)) AS BIGINT) + 
			CAST(SUM(CAST (Deaths AS BIGINT)) AS BIGINT)+ 
			CAST(SUM(CAST(Cured AS BIGINT)) AS BIGINT) AS Total_Cases
		FROM covid_19_india
		GROUP BY State_UnionTerritory
		ORDER BY Total_Cases DESC;
END
GO
--11. Use T-SQL to identify the state with the highest number of new cases reported on a specific date.
CREATE PROCEDURE proc_HighestNumberOfCasesOnSpecificDate
	@Date DATE
	AS
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
				SELECT State_UnionTerritory AS [State], [Date], Confirmed
				FROM covid_19_india
				WHERE [Date] = @Date AND Confirmed = (SELECT MAX(Confirmed) FROM covid_19_india WHERE [Date] = @Date)
				GROUP BY State_UnionTerritory, [Date], Confirmed
				ORDER BY Confirmed;
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0 ROLLBACK;
			THROW;
		END CATCH
	END
GO
EXEC proc_HighestNumberOfCasesOnSpecificDate @Date = '2020-03-03'
GO
--**CTE (Comman Table Expressions)**
--12. Create a CTE to calculate the percentage increase in confirmed cases for each state over the past week.
WITH cte_PercentageIncreaseInConfirmedCases AS (
	SELECT [State], 
		[Date], 
		ISNULL(Positive, 0) AS Confirmed_Cases, 
		ROUND(ISNULL((Positive*100/TotalSamples),0) ,2) AS ConfirmedCases_In_Percentage
	FROM StatewiseTestingDetails
	WHERE [Date] >= DATEADD(DAY, -7, (SELECT MAX(Date) FROM StatewiseTestingDetails))
)
SELECT * FROM cte_PercentageIncreaseInConfirmedCases;
GO
--13. Use a CTE to find the state with the highest number of active cases at the moment
DECLARE @Date DATE
SET @Date = '2021-08-04'
IF @Date >= '2020-01-30' AND @Date <= '2021-08-11'
BEGIN
	WITH cte_HighestNumberOfActiveCases AS (
		SELECT State_UnionTerritory, [Date], Confirmed
		FROM covid_19_india
		WHERE [Date] = @Date AND Confirmed = (SELECT MAX(Confirmed) FROM covid_19_india WHERE [Date] = @Date)
	)
	SELECT * FROM cte_HighestNumberOfActiveCases
END
ELSE
	BEGIN
		PRINT 'Data is not available..';
	END

--**INDEXES**
--15. Implement an index on the state column to speed up search operations.
CREATE NONCLUSTERED INDEX IX_covid_19_india_State_UnionTerritory
ON covid_19_india(State_UnionTerritory);
GO
--**User-Defined Functions (UDF)**
--16. Develop a UDF to calculate the mortality rate (deaths/confirmed cases * 100) for a given state.
CREATE OR ALTER FUNCTION func_ToCalculateMortalityRate(@State VARCHAR(20))
RETURNS DECIMAL
	BEGIN
		DECLARE @Mortality_Rate AS DECIMAL(10,2)
		SELECT @Mortality_Rate = 
			CASE
				 WHEN SUM(Confirmed) > 0 THEN (SUM(Deaths)*100.0) / SUM(Confirmed) 
            ELSE 0
				END
			FROM covid_19_india
			WHERE State_UnionTerritory = @State
		RETURN @Mortality_Rate
	END
GO
SELECT dbo.func_ToCalculateMortalityRate ('Bihar') AS Mortality_Rate
GO
--17. Create a UDF to determine the recovery rate (cured / confirmed *100) for a specific date.
CREATE FUNCTION func_ToCalculateRecoveryRate(@Date DATE)
RETURNS DECIMAL
	BEGIN
		DECLARE @Recovery_Rate AS DECIMAL(10,2)
		SELECT @Recovery_Rate = 
			CASE	
				WHEN SUM(Confirmed) > 0 THEN (SUM(Cured)*100.0) / SUM(Confirmed)
			ELSE 0
				END
			FROM covid_19_india
			WHERE [Date] = @Date
		RETURN @Recovery_Rate
	END
GO
SELECT dbo.func_ToCalculateRecoveryRate ('2020-08-11') AS Recovery_Rate
GO
--**Group By**
--18. Group the data by state and  calculate the total number of confirmed cases for each state.
SELECT State_UnionTerritory, SUM(Confirmed) AS Total_Confirmed_Cases
FROM covid_19_india
GROUP BY State_UnionTerritory
ORDER BY Total_Confirmed_Cases DESC;

--19. Group the data by date and compute the total number of deaths and recoveries for each date.
SELECT [Date], SUM(Deaths) AS Total_Deaths, SUM(Cured) AS Total_Recovered 
FROM covid_19_india
GROUP BY [Date]
ORDER BY [Date];

--20. Group the data by state and calculate the average number of new cases reported daily for each state.
SELECT State_UnionTerritory, [Date], AVG(Confirmed) AS Average_New_Cases
FROM covid_19_india
GROUP BY State_UnionTerritory, [Date]
ORDER BY [Date] DESC;

GO
--Queries on covid_19_india:
--To find out the death percentage locally.
SELECT  State_UnionTerritory, 
		CASE 
			WHEN SUM(Confirmed) > 0 THEN ROUND(((SUM(Deaths)*100.0) / SUM(Confirmed)),2)
			ELSE 0
		END AS Statewise_Death_Percentage
FROM covid_19_india
GROUP BY State_UnionTerritory
ORDER BY Statewise_Death_Percentage DESC;
GO

--To find out the infected population percentage locally
SELECT State, 
			CASE 
				WHEN SUM(TotalSamples) > 0 THEN ROUND(((SUM(Positive)*100.0) / SUM(TotalSamples)),2)
			     ELSE 0
			END AS Statewise_Infected_Percentage
FROM StatewiseTestingDetails
GROUP BY [State]
ORDER BY Statewise_Infected_Percentage DESC;

--To find out the state with the highest infection rates.
SELECT TOP 1 State,
	CASE 
		WHEN SUM(TotalSamples) > 0 THEN ROUND((SUM((Positive)*100.0) / SUM(TotalSamples)), 2)
	    ELSE 0
	END AS Highest_Infection_Rate
FROM StatewiseTestingDetails
GROUP BY [State]
ORDER BY Highest_Infection_Rate DESC;

--To find out the state with the highest death counts.
SELECT TOP 1 State_UnionTerritory, 
			CASE	
				WHEN SUM(Confirmed) > 0 THEN ROUND((SUM(Deaths)*100.0 / SUM(Confirmed)), 2)
				ELSE 0
			END AS Highest_Deaths_Rate
FROM covid_19_india
GROUP BY State_UnionTerritory
ORDER BY Highest_Deaths_Rate DESC

--Average number of deaths by day for states
SELECT State_UnionTerritory, [Date], AVG(Deaths) AS Average_Deaths_Per_Day
FROM covid_19_india
GROUP BY State_UnionTerritory, [Date]
ORDER BY [Date] DESC;

--Queries on Vaccination:
--Total vaccinated with at least 1 dose over time.
SELECT Updated_On, [State],
		SUM(First_Dose_Administered + Second_Dose_Administered) AS Total_Vaccinated_At_Least_One_Dose
FROM covid_vaccine_statewise
WHERE First_Dose_Administered IS NOT NULL AND Second_Dose_Administered IS NOT NULL
GROUP BY Updated_On, [State]
ORDER BY Updated_On;

--Percentage of the population vaccinated with at least the first dose until 30-09-2021 (TOP 3)
SELECT TOP 3 [State], 
			ROUND(SUM(Total_Doses_Administered - Second_Dose_Administered)*100.0 / SUM(Total_Doses_Administered), 2)AS Total_Vaccinated_At_Least_One_Dose_Percentage
FROM covid_vaccine_statewise
WHERE Updated_On <= '2021-09-30'
GROUP BY [State];

--Total State-wise Confirmed Cases
SELECT State_UnionTerritory, SUM(Confirmed) AS Confirmed_Cases
FROM covid_19_india
GROUP BY State_UnionTerritory
ORDER BY Confirmed_Cases DESC;

--Maximum Active cases statewise till date
SELECT [State], SUM(Positive) AS Maximum_Cases
FROM StatewiseTestingDetails
WHERE [Date] <= GETDATE()
GROUP BY [State]
ORDER BY Maximum_Cases DESC;

--Maximum per day confirmed cases in states
SELECT [Date],  SUM(Confirmed) AS Confirmed_Cases
FROM covid_19_india
GROUP BY [Date], State_UnionTerritory 
ORDER BY [Date] DESC

--Maximum per day Death causes in states
SELECT [Date], State_UnionTerritory, SUM(Deaths) AS Deaths_Cases
FROM covid_19_india
GROUP BY [Date], State_UnionTerritory 
ORDER BY [Date] DESC

--statewise mortality rate
SELECT State_UnionTerritory,
		CASE
			WHEN SUM(Confirmed) > 0 --THEN CAST(ROUND((SUM(Deaths)*100.0 / SUM(Confirmed)), 2)) 
				THEN RTRIM(CAST(CAST((SUM(Deaths) * 100.0 / SUM(Confirmed)) AS DECIMAL(10, 2)) AS VARCHAR))
			ELSE '0'
		END AS Mortality_Rate 
FROM covid_19_india
GROUP BY State_UnionTerritory
ORDER BY Mortality_Rate DESC;

--write a query that gives on each day which state having the maximim number of deaths
WITH cte_Everyday_Statewise_Maximum_Deaths AS 
(
	SELECT [Date], State_UnionTerritory, Deaths, 
		ROW_NUMBER() OVER (PARTITION BY [Date] ORDER BY Deaths DESC) AS rankb
	FROM covid_19_india
	ORDER BY [Date]
)
SELECT [Date],
	State_UnionTerritory,
	Deaths
FROM cte_Everyday_Statewise_Maximum_Deaths
WHERE rankb = 1
ORDER BY [Date] DESC;

--backup of database
BACKUP DATABASE COVID_DB
TO DISK = 'F:\Database_Backups\Covid19_India_FullBackup1.bak'
WITH FORMAT,
Name = 'Full Back Of Covid19 India';

