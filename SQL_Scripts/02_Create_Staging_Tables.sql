/* =====================================================================
   ARMDD 2026/27 - MoreRhythm Data Mart
   Script : 02_Create_Staging_Tables.sql
   Owner  : Person A
   Purpose: Create the Staging Area database and its structures, following
            the ARMDD lab conventions:
            - stg_<Table>      : transient tables filled on every ETL run
            - stg_<Table>DQP   : Data Quality Problems tables - records that
                                 cannot be corrected automatically, with a DQP
                                 column describing the problem (never loaded
                                 into the Data Mart)  [lab 4: CardDQP]
            - <Attr>_Lookup    : lookup tables used to make values explicit /
                                 standardised  [lab 4: MaritalStatusDescription_Lookup]
            - etl_*            : incremental-load watermarks and ETL run log
   Notes  : * Database name must match the SSIS project parameter
              StagingAreaDBName (default: MoreRhythm_StagingArea).
            * Script is re-runnable (drops and recreates tables).
            * DQP tables store source values as NVARCHAR so that values
              violating the domain (wrong type/length) can still be kept.
   ===================================================================== */
USE master;
GO
IF DB_ID(N'MoreRhythm_StagingArea') IS NULL
    CREATE DATABASE MoreRhythm_StagingArea;
GO
ALTER DATABASE MoreRhythm_StagingArea SET RECOVERY SIMPLE;   -- staging data is reproducible
GO
USE MoreRhythm_StagingArea;
GO

/* ---------------------------------------------------------------------
   Drop existing objects (re-runnable)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.stg_InvoiceLines, dbo.stg_Invoices, dbo.stg_Customers,
                     dbo.stg_Products, dbo.stg_Suppliers, dbo.stg_Employees,
                     dbo.stg_InvoiceLinesDQP, dbo.stg_InvoicesDQP, dbo.stg_CustomersDQP, dbo.stg_ProductsDQP,
                     dbo.CustomerDuplicate_Lookup, dbo.Currency_Lookup, dbo.stg_CurrencyRate,
                     dbo.etl_LoadControl, dbo.etl_RunLog;
GO

/* =====================================================================
   ETL CONTROL
   ===================================================================== */

/* One row per ETL execution - every staging/error row carries the RunID */
CREATE TABLE dbo.etl_RunLog (
    RunID            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_etl_RunLog PRIMARY KEY,
    PackageName      NVARCHAR(128)     NOT NULL,
    StartTime        DATETIME2(0)      NOT NULL CONSTRAINT DF_etl_RunLog_Start DEFAULT SYSDATETIME(),
    EndTime          DATETIME2(0)      NULL,
    Status           VARCHAR(10)       NOT NULL CONSTRAINT DF_etl_RunLog_Status DEFAULT 'RUNNING'
                     CONSTRAINT CK_etl_RunLog_Status CHECK (Status IN ('RUNNING','SUCCESS','FAILED')),
    RowsExtracted    INT               NULL,
    RowsRejected     INT               NULL,
    RowsLoaded       INT               NULL
);
GO

/* Incremental load watermark per source table:
   next run extracts rows WHERE UpdatedAt > LastUpdatedAt (see report). */
CREATE TABLE dbo.etl_LoadControl (
    SourceTable      VARCHAR(50)  NOT NULL CONSTRAINT PK_etl_LoadControl PRIMARY KEY,
    LastUpdatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_etl_LoadControl_Last DEFAULT '1900-01-01',
    LastRunID        INT          NULL,
    LastRunTime      DATETIME2(0) NULL
);
INSERT INTO dbo.etl_LoadControl (SourceTable)
VALUES ('customers'),('invoices'),('invoices_lines'),('products'),('suplliers'),('employees');
GO

/* =====================================================================
   LOOKUP TABLES AND CURRENCY RATES
   ===================================================================== */

/* Currency_Lookup: free-text currency of the source -> ISO 4217 code */
CREATE TABLE dbo.Currency_Lookup (
    SourceCurrency   NVARCHAR(11)   NOT NULL CONSTRAINT PK_Currency_Lookup PRIMARY KEY,  -- invoices.currency
    CurrencyCode     NCHAR(3)       NOT NULL
);
INSERT INTO dbo.Currency_Lookup (SourceCurrency, CurrencyCode)
VALUES (N'EURO', N'EUR'), (N'EUR', N'EUR'), (N'LIBRA', N'GBP'), (N'GBP', N'GBP');   -- future UK branch
GO

/* stg_CurrencyRate: daily exchange rates (e.g. ECB reference rates file),
   source for FactCurrencyRate; RateToEUR = EUR for 1 unit of currency    */
CREATE TABLE dbo.stg_CurrencyRate (
    CurrencyCode     NCHAR(3)       NOT NULL,
    RateDate         DATE           NOT NULL,
    RateToEUR        DECIMAL(18,6)  NOT NULL CONSTRAINT CK_stg_CurrencyRate_Pos CHECK (RateToEUR > 0),
    CONSTRAINT PK_stg_CurrencyRate PRIMARY KEY (CurrencyCode, RateDate)
);
GO

/* CustomerDuplicate_Lookup: result of the customer de-duplication -
   every source customer id -> surviving id                               */
CREATE TABLE dbo.CustomerDuplicate_Lookup (
    SourceCustomerID    NUMERIC(10,0) NOT NULL CONSTRAINT PK_CustomerDuplicate_Lookup PRIMARY KEY,
    SurvivorCustomerID  NUMERIC(10,0) NOT NULL,
    MatchRule           NVARCHAR(30)  NOT NULL,   -- SELF | SAME_NIF | FUZZY_NAME_ZIP
    MatchScore          DECIMAL(5,4)  NULL,       -- similarity from SSIS Fuzzy Grouping
    RunID               INT           NULL
);
GO
