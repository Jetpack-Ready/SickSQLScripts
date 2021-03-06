USE [Salesforce_BI]
GO
/****** Object:  StoredProcedure [dbo].[spUpdateLeadState]    Script Date: 5/2/2016 11:12:58 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[spUpdateLeadState]
as
drop table _LeadState;

declare	@Id nvarchar(18)
	   ,@Address varchar(50)
	   ,@City varchar(50)
	   ,@PostalCode varchar(5) -- This needs to be a varchar because of leading 0s in the postal code
	   ,@State char(2) = '' -- This must be set to '' because if Google can't find a match on zip, it sets state to NULL, which creates infinite loop
	   ,@Status varchar(50)
	   ,@GPSLatitude varchar(50)
	   ,@GPSLongitude varchar(50);




select	Id
	   ,Street
	   ,City
	   ,left(PostalCode, 5) PostalCode
	   ,State
	   ,Latitude__c
	   ,Longitude__c
into	_LeadState
from	SalesForce.dbo.BWDRE_Lead
where	State is null
		and Country = 'US'
		and (Street is not null or PostalCode is not null)
		and CreatedDate > = dateadd(day, -1, getdate())
		and Status in ( 'Active' )
		and isnumeric(left(PostalCode, 5)) = 1
		and DELETEDFLAG = 'false'
		and left(PostalCode, 5) not in ( '11111','00000' );
		



-- Get an updated State code if it is empty.
while exists ( select	Id
					   ,PostalCode
			   from		_LeadState
			   where	State is null
						)
	  begin

			select	@Id = Id
				   ,@Address = Street
				   ,@City = City
				   ,@PostalCode = PostalCode
				   ,@State = State
			from	_LeadState
			where	State is null;
					
			select	@Id Id
				   ,@Address Street
				   ,@City City
				   ,@State State
				   ,@PostalCode PostalCode
				   ,'Input' Input;

			execute spGeocode @Status output, @Address, @City output, @State output, '', @PostalCode, '', @GPSLatitude output,
				@GPSLongitude output;

			select	@Id Id
				   ,@Status Status
				   ,@PostalCode PostalCode
				   ,@City City
				   ,@State State
				   ,@GPSLatitude Lat
				   ,@GPSLongitude Long
				   ,'Output' Output;
		
			
			
			if @Status = 'OVER_QUERY_LIMIT'
			   begin
					 throw 50000, @Status, 1;
					 break;
			   end;
			else
			   begin

					 print @Id;
					 update	_LeadState
					 set	State = isnull(@State, 'X') -- Set State to X so we can continue to loop
					 ,City =@City
						   ,Latitude__c = @GPSLatitude
						   ,Longitude__c = @GPSLongitude
					 where	Id = @Id;
					 waitfor delay '00:00:05';
			   end; 
			

	  end;


select	l.Id
	   ,t.State
	   ,t.Latitude__c
	   ,t.Longitude__c
from	SalesForce.dbo.BWDRE_Lead l
join	_LeadState t
on		t.Id = l.Id
where	t.State is not null and t.State != 'X';


SELECT * FROM dbo.[_LeadState] where state != 'X';
