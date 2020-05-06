CREATE EXTERNAL DATA SOURCE nyscovid19_testing
WITH (
    TYPE = BLOB_STORAGE,
    LOCATION = 'https://nyscovid19.blob.core.windows.net/testing'
);
GO

CREATE TABLE PopulationStage (
    CountyRank int,
    County varchar(64),
    Census2010 varchar(16),
    Estimates2018 varchar(16),
    Change varchar(8)
);
GO

CREATE TABLE TestingStage (
    TestDate date,
    County varchar(32),
    NewPositives int,
    CumulativeNumberOfPositives int,
    TotalNumberOfTestsPerformed int,
    CumulativeNumberOfTestsPerformed int
);
GO

BULK INSERT PopulationStage
FROM '111.8.19 Population and Demographics - Population, New York and US- NYS & Counties.csv'
WITH (
    FORMAT = 'CSV',
    DATA_SOURCE = 'nyscovid19_testing',
    FIRSTROW = 5,
    ROWTERMINATOR = '0x0a'
);
GO

BULK INSERT TestingStage
FROM 'New_York_State_Statewide_COVID-19_Testing.csv'
WITH (
    FORMAT = 'CSV',
    DATA_SOURCE = 'nyscovid19_testing',
    FIRSTROW = 2,
    ROWTERMINATOR = '0x0a'
);
GO

CREATE TABLE County (
    CountyId varchar(32) PRIMARY KEY,
    Census int
)
GO

INSERT INTO County(CountyId, Census)
SELECT
    REPLACE(TRIM(County), ' County', ''),
    CAST(REPLACE(Estimates2018, ',', '') as int)
FROM PopulationStage
WHERE County IS NOT NULL AND RIGHT(TRIM(County), 6) = 'County';
GO

CREATE TABLE Testing (
    Id int IDENTITY(1,1) PRIMARY KEY,
    County varchar(32) FOREIGN KEY REFERENCES County(CountyId),
    TestDate date,
    NewPositives int,
    TotalNumberOfTestsPerformed int
);
GO

INSERT INTO Testing (
    County,
    TestDate,
    NewPositives,
    TotalNumberOfTestsPerformed)
SELECT County, TestDate, NewPositives, TotalNumberOfTestsPerformed
FROM TestingStage;
GO

/* very naive, update to reference prior computed column */
CREATE FUNCTION getTotalPositives(@testDate date, @county varchar(32))
RETURNS int AS BEGIN
    DECLARE @ret int;
    SELECT @ret = SUM(NewPositives) FROM Testing
    WHERE TestDate < @testDate AND County = @county;
    IF (@ret IS NULL)
        SET @ret = 0;
    RETURN @ret;
END;
GO

/* very naive, update to reference prior computed column */
CREATE FUNCTION getTotalTestsPerformed(@testDate date, @county varchar(32))
RETURNS int AS BEGIN
    DECLARE @ret int;
    SELECT @ret = SUM(TotalNumberOfTestsPerformed) FROM Testing
    WHERE TestDate < @testDate AND County = @county;
    IF (@ret IS NULL)
        SET @ret = 0;
    RETURN @ret;
END;
GO

ALTER TABLE Testing
ADD CumulativeNumberOfPositives AS (NewPositives + dbo.getTotalPositives(TestDate, County));
GO

ALTER TABLE Testing
ADD CumulativeNumberOfTestsPerformed AS (TotalNumberOfTestsPerformed + dbo.getTotalTestsPerformed(TestDate, County));
GO

GRANT SELECT ON SCHEMA :: [dbo] to public;
GO

CREATE USER public_user WITH PASSWORD = 'NYS-covid-19';
GO
