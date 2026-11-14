IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'DimProduct')
BEGIN
	CREATE TABLE [dbo].[DimProduct](
		[ProductKey] [int] IDENTITY(1,1) NOT NULL,
		[ProductID] [char](18) NOT NULL,
		[ProductDesignation] [char](60) NULL,
		[CategoryName] [varchar](35) NULL,
		[FamilyReference] [varchar](18) NULL,
		[FamilyName] [varchar](60) NULL,
		[Classification] [varchar](20) NULL,
		[StandardUnitPrice] [numeric](19,6) NULL,
		[VATRate] [numeric](2,0) NULL,
		[EffectiveDate] [datetime] NOT NULL,
		[ExpiredDate] [datetime] NULL,
		[IsCurrent] [nvarchar](3) NOT NULL	
	 CONSTRAINT [PK_DimProduct] PRIMARY KEY CLUSTERED 
	(
		[ProductKey] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]

	CREATE NONCLUSTERED INDEX [NonClusteredIndex-DimProduct] ON [dbo].[DimProduct]
	(
		[ProductID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
END