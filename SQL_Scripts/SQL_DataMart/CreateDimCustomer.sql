IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'DimCustomer')
BEGIN
	CREATE TABLE [dbo].[DimCustomer](
		[CustomerKey] [int] IDENTITY(1,1) NOT NULL,
		[CustomerID] [numeric](10,0) NOT NULL,
		[CustomerName] [varchar](55) NOT NULL,
		[TaxNumber] [varchar](20) NOT NULL,
		[Phone] [varchar](60) NOT NULL,
		[Mobile] [varchar](45) NOT NULL,
		[ContactName] [varchar](30) NOT NULL,
		[Email] [varchar](45) NOT NULL,
		[Address] [varchar](55) NOT NULL,
		[City] [varchar](43) NOT NULL,
		[ZipCode] [varchar](45) NOT NULL,
		[Zone] [varchar](50) NOT NULL,
		[Country] [varchar](100) NOT NULL,
		[CustomerType] [varchar](20) NOT NULL,
		[Seller] [numeric](4,0) NOT NULL,
		[PaymentTerms] [numeric](3,0) NOT NULL,
		[Segment] [varchar](25) NOT NULL,
		[EffectiveDate] [datetime] NOT NULL,
		[ExpiredDate] [datetime] NULL,
		[IsCurrent] [nvarchar](3) NOT NULL	
	 CONSTRAINT [PK_DimCustomer] PRIMARY KEY CLUSTERED 
	(
		[CustomerKey] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]

	CREATE NONCLUSTERED INDEX [NonClusteredIndex-DimCustomer] ON [dbo].[DimCustomer]
	(
		[CustomerID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
END