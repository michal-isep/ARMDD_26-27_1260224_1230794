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

/* =====================================================================
   STAGING TABLES (transient: truncated at the start of each run)
   ===================================================================== */

/* ---- Customers -------------------------------------------------------- */
CREATE TABLE dbo.stg_Customers (
    CustomerID          NUMERIC(10,0) NOT NULL,     -- customers.number
    SurvivorCustomerID  NUMERIC(10,0) NULL,         -- filled by de-duplication
    CustomerName        NVARCHAR(55)  NOT NULL,     -- trimmed, proper case
    CustomerNameNorm    NVARCHAR(55)  NULL,         -- upper, no accents/punctuation/legal suffix (matching key)
    TaxNumber           VARCHAR(20)   NULL,         -- trimmed; NULL when placeholder (blank/zeros)
    IsTaxNumberValid    BIT           NULL,         -- PT NIF modulo-11 check digit
    Phone               VARCHAR(20)   NULL,         -- digits only
    Mobile              VARCHAR(20)   NULL,         -- digits only
    ContactName         NVARCHAR(30)  NULL,
    Email               VARCHAR(45)   NULL,         -- NULL when invalid format
    Address             NVARCHAR(55)  NULL,
    City                NVARCHAR(43)  NULL,         -- customers.clity
    ZipCode             VARCHAR(10)   NULL,         -- "NNNN-NNN" (PT) or foreign postal code
    ZipLocality         NVARCHAR(40)  NULL,         -- text after the zip code
    Country             NVARCHAR(30)  NULL,         -- derived: Portugal / Espanha (from zone)
    ZoneCode            NUMERIC(5,0)  NULL,
    ZoneName            NVARCHAR(50)  NULL,         -- zones.zone (Norte, Centro, Sul, Ilhas, Espanha)
    CustomerType        NVARCHAR(20)  NOT NULL,     -- Cliente Final, Revendedor, Funcionário, Interno
    Segment             NVARCHAR(25)  NOT NULL,     -- Alto, Médio, Baixo
    SellerCode          NUMERIC(4,0)  NULL,
    DaysToPay           NUMERIC(3,0)  NULL,
    BBAN                VARCHAR(28)   NULL,
    CreatedAt           DATETIME2(0)  NOT NULL,     -- create_date + create_time
    UpdatedAt           DATETIME2(0)  NOT NULL,     -- last_update_date + last_update_time
    RunID               INT           NULL,
    CONSTRAINT PK_stg_Customers PRIMARY KEY (CustomerID)
);
GO

/* ---- Invoices (header) ------------------------------------------------ */
CREATE TABLE dbo.stg_Invoices (
    InvoiceID           VARCHAR(25)    NOT NULL,    -- invoices.invoice_stamp_id (trimmed)
    InvoiceDate         DATE           NOT NULL,
    CustomerID          NUMERIC(10,0)  NOT NULL,    -- source customer id
    SurvivorCustomerID  NUMERIC(10,0)  NULL,        -- after de-duplication
    EmployeeID          NUMERIC(6,0)   NOT NULL,
    PaymentDate         DATE           NULL,
    CurrencySource      VARCHAR(11)    NOT NULL,    -- as in source (e.g. 'EURO')
    CurrencyCode        CHAR(3)        NOT NULL,    -- ISO code (EUR, GBP, ...)
    ExchangeRateToEUR   DECIMAL(19,10) NOT NULL,
    ProductsTotal       DECIMAL(19,6)  NOT NULL,    -- original currency (header value)
    ShippingCost        DECIMAL(19,6)  NOT NULL,    -- original currency (after correction rule S1)
    TotalForVAT         DECIMAL(19,6)  NOT NULL,
    VATValue            DECIMAL(19,6)  NOT NULL,
    FinalTotal          DECIMAL(19,6)  NOT NULL,
    SumLinesTotal       DECIMAL(19,6)  NULL,        -- SUM(line_total) - used for allocation
    ShippingCostEUR     DECIMAL(19,6)  NULL,
    QualityFlags        VARCHAR(200)   NULL,        -- auto-corrected issues (audit trail)
    CreatedAt           DATETIME2(0)   NOT NULL,
    UpdatedAt           DATETIME2(0)   NOT NULL,
    RunID               INT            NULL,
    CONSTRAINT PK_stg_Invoices PRIMARY KEY (InvoiceID)
);
GO

