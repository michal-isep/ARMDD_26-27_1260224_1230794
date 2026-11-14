IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'DimCurrency')	
	CREATE TABLE [dbo].[DimCurrency](
		[CurrencyKey] [int] IDENTITY(1,1) NOT NULL,
		[CurrencyCode] [varchar](3) NOT NULL,
		[CurrencyName] [varchar](50) NOT NULL,
		[Symbol] [nvarchar](5) NULL
	 CONSTRAINT [PK_DimCurrency] PRIMARY KEY CLUSTERED 
	(
		[CurrencyKey] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]