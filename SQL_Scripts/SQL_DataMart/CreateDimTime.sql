IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = 'DimTime')	
	CREATE TABLE [dbo].[DimTime](
		[TimeKey] [int] IDENTITY(1,1) NOT NULL,
		[FullTime] [time] NOT NULL,
		[FullTime_int] [int] NOT NULL,
		[Hour] [tinyint] NOT NULL,
		[Minute] [tinyint] NOT NULL,
		[Second] [tinyint] NOT NULL,
		[Period] [nvarchar](10) NOT NULL,
		[LunchTime] [nvarchar](3) NOT NULL,
		[DinnerTime] [nvarchar](3) NOT NULL,
	 CONSTRAINT [PK_DimTime] PRIMARY KEY CLUSTERED 
	(
		[TimeKey] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]
