IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'FactCurrencyRate')	
	CREATE TABLE [dbo].[FactCurrencyRate](
		[DateKey] [int] NOT NULL,
		[SourceCurrencyKey] [int] NOT NULL,
		[DestinationCurrencyKey] [int] NOT NULL,
		[SourceDestinationExchangeRate] [decimal](18,6) NOT NULL,
		[DestinationSourceExchangeRate] [decimal](18,6) NOT NULL,
	 CONSTRAINT [PK_FactCurrencyRate] PRIMARY KEY CLUSTERED 
	(
		[DateKey] ASC,
		[SourceCurrencyKey] ASC,
		[DestinationCurrencyKey] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]