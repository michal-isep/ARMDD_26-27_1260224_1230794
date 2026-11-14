IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'FactSales')	
	CREATE TABLE [dbo].[FactSales](
		[InvoiceID] [int] NOT NULL,
		[InvoiceLineID] [int] NOT NULL,
		[CustomerKey] [int] NOT NULL,
		[ProductKey] [int] NOT NULL,
		[EmployeeKey] [int] NOT NULL,
		[SupplierKey] [int] NOT NULL,
		[DateKey] [int] NOT NULL,
		[TimeKey] [int] NOT NULL,
		[CurrencyKey] [int] NOT NULL,
		[Quantity] [numeric](14,4) NOT NULL,
		[UnitPriceOriginalCurrency] [numeric](19,6) NOT NULL,
		[LineAmountWithoutVATOriginalCurrency] [numeric](19,6) NOT NULL,
		[VATAmountOriginalCurrency] [numeric](19,6) NOT NULL,
		[LineAmountWithVATOriginalCurrency] [numeric](19,6) NOT NULL,
		[ShippingCostAllocatedOriginalCurrency] [numeric](19,6) NOT NULL,
		[UnitPriceStandardCurrency] [numeric](19,6) NOT NULL,
		[LineAmountWithoutVATStandardCurrency] [numeric](19,6) NOT NULL,
		[VATAmountStandardCurrency] [numeric](19,6) NOT NULL,
		[LineAmountWithVATStandardCurrency] [numeric](19,6) NOT NULL,
		[ShippingCostAllocatedStandardCurrency] [numeric](19,6) NOT NULL,
	 CONSTRAINT [PK_FactSales] PRIMARY KEY CLUSTERED 
	(
		[InvoiceID] ASC,
		[InvoiceLineID] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]