/* ---- Invoice lines (grain of the fact table) --------------------------- */
CREATE TABLE dbo.stg_InvoiceLines (
    InvoiceLineID       VARCHAR(25)    NOT NULL,    -- invoices_lines.invoice_line_stamp_id
    InvoiceID           VARCHAR(25)    NOT NULL,
    ProductID           VARCHAR(18)    NOT NULL,    -- products.reference (trimmed)
    Quantity            DECIMAL(14,4)  NOT NULL,    -- ABS() applied (sign errors)
    UnitPrice           DECIMAL(19,6)  NOT NULL,    -- ABS() applied, original currency
    LineTotal           DECIMAL(19,6)  NOT NULL,    -- excl. VAT, original currency
    LineVAT             DECIMAL(19,6)  NOT NULL,
    VATRate             DECIMAL(5,2)   NULL,        -- LineVAT / LineTotal * 100
    ShippingAllocated   DECIMAL(19,6)  NULL,        -- share of invoice shipping (see report)
    -- EUR-standardised measures (amount * ExchangeRateToEUR)
    UnitPriceEUR        DECIMAL(19,6)  NULL,
    LineTotalEUR        DECIMAL(19,6)  NULL,
    LineVATEUR          DECIMAL(19,6)  NULL,
    LineTotalWithVATEUR DECIMAL(19,6)  NULL,
    ShippingAllocatedEUR DECIMAL(19,6) NULL,
    QualityFlags        VARCHAR(200)   NULL,
    CreatedAt           DATETIME2(0)   NOT NULL,
    UpdatedAt           DATETIME2(0)   NOT NULL,
    RunID               INT            NULL,
    CONSTRAINT PK_stg_InvoiceLines PRIMARY KEY (InvoiceLineID)
);
CREATE INDEX IX_stg_InvoiceLines_Invoice ON dbo.stg_InvoiceLines (InvoiceID);
GO

/* ---- Dimension sources used by the fact lookups ------------------------ */
CREATE TABLE dbo.stg_Products (
    ProductID           VARCHAR(18)    NOT NULL CONSTRAINT PK_stg_Products PRIMARY KEY,
    ProductName         NVARCHAR(60)   NOT NULL,
    FamilyCode          VARCHAR(18)    NULL,
    FamilyName          NVARCHAR(60)   NULL,
    FamilyClassification NVARCHAR(20)  NULL,
    CategoryCode        INT            NULL,
    CategoryName        NVARCHAR(35)   NULL,
    SupplierID          NUMERIC(10,0)  NULL,
    Classification      NVARCHAR(20)   NULL,
    CurrentSellPrice    DECIMAL(19,6)  NULL,        -- divided by 1,000,000 (scale error in source)
    LastCostPrice       DECIMAL(19,6)  NULL,        -- divided by 1,000,000
    VATRate             DECIMAL(5,2)   NULL,
    CreatedAt           DATETIME2(0)   NULL,
    UpdatedAt           DATETIME2(0)   NULL,
    RunID               INT            NULL
);
CREATE TABLE dbo.stg_Suppliers (
    SupplierID          NUMERIC(10,0)  NOT NULL CONSTRAINT PK_stg_Suppliers PRIMARY KEY,
    SupplierName        NVARCHAR(55)   NOT NULL,
    TaxNumber           VARCHAR(20)    NULL,
    City                NVARCHAR(43)   NULL,
    ZipCode             VARCHAR(10)    NULL,
    Country             NVARCHAR(30)   NULL,
    ZoneCode            NUMERIC(5,0)   NULL,
    ZoneName            NVARCHAR(50)   NULL,
    SupplierType        NVARCHAR(20)   NULL,
    Nationality         NVARCHAR(20)   NULL,
    CreatedAt           DATETIME2(0)   NULL,
    UpdatedAt           DATETIME2(0)   NULL,
    RunID               INT            NULL
);
CREATE TABLE dbo.stg_Employees (
    EmployeeID          NUMERIC(6,0)   NOT NULL CONSTRAINT PK_stg_Employees PRIMARY KEY,
    EmployeeCode        VARCHAR(20)    NOT NULL,
    EmployeeName        NVARCHAR(30)   NOT NULL,
    EmployeeGroup       NVARCHAR(20)   NULL,
    Department          NVARCHAR(20)   NULL,
    ManagerID           NUMERIC(6,0)   NULL,
    ManagerName         NVARCHAR(30)   NULL,
    Email               VARCHAR(100)   NULL,
    CreatedAt           DATETIME2(0)   NULL,
    UpdatedAt           DATETIME2(0)   NULL,
    RunID               INT            NULL
);
GO

