IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'DimSupplier')
BEGIN
	CREATE TABLE [dbo].[DimSupplier](
		[SupplierKey] [int] IDENTITY(1,1) NOT NULL,
		[SupplierID] [numeric](10,0) NOT NULL,
		[SupplierName] [varchar](55) NOT NULL,
		[Phone] [varchar](60) NOT NULL,
		[Mobile] [varchar](45) NOT NULL,
		[Email] [varchar](60) NOT NULL,
		[ContactName] [varchar](30) NOT NULL,
		[ContactPosition] [varchar](15) NOT NULL,
		[Address] [varchar](55) NOT NULL,
		[City] [varchar](43) NOT NULL,
		[Zip_code] [varchar](45) NOT NULL,
		[TaxpayerNumber] [varchar](60) NOT NULL,
		[Zone] [varchar](50) NULL,
		[Country] [varchar](100) NOT NULL,
		[Type] [varchar](20) NOT NULL,
		[PaymentTerms] [numeric](3,0) NOT NULL,
		[Nationality] [varchar](20) NOT NULL,
		[EffectiveDate] [datetime] NOT NULL,
		[ExpiredDate] [datetime] NULL,
		[IsCurrent] [nvarchar](3) NOT NULL	
	 CONSTRAINT [PK_DimSupplier] PRIMARY KEY CLUSTERED 
	(
		[SupplierKey] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]

	CREATE NONCLUSTERED INDEX [NonClusteredIndex-DimSupplier] ON [dbo].[DimSupplier]
	(
		[SupplierID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
END