/* =====================================================================
   DATA QUALITY PROBLEM (DQP) TABLES  - persistent, rows are appended
   Convention (lab 4, CardDQP): same columns as the staging table, values
   kept as NVARCHAR, plus the DQP column with the problem description
   ("<code>: <message>", codes listed in the report) and audit columns.
   In SSIS: Conditional Split / Lookup error output -> Derived Column
   "Add <problem> DQP" -> Union All -> OLE DB Destination stg_<Table>DQP.
   ===================================================================== */
CREATE TABLE dbo.stg_CustomersDQP (
    DQPID               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stg_CustomersDQP PRIMARY KEY,
    number              NVARCHAR(20)   NULL,
    name                NVARCHAR(100)  NULL,
    taxpayer_number     NVARCHAR(40)   NULL,
    phone               NVARCHAR(60)   NULL,
    mobile              NVARCHAR(45)   NULL,
    contact             NVARCHAR(60)   NULL,
    email               NVARCHAR(100)  NULL,
    address             NVARCHAR(100)  NULL,
    clity               NVARCHAR(60)   NULL,
    zip_code            NVARCHAR(60)   NULL,
    zone                NVARCHAR(20)   NULL,
    type                NVARCHAR(40)   NULL,
    seller              NVARCHAR(20)   NULL,
    segment             NVARCHAR(40)   NULL,
    create_datetime     NVARCHAR(40)   NULL,
    last_update_datetime NVARCHAR(40)  NULL,
    DQP                 NVARCHAR(200)  NOT NULL,     -- e.g. 'C01: customer name is missing'
    DQPDate             DATETIME       NOT NULL CONSTRAINT DF_stg_CustomersDQP_Date DEFAULT GETDATE(),
    RunID               INT            NULL
);
CREATE TABLE dbo.stg_InvoicesDQP (
    DQPID               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stg_InvoicesDQP PRIMARY KEY,
    invoice_stamp_id    NVARCHAR(40)   NULL,
    invoice_date        NVARCHAR(40)   NULL,
    customer            NVARCHAR(20)   NULL,
    employee            NVARCHAR(20)   NULL,
    payment_date        NVARCHAR(40)   NULL,
    currency            NVARCHAR(20)   NULL,
    products_total      NVARCHAR(40)   NULL,
    shipping_cost       NVARCHAR(40)   NULL,
    total_for_vat       NVARCHAR(40)   NULL,
    vat_value           NVARCHAR(40)   NULL,
    final_total         NVARCHAR(40)   NULL,
    create_datetime     NVARCHAR(40)   NULL,
    last_update_datetime NVARCHAR(40)  NULL,
    DQP                 NVARCHAR(200)  NOT NULL,     -- e.g. 'I03: customer not found'
    DQPDate             DATETIME       NOT NULL CONSTRAINT DF_stg_InvoicesDQP_Date DEFAULT GETDATE(),
    RunID               INT            NULL
);
CREATE TABLE dbo.stg_InvoiceLinesDQP (
    DQPID               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stg_InvoiceLinesDQP PRIMARY KEY,
    invoice_line_stamp_id NVARCHAR(40) NULL,
    invoice_stamp_id    NVARCHAR(40)   NULL,
    product             NVARCHAR(40)   NULL,
    quantity            NVARCHAR(40)   NULL,
    unit_price          NVARCHAR(40)   NULL,
    line_total          NVARCHAR(40)   NULL,
    line_vat            NVARCHAR(40)   NULL,
    create_datetime     NVARCHAR(40)   NULL,
    last_update_datetime NVARCHAR(40)  NULL,
    DQP                 NVARCHAR(200)  NOT NULL,     -- e.g. 'L02: product not found'
    DQPDate             DATETIME       NOT NULL CONSTRAINT DF_stg_InvoiceLinesDQP_Date DEFAULT GETDATE(),
    RunID               INT            NULL
);
CREATE TABLE dbo.stg_ProductsDQP (
    DQPID               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stg_ProductsDQP PRIMARY KEY,
    reference           NVARCHAR(40)   NULL,
    designation         NVARCHAR(100)  NULL,
    family              NVARCHAR(40)   NULL,
    category            NVARCHAR(20)   NULL,
    supplyer            NVARCHAR(20)   NULL,
    current_sell_price  NVARCHAR(40)   NULL,
    vat_rate            NVARCHAR(20)   NULL,
    DQP                 NVARCHAR(200)  NOT NULL,     -- e.g. 'P01: product without designation/family/category'
    DQPDate             DATETIME       NOT NULL CONSTRAINT DF_stg_ProductsDQP_Date DEFAULT GETDATE(),
    RunID               INT            NULL
);
GO
PRINT 'Staging Area created: ' + DB_NAME();
SELECT name AS table_name FROM sys.tables ORDER BY name;
GO
