--ticket 5050
--DECLARE @LowerLimit DATE= '2022-05-16';
--DECLARE @UpperLimit DATE= '2022-05-22';
--DECLARE @ProviderConsultantParam VARCHAR(30)= 'Ondina';


--Gathering Consultant info from Addisons DB (unchanged from previous report)
--DECLARE @tTinConsultantMapping TABLE (TIN VARCHAR(9), Consultant VARCHAR(100), Company VARCHAR(100), NPI VARCHAR(10))
drop table if exists #tTinConsultantMapping  
SELECT DISTINCT TIN, Provider_Consultant as Consultant, Company, NPI 
INTO #tTinConsultantMapping
FROM [temp_Addison].[dbo].[tin_consultant]
WHERE 
	Provider_Consultant in(@ProviderConsultantParam)
	and multi_consultant_tin=0
	AND dataset = (SELECT TOP(1) dataset FROM [temp_Addison].[dbo].[tin_consultant] ORDER BY dataset DESC)
create index TIN_NPI on #tTinConsultantMapping(TIN,NPI)

--Consultants from Addisons database (NPI BASED FOR multi consultant tins)
--DECLARE #tTinNpiConsultantMapping TABLE (TIN VARCHAR(9), Consultant VARCHAR(100), Company VARCHAR(100), NPI VARCHAR(10))
drop table if exists #tTinNpiConsultantMapping  
SELECT DISTINCT TIN, Provider_Consultant as Consultant, Company, NPI 
INTO #tTinNpiConsultantMapping
FROM [temp_Addison].[dbo].[tin_consultant]
WHERE 
	Provider_Consultant in(@ProviderConsultantParam)
	and multi_consultant_tin=1
	AND dataset = (SELECT TOP(1) dataset FROM [temp_Addison].[dbo].[tin_consultant] ORDER BY dataset DESC)
create index TIN_NPI on #tTinNpiConsultantMapping(TIN, NPI)



-----in this section we get the tin npi combinations straddling the end of year 2020---------------------------------------------------------------------------

drop table if exists #Dataset
Select Top(2) Dataset
into #Dataset
From (
Select Distinct Concat([YEAR],[Period]) as Dataset
From _Internal_Reporting.[dbo].[Assignment_NPI_Level_2021Rules]) a
Order By Dataset Desc
--Select * From #Dataset

declare @dataset varchar(10)
set @dataset = (select top(1) Dataset from #Dataset order by dataset desc);

--Select right(@Dataset,2)
drop table if exists #NpiAssignmentStraddlingYear
Create Table #NpiAssignmentStraddlingYear (Beneficiary_ID varchar(10) not null, TIN varchar(11) null, Npi varchar(11) null, [Year] varchar(5) null, [Period] varchar(5) null)

IF right(@dataset,2) = '00'
	Begin
	Insert into #NpiAssignmentStraddlingYear
	Select Beneficiary_ID, TIN, Npi, [Year], [Period]
	FROM (
	Select distinct Beneficiary_ID, TIN, Npi, [Year], [Period]
	From _Internal_Reporting.[dbo].[Assignment_NPI_Level_2021Rules]
	Where Concat([YEAR],[Period]) IN (Select Dataset from #Dataset)) a
	End

Else
	Begin
	Insert into #NpiAssignmentStraddlingYear
	SELECT Beneficiary_ID, TIN, Npi, [Year], [Period]
	FROM (
	Select distinct Beneficiary_ID, TIN, Npi, [Year], [Period]
	From _Internal_Reporting.[dbo].[Assignment_NPI_Level_2021Rules]
	Where Concat([YEAR],[Period]) IN (Select top(1) Dataset from #Dataset order by Dataset desc)) a
	End

create index tin on #NpiAssignmentStraddlingYear (tin, Npi)

--Select * From #NpiAssignmentStraddlingYear

---------------------------------------------------------------------



drop table if exists #pbacoStaffExclusionList
select distinct userId 
into #pbacoStaffExclusionList
from [pbaco-beta.database.windows.net].[Messaging].[dbo].PBACO_Staff

create index userIds on #pbacoStaffExclusionList (userId)

--Active users excluding PBACO Staff
drop table if exists #tUsers
SELECT users.UserId, FirstName as FN, LastName as LN, UserName 
INTO #tUsers 
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].Users users
left join #pbacoStaffExclusionList staff
	on users.UserId = staff.UserId
WHERE 
	staff.userId is null --exclude pbaco staff

--Active doctors excluding PBACO Staff and hospitalists (per David requests, to avoid having duplicated alert/events)
drop table if exists #tNpis
SELECT NpiId, PhysicianUserId as UserId, NpiNum 
INTO #tNpis
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].Npis 
left join #pbacoStaffExclusionList staff
	on PhysicianUserId = staff.UserId
WHERE 
	staff.userId is null --exclude pbaco staff
	and 
	(Active=1 or [isMAProvider]=1)
	--AND PhysicianUserId NOT IN (SELECT * FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].PBACO_Staff) 
	AND PhysicianUserId IN (
							SELECT UserId 
							FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].Users
							WHERE Active=1
							)
	AND LEN(NpiNum)=10 
	AND isNumeric(NpiNum) = 1 and npinum not like '9%' 

--Active Subscriptions
DECLARE @tNpiSubs TABLE (NpiId uniqueidentifier, UserId uniqueidentifier, PRIMARY KEY (NpiId, UserId))
INSERT INTO @tNpiSubs 
SELECT DISTINCT npiSubs.NpiId, npiSubs.UserId 
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].NpiSubscriptions  npiSubs
left join #pbacoStaffExclusionList staff
	on npiSubs.UserId = staff.UserId
WHERE 
	staff.userId is null --exclude pbaco staff
--WHERE /*Active = 1 AND */
	--UserID NOT IN (SELECT * FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].PBACO_Staff)

--Active doctors with active users subscribed excluding PBACO_Staff
DECLARE @tDocSubInfo TABLE (NpiId uniqueidentifier, UserId uniqueidentifier, IsDoctor BIT, FN VARCHAR(100), LN VARCHAR(100), Username VARCHAR(100), PRIMARY KEY (NpiId, UserId))
INSERT INTO @tDocSubInfo 
SELECT npis.NpiId, subs.UserId, 
	CASE WHEN npis.UserId = subs.UserId THEN 1 ELSE 0 END, users.FN, users.LN, users.UserName
FROM #tNpis npis
LEFT JOIN @tNpiSubs subs ON npis.NpiId = subs.NpiId
INNER JOIN #tUsers users 
	ON subs.UserId = users.UserId

--0 seconds

--Gathering alert info (Database in UTC, needs conversion to EST) -- Adding 1 day offset to the between to prevent alerts for the closing day to not be displayed
DECLARE @tAlerts TABLE (AlertId uniqueidentifier primary key, NpiId uniqueidentifier, BenId VARCHAR(50), DateReceived DATETIME)
INSERT INTO @tAlerts 
SELECT AlertId, NpiId, BenId, [CreatedDate] AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time' 
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].Alerts 
WHERE Active = 1 
	AND Convert(DATETIME, [CreatedDate] AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time') BETWEEN @LowerLimit AND DATEADD(day,1,@UpperLimit) 
	AND BenId NOT IN (SELECT BenId FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].PatientExclusions WHERE BenId IS NOT NULL)

--16 seconds all above

--BENS WITH ALERTS
DECLARE @tBeneficiaries TABLE (BenId uniqueidentifier primary key, Payor VARCHAR(50), BeneficiaryId VARCHAR(30))
INSERT INTO @tBeneficiaries 
SELECT BenId, Payor, BeneficiaryId 
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].Beneficiaries 
WHERE BenId IN (SELECT BenId FROM @tAlerts WHERE BenID IS NOT NULL)

--All alert actions performed on those alerts
DECLARE @tAllAlertActions TABLE (AlertActionId uniqueidentifier primary key, AAId uniqueidentifier, AlertId uniqueidentifier, UserId uniqueidentifier, CreatedDate DATETIME)
INSERT INTO @tAllAlertActions 
SELECT AlertActionLogId, AlertActionId, logs.AlertId, logs.UserId, CreatedDate AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time' 
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].AlertActionLogs logs
inner join @tAlerts alerts--filter results
	on logs.AlertId = alerts.AlertId
left join #pbacoStaffExclusionList staff
	on logs.UserId = staff.UserId
inner join #tUsers users
	on users.UserId = logs.UserId
WHERE 
	staff.userId is null --exclude pbaco staff
	--AlertId IN (SELECT AlertId FROM @tAlerts) AND
	-- UserId NOT IN (SELECT * FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].PBACO_Staff)	
	AND Active=1

--All alert actions excluding No ActionTaken
drop table if exists #tAlertActions
--DECLARE @tAlertActions TABLE (AlertActionId uniqueidentifier primary key, AAId uniqueidentifier, AlertId uniqueidentifier, UserId uniqueidentifier, CreatedDate DATETIME)
--INSERT INTO @tAlertActions 
SELECT AlertActionLogId, AlertActionId, logs.AlertId, logs.UserId, 
	CreatedDate AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time' as CreatedDate
into #tAlertActions
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].AlertActionLogs logs
inner join @tAlerts alerts
	on logs.AlertId = alerts.AlertId
left join #pbacoStaffExclusionList staff
	on logs.UserId = staff.UserId
inner join #tUsers users
	on users.UserId = logs.UserId
WHERE 
	staff.userId is null --exclude pbaco staff
	 --AlertId IN (SELECT AlertId FROM @tAlerts) AND
	 --UserId NOT IN (SELECT * FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].PBACO_Staff) 
	AND AlertActionId NOT IN (SELECT AlertActionId FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].AlertActions WHERE [Text] LIKE 'No Action Taken') 
	AND Active=1

create index alertid on #tAlertActions ( AlertId )

DECLARE @tPatientNpiExclusionBasedOnNoActionTaken TABLE (NpiId uniqueidentifier, BenId uniqueidentifier)
INSERT INTO @tPatientNpiExclusionBasedOnNoActionTaken
SELECT NpiId, BenId
FROM
(
	SELECT a.NpiId, a.BenId, 
		CASE WHEN TotalActionsPerPatient IS NULL THEN 0 ELSE TotalActionsPerPatient END AS TotalActionsPerPatient, 
		CASE WHEN TotalNoActionTakenActions IS NULL THEN 0 ELSE TotalNoActionTakenActions END AS TotalNoActionTakenActions
	FROM
	(
		--All actions made on each Npi, BenId combination
		SELECT COUNT(*) AS TotalActionsPerPatient, BenId, NpiId
		FROM
		(
			SELECT BenId, NpiId, b.AlertId
			FROM @tAlerts a LEFT JOIN @tAllAlertActions b ON a.AlertId = b.AlertId
			--ORDER BY BenId DESC
		)a
		GROUP BY
			BenID, NpiId	
	)a
	LEFT JOIN
	(
		--All No Action Taken actions made on each Npi, BenId combination (the No Action Taken must be performed within the first 3bd of receiving the alert)
		--see here for most recent 3 business days logic: Y:\Dev_Team\SuperDoc App\Alert_Delay\3 business days
		SELECT CASE WHEN COUNT(*) IS NULL THEN 0 ELSE COUNT(*) END AS TotalNoActionTakenActions, BenId, NpiId
		FROM
		(
			SELECT BenId, NpiId, b.AlertId
			FROM 
				@tAlerts a 
				INNER JOIN (SELECT * FROM @tAllAlertActions WHERE AAId IN (SELECT AlertActionId FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].AlertActions WHERE [Text] LIKE 'No Action Taken'))b ON a.AlertId = b.AlertId
			WHERE
				DATEDIFF(minute, a.DateReceived, b.CreatedDate) <= 60*24
				OR
				(
					DATEDIFF(minute, a.DateReceived, b.CreatedDate) <= 60*24*5 AND
					(
						(DATENAME(weekday,a.DateReceived)='Monday' AND (DATENAME(weekday,b.CreatedDate)='Tuesday' OR DATENAME(weekday,b.CreatedDate)='Wednesday' OR DATENAME(weekday,b.CreatedDate)='Thursday'))
						OR (DATENAME(weekday,a.DateReceived)='Tuesday' AND (DATENAME(weekday,b.CreatedDate)='Wednesday' OR DATENAME(weekday,b.CreatedDate)='Thursday' OR DATENAME(weekday,b.CreatedDate)='Friday'))
						OR (DATENAME(weekday,a.DateReceived)='Wednesday' AND (DATENAME(weekday,b.CreatedDate)='Thursday' OR DATENAME(weekday,b.CreatedDate)='Friday' OR DATENAME(weekday,b.CreatedDate)='Saturday' OR DATENAME(weekday,b.CreatedDate)='Sunday' OR DATENAME(weekday,b.CreatedDate)='Monday'))
						OR (DATENAME(weekday,a.DateReceived)='Thursday' AND (DATENAME(weekday,b.CreatedDate)='Friday' OR DATENAME(weekday,b.CreatedDate)='Saturday' OR DATENAME(weekday,b.CreatedDate)='Sunday' OR DATENAME(weekday,b.CreatedDate)='Monday' OR DATENAME(weekday,b.CreatedDate)='Tuesday'))
						OR (DATENAME(weekday,a.DateReceived)='Friday' AND (DATENAME(weekday,b.CreatedDate)='Saturday' OR DATENAME(weekday,b.CreatedDate)='Sunday' OR DATENAME(weekday,b.CreatedDate)='Monday' OR DATENAME(weekday,b.CreatedDate)='Tuesday' OR DATENAME(weekday,b.CreatedDate)='Wednesday'))
						OR (DATENAME(weekday,a.DateReceived)='Saturday' AND (DATENAME(weekday,b.CreatedDate)='Sunday' OR DATENAME(weekday,b.CreatedDate)='Monday' OR DATENAME(weekday,b.CreatedDate)='Tuesday' OR DATENAME(weekday,b.CreatedDate)='Wednesday'))
						OR (DATENAME(weekday,a.DateReceived)='Sunday' AND (DATENAME(weekday,b.CreatedDate)='Monday' OR DATENAME(weekday,b.CreatedDate)='Tuesday' OR DATENAME(weekday,b.CreatedDate)='Wednesday'))
					)
				)
			--ORDER BY BenId DESC
		)a
		GROUP BY
			BenID, NpiId
	)b ON a.BenId=b.BenId AND a.NpiId=b.NpiId
)a
WHERE
	TotalActionsPerPatient=TotalNoActionTakenActions

DECLARE @tAlertsExcludingNoActions TABLE (AlertId uniqueidentifier primary key, NpiId uniqueidentifier, BenId VARCHAR(50), DateReceived DATETIME)
INSERT INTO @tAlertsExcludingNoActions
SELECT a.*
FROM  @tAlerts a
LEFT JOIN @tPatientNpiExclusionBasedOnNoActionTaken b 
	ON a.BenId=b.BenId AND a.NpiId=b.NpiId
WHERE 
	b.NpiId IS NULL

--46 seconds later

--All alert reads on those alerts
drop table if exists #tAlertReads
--DECLARE @tAlertReads TABLE (AlertId uniqueidentifier, UserId uniqueidentifier, ViewedDate DATETIME)
--INSERT INTO @tAlertReads 
SELECT alerts.AlertId, alerts.UserId, alerts.ViewedDate 
into #tAlertReads
FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].UserAlerts  alerts
inner join @tAlertsExcludingNoActions excludeNoActions
	on alerts.AlertId = excludeNoActions.AlertId
left join #pbacoStaffExclusionList staff
	on alerts.UserId = staff.UserId
WHERE 
	staff.userId is null --exclude pbaco staff
	 --AlertId IN (SELECT AlertId FROM @tAlertsExcludingNoActions)  AND
	 and ViewedDate IS NOT NULL 
	 --AND UserId NOT IN (SELECT UserId FROM [pbaco-beta.database.windows.net].[Messaging].[dbo].PBACO_Staff)

CREATE INDEX alertId ON #tAlertReads (AlertId) 

--48 seconds later

--Readings by user
DECLARE @tReadingsByUser TABLE (ReadNumber int, AlertId uniqueidentifier, NpiId uniqueidentifier, BenId uniqueidentifier, UserId uniqueidentifier, DateReceived DateTime, DateRead DateTime)
INSERT INTO @tReadingsByUser 
SELECT 
	ROW_NUMBER() OVER(PARTITION BY a.AlertId, UserId ORDER BY ViewedDate ASC) AS ReadNumber, 
	a.AlertId, NpiId, BenId, UserId, DateReceived, ViewedDate
FROM @tAlertsExcludingNoActions A
INNER JOIN #tAlertReads aa 
	ON A.AlertId = aa.AlertId

--Actions excluding No Action Taken
DECLARE @tActionsByUser TABLE (ActionNumber int, AlertId uniqueidentifier, NpiId uniqueidentifier, BenId uniqueidentifier, UserId uniqueidentifier, DateReceived DateTime, DateAction DateTime)
INSERT INTO @tActionsByUser 
SELECT 
	ROW_NUMBER() OVER(PARTITION BY ale.AlertId, UserId ORDER BY CreatedDate ASC) AS ActionNumber, 
	ale.AlertId, NpiId, BenId, UserId, DateReceived, CreatedDate
FROM @tAlertsExcludingNoActions ale
INNER JOIN #tAlertActions aa 
	ON ale.AlertId = aa.AlertId


drop table if exists #RecievedAlertsAndPatientsCounts	
select 'RecievedAlertsAndPatientsCounts' as logs,a.npiId, 
	count(distinct AlertId) as AlertsReceived,
	count(distinct BenId) as PatientsReceived
into #RecievedAlertsAndPatientsCounts
from @tAlertsExcludingNoActions a
group by a.NpiId

--Number of alerts read per doctor
drop table if exists #ReadAlertsAndPatientsCounts
select '#ReadAlertsAndPatientsCounts' as logs, a.NpiId, 
	count( DISTINCT A.AlertId) AS AlertsRead,
	COUNT(distinct BenId) AS PatientsRead
into #ReadAlertsAndPatientsCounts
FROM  @tAlertsExcludingNoActions a
INNER JOIN #tAlertReads b 
	ON a.AlertId = b.AlertId
GROUP BY a.NpiId




--Number of alerts not read per doctor


drop table if exists #NotReadAlertsAndPatients
select a.NpiId,
	COUNT(distinct a.AlertId) as AlertsNotRead,
	COUNT( distinct a.BenId) as PatientsNotRead
into #NotReadAlertsAndPatients
FROM @tAlertsExcludingNoActions a
LEFT JOIN  @tAlertsExcludingNoActions  readAlerts
	ON a.AlertId = readAlerts.AlertId
WHERE
	readAlerts.BenId IS NULL
GROUP BY
	a.NpiId









DECLARE @tAlertsWActionsPerDoc TABLE (NpiId uniqueidentifier primary key, AlertsWActions int)
INSERT INTO @tAlertsWActionsPerDoc 
SELECT NpiId, COUNT(distinct a.AlertId) AS AlertsWActions
FROM @tAlertsExcludingNoActions a
inner JOIN #tAlertActions b 
	ON a.AlertId = b.AlertId
GROUP BY NpiId


drop table if exists #notActedAlertsAndPatients
SELECT NpiId, 
	COUNT(distinct a.AlertId) AS AlertsWNoActions,
	COUNT(distinct a.BenId) as PatientsWNoActions
into #notActedAlertsAndPatients
FROM @tAlertsExcludingNoActions a
LEFT JOIN #tAlertActions b 
	ON a.AlertId = b.AlertId
WHERE b.AlertId IS NULL
GROUP BY NpiId



--Patients with actions per doctor
DECLARE @tPatientsWActionsPerDoc TABLE (NpiId uniqueidentifier primary key, PatientsWActions int)
INSERT INTO @tPatientsWActionsPerDoc SELECT NpiId, COUNT(distinct BenId) AS PatientsWActions
FROM @tAlertsExcludingNoActions a
LEFT JOIN #tAlertActions b 
	ON a.AlertId = b.AlertId
WHERE b.AlertId IS NOT NULL

GROUP BY NpiId



--READINGS CLASSIFICATION: Assigning each alert/user combination to a response group
DECLARE @tAlertReadingTimings TABLE (AlertId uniqueidentifier, NpiId uniqueidentifier, UserId uniqueidentifier, IsDoctor BIT, DateReceived DATETIME, DateAction DATETIME, HoursLapsed INT, Less24 bit, OneToThreeBD INT, MoreThreeBD INT)
INSERT INTO @tAlertReadingTimings 
SELECT *, CASE WHEN Less24 = 0 AND OneToThreeBD = 0 THEN 1 ELSE 0 END AS MoreThreeBD
FROM
(
	SELECT *,
		CASE
			WHEN Less24=1 THEN 0
			ELSE
				CASE 
					WHEN
						DATEDIFF(minute, DateReceived, DateRead) <= 60*24*5 AND
		--see here for most recent 3 business days logic: Y:\Dev_Team\SuperDoc App\Alert_Delay\3 business days
						(
							(DATENAME(weekday,DateReceived)='Monday' AND (DATENAME(weekday,DateRead)='Tuesday' OR DATENAME(weekday,DateRead)='Wednesday' OR DATENAME(weekday,DateRead)='Thursday'))
							OR (DATENAME(weekday,DateReceived)='Tuesday' AND (DATENAME(weekday,DateRead)='Wednesday' OR DATENAME(weekday,DateRead)='Thursday' OR DATENAME(weekday,DateRead)='Friday'))
							OR (DATENAME(weekday,DateReceived)='Wednesday' AND (DATENAME(weekday,DateRead)='Thursday' OR DATENAME(weekday,DateRead)='Friday' OR DATENAME(weekday,DateRead)='Saturday' OR DATENAME(weekday,DateRead)='Sunday' OR DATENAME(weekday,DateRead)='Monday'))
							OR (DATENAME(weekday,DateReceived)='Thursday' AND (DATENAME(weekday,DateRead)='Friday' OR DATENAME(weekday,DateRead)='Saturday' OR DATENAME(weekday,DateRead)='Sunday' OR DATENAME(weekday,DateRead)='Monday' OR DATENAME(weekday,DateRead)='Tuesday'))
							OR (DATENAME(weekday,DateReceived)='Friday' AND (DATENAME(weekday,DateRead)='Saturday' OR DATENAME(weekday,DateRead)='Sunday' OR DATENAME(weekday,DateRead)='Monday' OR DATENAME(weekday,DateRead)='Tuesday' OR DATENAME(weekday,DateRead)='Wednesday'))
							OR (DATENAME(weekday,DateReceived)='Saturday' AND (DATENAME(weekday,DateRead)='Sunday' OR DATENAME(weekday,DateRead)='Monday' OR DATENAME(weekday,DateRead)='Tuesday' OR DATENAME(weekday,DateRead)='Wednesday'))
							OR (DATENAME(weekday,DateReceived)='Sunday' AND (DATENAME(weekday,DateRead)='Monday' OR DATENAME(weekday,DateRead)='Tuesday' OR DATENAME(weekday,DateRead)='Wednesday'))
						)
					THEN 1
					ELSE 0
				END
			END AS OneToThreeBD
	FROM
	(
		SELECT b.AlertId, b.NpiId, a.UserId, a.IsDoctor, b.DateReceived, b.DateRead,
			DATEDIFF(hour, DateReceived, DateRead) AS HoursLapsed,
			CASE 
				WHEN DATENAME(weekday,DateReceived) = 'Monday' OR DATENAME(weekday,DateReceived) = 'Tuesday' OR DATENAME(weekday,DateReceived) = 'Wednesday' OR DATENAME(weekday,DateReceived) = 'Thursday' THEN
					CASE
						WHEN DATEDIFF(minute,DateReceived,DateRead) <= 60*24*1 THEN 1
						ELSE 0
					END
				--Friday and Weekends, alert replied before 72h and before monday
				WHEN DATENAME(weekday,DateReceived) = 'Friday' OR DATENAME(weekday,DateReceived) = 'Saturday' OR DATENAME(weekday,DateReceived) = 'Sunday' THEN
					CASE
						WHEN (DATENAME(weekday,DateRead) = 'Friday' OR DATENAME(weekday,DateRead) = 'Saturday' OR DATENAME(weekday,DateRead) = 'Sunday' OR DATENAME(weekday,DateRead) = 'Monday') AND DATEDIFF(minute,DateReceived,DateRead) <= 60*24*3 THEN 1
						ELSE 0
					END
			END AS Less24
		FROM 
			@tDocSubInfo a --this table contains the info of the users subscribed to the doctors
			INNER JOIN (SELECT * FROM @tReadingsByUser WHERE ReadNumber=1) b ON a.UserId=b.UserId AND a.NpiId=b.NpiId --this table contains the info of the first read performed by each user on each alert
	)a
)a

DECLARE @tAlertReadingsCategorized TABLE (AlertId uniqueidentifier, NpiId uniqueidentifier, UserId uniqueidentifier, IsDoctor bit, Less24 bit, OneToThreeBD bit, MoreThreeBD bit)
INSERT INTO @tAlertReadingsCategorized SELECT AlertId, NpiId, UserId, IsDoctor, Less24, OneToThreeBD, MoreThreeBD
FROM
(
	--Priority on the rownumber: Acted withing 24h > Acted 1-3BD > Rest
	SELECT AlertId, NpiId, UserId, IsDoctor, DateReceived, DateAction, HoursLapsed, Less24, OneToThreeBD, MoreThreeBD, ROW_NUMBER() OVER(PARTITION BY AlertId ORDER BY Less24 DESC, OneToThreeBD DESC, MoreThreeBD DESC) AS RowNum
	FROM @tAlertReadingTimings
)a
WHERE RowNum=1

DECLARE @tPatientReadingsCategorized TABLE (BenId uniqueidentifier, NpiId uniqueidentifier, UserId uniqueidentifier, IsDoctor bit, Less24 bit, OneToThreeBD bit, MoreThreeBD bit)
INSERT INTO @tPatientReadingsCategorized SELECT BenId, NpiId, UserId, IsDoctor, Less24, OneToThreeBD, MoreThreeBD
FROM
(
	SELECT BenId, NpiId, UserId, IsDoctor, DateReceived, DateAction, HoursLapsed, Less24, OneToThreeBD, MoreThreeBD, ROW_NUMBER() OVER(PARTITION BY BenId, NpiId ORDER BY Less24 DESC, OneToThreeBD DESC, MoreThreeBD DESC) AS RowNum
	FROM
	(
		SELECT a.*,b.BenId
		FROM 
			@tAlertReadingTimings a
			LEFT JOIN @tAlertsExcludingNoActions b ON a.AlertId=b.AlertId
	)a
)a
WHERE RowNum=1

--ACTION CLASSIFICATION: Assigning each alert/user combination to a response group
DECLARE @tAlertActionTimings TABLE (AlertId uniqueidentifier, NpiId uniqueidentifier, UserId uniqueidentifier, IsDoctor BIT, DateReceived DATETIME, DateAction DATETIME, HoursLapsed INT, Less24 bit, OneToThreeBD INT, MoreThreeBD INT)
INSERT INTO @tAlertActionTimings 
SELECT *, CASE WHEN Less24 = 0 AND OneToThreeBD = 0 THEN 1 ELSE 0 END AS MoreThreeBD
FROM
(
	SELECT *,
		CASE
			WHEN Less24=1 THEN 0
			ELSE
				CASE 
					WHEN
						DATEDIFF(minute, DateReceived, DateAction) <= 60*24*5 AND
		--see here for most recent 3 business days logic: Y:\Dev_Team\SuperDoc App\Alert_Delay\3 business days
						(
							(DATENAME(weekday,DateReceived)='Monday' AND (DATENAME(weekday,DateAction)='Tuesday' OR DATENAME(weekday,DateAction)='Wednesday' OR DATENAME(weekday,DateAction)='Thursday'))
							OR (DATENAME(weekday,DateReceived)='Tuesday' AND (DATENAME(weekday,DateAction)='Wednesday' OR DATENAME(weekday,DateAction)='Thursday' OR DATENAME(weekday,DateAction)='Friday'))
							OR (DATENAME(weekday,DateReceived)='Wednesday' AND (DATENAME(weekday,DateAction)='Thursday' OR DATENAME(weekday,DateAction)='Friday' OR DATENAME(weekday,DateAction)='Saturday' OR DATENAME(weekday,DateAction)='Sunday' OR DATENAME(weekday,DateAction)='Monday'))
							OR (DATENAME(weekday,DateReceived)='Thursday' AND (DATENAME(weekday,DateAction)='Friday' OR DATENAME(weekday,DateAction)='Saturday' OR DATENAME(weekday,DateAction)='Sunday' OR DATENAME(weekday,DateAction)='Monday' OR DATENAME(weekday,DateAction)='Tuesday'))
							OR (DATENAME(weekday,DateReceived)='Friday' AND (DATENAME(weekday,DateAction)='Saturday' OR DATENAME(weekday,DateAction)='Sunday' OR DATENAME(weekday,DateAction)='Monday' OR DATENAME(weekday,DateAction)='Tuesday' OR DATENAME(weekday,DateAction)='Wednesday'))
							OR (DATENAME(weekday,DateReceived)='Saturday' AND (DATENAME(weekday,DateAction)='Sunday' OR DATENAME(weekday,DateAction)='Monday' OR DATENAME(weekday,DateAction)='Tuesday' OR DATENAME(weekday,DateAction)='Wednesday'))
							OR (DATENAME(weekday,DateReceived)='Sunday' AND (DATENAME(weekday,DateAction)='Monday' OR DATENAME(weekday,DateAction)='Tuesday' OR DATENAME(weekday,DateAction)='Wednesday'))
						)
					THEN 1
					ELSE 0
				END
			END AS OneToThreeBD
	FROM
	(
		SELECT b.AlertId, b.NpiId, a.UserId, a.IsDoctor, b.DateReceived, b.DateAction,
			DATEDIFF(hour, DateReceived, DateAction) AS HoursLapsed,
			CASE 
				WHEN DATENAME(weekday,DateReceived) = 'Monday' OR DATENAME(weekday,DateReceived) = 'Tuesday' OR DATENAME(weekday,DateReceived) = 'Wednesday' OR DATENAME(weekday,DateReceived) = 'Thursday' THEN
					CASE
						WHEN DATEDIFF(minute,DateReceived,DateAction) <= 60*24*1 THEN 1
						ELSE 0
					END
				--Friday and Weekends, alert replied before 72h and before monday
				WHEN DATENAME(weekday,DateReceived) = 'Friday' OR DATENAME(weekday,DateReceived) = 'Saturday' OR DATENAME(weekday,DateReceived) = 'Sunday' THEN
					CASE
						WHEN (DATENAME(weekday,DateAction) = 'Friday' OR DATENAME(weekday,DateAction) = 'Saturday' OR DATENAME(weekday,DateAction) = 'Sunday' OR DATENAME(weekday,DateAction) = 'Monday') AND DATEDIFF(minute,DateReceived,DateAction) <= 60*24*3 THEN 1
						ELSE 0
					END
			END AS Less24
		FROM 
			@tDocSubInfo a --this table contains the info of the users subscribed to the doctors
			INNER JOIN (SELECT * FROM @tActionsByUser WHERE ActionNumber=1) b ON a.UserId=b.UserId AND a.NpiId=b.NpiId --this table contains the info of the first action performed by each user on each alert
	)a
)a


DECLARE @tAlertActionsCategorized TABLE (AlertId uniqueidentifier, NpiId uniqueidentifier, UserId uniqueidentifier, IsDoctor bit, Less24 bit, OneToThreeBD bit, MoreThreeBD bit)
INSERT INTO @tAlertActionsCategorized SELECT AlertId, NpiId, UserId, IsDoctor, Less24, OneToThreeBD, MoreThreeBD
FROM
(
	--Priority on the rownumber: Acted withing 24h > Acted 1-3BD > Rest
	SELECT AlertId, NpiId, UserId, IsDoctor, DateReceived, DateAction, HoursLapsed, Less24, OneToThreeBD, MoreThreeBD, ROW_NUMBER() OVER(PARTITION BY AlertId ORDER BY Less24 DESC, OneToThreeBD DESC, MoreThreeBD DESC) AS RowNum
	FROM @tAlertActionTimings
)a
WHERE RowNum=1

DECLARE @tPatientActionsCategorized TABLE (BenId uniqueidentifier, NpiId uniqueidentifier, UserId uniqueidentifier, IsDoctor bit, Less24 bit, OneToThreeBD bit, MoreThreeBD bit)
INSERT INTO @tPatientActionsCategorized SELECT BenId, NpiId, UserId, IsDoctor, Less24, OneToThreeBD, MoreThreeBD
FROM
(
	SELECT BenId, NpiId, UserId, IsDoctor, DateReceived, DateAction, HoursLapsed, Less24, OneToThreeBD, MoreThreeBD, ROW_NUMBER() OVER(PARTITION BY BenId, NpiId ORDER BY Less24 DESC, OneToThreeBD DESC, MoreThreeBD DESC) AS RowNum
	FROM
	(
		SELECT a.*,b.BenId
		FROM 
			@tAlertActionTimings a
			LEFT JOIN @tAlertsExcludingNoActions b ON a.AlertId=b.AlertId
	)a
)a
WHERE RowNum=1




--GATHERING STATISTICS

--READING  STATISTICS
drop table if exists #AlertReadInXDays
select NpiId, 
		sum(case when Less24 = 1 then 1 else 0 end) as AlertsReadLess24,
		sum(case when OneToThreeBD = 1 then 1 else 0 end) as AlertsReadOneToThreeBD,
		sum(case when MoreThreeBD = 1 then 1 else 0 end) as AlertsReadMoreThreeBD
into #AlertReadInXDays
from @tAlertReadingsCategorized
group by NpiId



drop table if exists #PatientReadInXDays
select NpiId, 
		sum(case when Less24 = 1 then 1 else 0 end) as PatientsReadLess24,
		sum(case when OneToThreeBD = 1 then 1 else 0 end) as PatientsReadOneToThreeBD,
		sum(case when MoreThreeBD = 1 then 1 else 0 end) as PatientsReadMoreThreeBD
into #PatientReadInXDays
from @tPatientReadingsCategorized
GROUP BY NpiId


--ACTIONS STATISTICS
--Alerts Actions in Less24

drop table if exists #alertActionInXDays
select NpiId,
	sum(case when Less24 = 1 then 1 else 0 end) as AlertsActionsLess24,
	sum(case when OneToThreeBD = 1 then 1 else 0 end) as AlertsActionsOneToThreeBD,
	sum(case when MoreThreeBD = 1 then 1 else 0 end) as AlertsActionsMoreThreeBD
into #alertActionInXDays
from @tAlertActionsCategorized
where AlertId is not null
group by NpiId

--Patients Actions in Less24

drop table if exists #patientActedXDays
select NpiId,
	sum( case when Less24 = 1 then 1 else 0 end) as PatientsActionsLess24,
	sum( case when OneToThreeBD = 1 then 1 else 0 end) as PatientsActionsOneToThreeBD,
	sum( case when MoreThreeBD = 1 then 1 else 0 end) as PatientsActionsMoreThreeBD
into #patientActedXDays
FROM @tPatientActionsCategorized
GROUP BY NpiId



drop table if exists #tAlertStatistics
--INSERT INTO @tAlertStatistics 
	SELECT DISTINCT
		zz.UserId,
		a.NpiId,
		a.NpiNum,
		zz.UserName,
		LN + ', ' + FN AS [Provider],
		coalesce(AlertActedXdays.AlertsActionsLess24 ,0) as AlertsActionsLess24,--CASE WHEN e.AlertsActionsLess24 IS NULL THEN 0 ELSE e.AlertsActionsLess24 END AS AlertsActionsLess24,
		coalesce(AlertActedXdays.AlertsActionsOneToThreeBD ,0) as AlertsActionsOneToThreeBD,--CASE WHEN f.AlertsActionsOneToThreeBD IS NULL THEN 0 ELSE f.AlertsActionsOneToThreeBD END AS AlertsActionsOneToThreeBD,
		coalesce(AlertActedXdays.AlertsActionsMoreThreeBD ,0) as AlertsActionsMoreThreeBD,--CASE WHEN g.AlertsActionsMoreThreeBD IS NULL THEN 0 ELSE g.AlertsActionsMoreThreeBD END AS AlertsActionsMoreThreeBD,
		
		
		--yellow section
		coalesce( recieved.PatientsReceived ,0) as PatientsReceived,--CASE WHEN bb.PatientsReceived IS NULL THEN 0 ELSE bb.PatientsReceived END AS PatientsReceived, 
		coalesce(PatActedXDays.PatientsActionsLess24,0) as PatientsActionsLess24,--CASE WHEN ee.PatientsActionsLess24 IS NULL THEN 0 ELSE ee.PatientsActionsLess24 END AS PatientsActionsLess24,
		coalesce(PatientDelay.PatientsReadLess24,0) as PatientsReadLess24,--CASE WHEN jj.PatientsReadLess24 IS NULL THEN 0 ELSE jj.PatientsReadLess24 END AS PatientsReadLess24,
		coalesce(PatientDelay.PatientsReadOneToThreeBD,0) as PatientsReadOneToThreeBD,--CASE WHEN kk.PatientsReadOneToThreeBD IS NULL THEN 0 ELSE kk.PatientsReadOneToThreeBD END AS PatientsReadOneToThreeBD,
		coalesce(PatientDelay.PatientsReadMoreThreeBD,0) as PatientsReadMoreThreeBD,--CASE WHEN ll.PatientsReadMoreThreeBD IS NULL THEN 0 ELSE ll.PatientsReadMoreThreeBD END AS PatientsReadMoreThreeBD
		coalesce(readed.PatientsRead,0) as PatientsRead,--CASE WHEN hh.PatientsRead IS NULL THEN 0 ELSE hh.PatientsRead END AS PatientsRead,
		coalesce(unread.PatientsNotRead,0) as PatientsNotRead,--CASE WHEN ii.PatientsNotRead IS NULL THEN 0 ELSE ii.PatientsNotRead END AS PatientsNotRead,
		
		--blue section
		coalesce(recieved.AlertsReceived, 0) as AlertsReceived,--CASE WHEN b.AlertsReceived IS NULL THEN 0 ELSE b.AlertsReceived END AS AlertsReceived, 
		coalesce(readed.AlertsRead ,0) as AlertsRead,--CASE WHEN h.AlertsRead IS NULL THEN 0 ELSE h.AlertsRead END AS AlertsRead,
		coalesce( unread.AlertsNotRead ,0) as AlertsNotRead,--CASE WHEN i.AlertsNotRead IS NULL THEN 0 ELSE i.AlertsNotRead END AS AlertsNotRead,
		coalesce(c.AlertsWActions,0) as AlertsWActions, --CASE WHEN c.AlertsWActions IS NULL THEN 0 ELSE c.AlertsWActions END AS AlertsWActions,
		coalesce(unacted.AlertsWNoActions ,0) as AlertsWNoActions,--CASE WHEN d.AlertsWNoActions IS NULL THEN 0 ELSE d.AlertsWNoActions END AS AlertsWNoActions,
		
		
		coalesce( alertDelay.AlertsReadLess24 ,0) as AlertsReadLess24,--CASE WHEN j.AlertsReadLess24 IS NULL THEN 0 ELSE j.AlertsReadLess24 END AS AlertsReadLess24,
		coalesce( alertDelay.AlertsReadOneToThreeBD ,0) as AlertsReadOneToThreeBD,--CASE WHEN k.AlertsReadOneToThreeBD IS NULL THEN 0 ELSE k.AlertsReadOneToThreeBD END AS AlertsReadOneToThreeBD,
		coalesce( alertDelay.AlertsReadMoreThreeBD ,0) as AlertsReadMoreThreeBD,--CASE WHEN l.AlertsReadMoreThreeBD IS NULL THEN 0 ELSE l.AlertsReadMoreThreeBD END AS AlertsReadMoreThreeBD,
		--green section
		coalesce( cc.PatientsWActions,0) as PatientsWActions,--CASE WHEN cc.PatientsWActions IS NULL THEN 0 ELSE cc.PatientsWActions END AS PatientsWActions,
		coalesce(unacted.PatientsWNoActions,0) as PatientsWNoActions,--CASE WHEN dd.PatientsWNoActions IS NULL THEN 0 ELSE dd.PatientsWNoActions END AS PatientsWNoActions,
		coalesce(PatActedXDays.PatientsActionsOneToThreeBD,0) as PatientsActionsOneToThreeBD,--CASE WHEN ff.PatientsActionsOneToThreeBD IS NULL THEN 0 ELSE ff.PatientsActionsOneToThreeBD END AS PatientsActionsOneToThreeBD,
		coalesce(PatActedXDays.PatientsActionsMoreThreeBD,0) as PatientsActionsMoreThreeBD--CASE WHEN gg.PatientsActionsMoreThreeBD IS NULL THEN 0 ELSE gg.PatientsActionsMoreThreeBD END AS PatientsActionsMoreThreeBD,
	into #tAlertStatistics
	FROM #tUsers zz
	

		INNER JOIN #tNpis a 
			ON zz.UserId=a.UserId
		--AlertLevel
		left join #RecievedAlertsAndPatientsCounts recieved
			on recieved.npiId = a.NpiId
		left join #ReadAlertsAndPatientsCounts readed
			on readed.Npiid = a.NpiId
		left join #NotReadAlertsAndPatients unread
			on unread.npiId = a.NpiId
		left join #notActedAlertsAndPatients unacted
			on unacted.NpiId = a.NpiId
		left join #AlertReadInXDays alertDelay
			on alertDelay.NpiId = a.NpiId
		left join #PatientReadInXDays PatientDelay
			on PatientDelay.NpiId = a.NpiId
		left join #alertActionInXDays AlertActedXdays
			on AlertActedXdays.NpiId = a.NpiId
		left join #patientActedXDays PatActedXDays
			on PatActedXDays.NpiId = a.NpiId
		--inner JOIN @tAlertsPerDoc b ON a.NpiId=b.NpiId--changed to inner join to remove all the 0 columns
		LEFT JOIN @tAlertsWActionsPerDoc c ON a.NpiId=c.NpiId
		LEFT JOIN @tPatientsWActionsPerDoc cc ON a.NpiId=cc.NpiId


/*
-------------------------------------------------------------------------------------------------------------------------------------------------------------
All app statistics have been calculated up until this point. Logic has been adjusted to match Davids criteria and unify this report with the Incentive report
-------------------------------------------------------------------------------------------------------------------------------------------------------------
Proceeding to merge TIN data, Consultant Data and BSA Data. This part of the code hasnt been modified
-------------------------------------------------------------------------------------------------------------------------------------------------------------
*/

--Gathering TIN info from masterview(unchanged from previous report)
--DECLARE @tNpiTinMapping TABLE (NpiId UNIQUEIDENTIFIER, TIN VARCHAR(9), EntityName VARCHAR(100))
drop table if exists #tNpiTinMapping 
SELECT NpiId, TIN, Entity as EntityName
INTO #tNpiTinMapping 
FROM 
(
	(
		SELECT NpiId, NpiNum
		FROM #tNpis
		--WHERE NpiId NOT IN (SELECT NpiId FROM @tNpiTinMapping)--removed this because its checking if an emty table contains something
	) npis
	LEFT JOIN
	(
		SELECT DISTINCT NPI, TIN, Entity 
		FROM [_Master_ProviderList].[dbo].[Master_View] 
		WHERE ACOR IN (
			SELECT DISTINCT top 1   ACOR
			FROM [_Master_ProviderList].[dbo].[Master_View]
			order by ACOR desc
		) 
		AND NPI_Approval=1 AND TIN_Approval=1
	) mview
	ON npis.NpiNum = mview.Npi
) 



--BSA Metrics
declare @mostRecentPracticeMappingDataset varchar(100);
SELECT TOP 1 @mostRecentPracticeMappingDataset = dataset
          FROM [BSA].[dbo].[PBACO_ACOInsights_DataExtraction_Providers_Practice_Mapping]
          ORDER BY dataset DESC

drop table if exists #BSAMetrics
SELECT
  *,
  ROW_NUMBER() OVER(PARTITION BY TIN, NPI ORDER BY Metric DESC) AS Rn
into #BSAMetrics
FROM (
SELECT distinct a.[TIN], 
        a.[NPI], 
        a.Metric, 
        CONVERT(FLOAT, QTR1) AS Q1Ptg, 
        CONVERT(FLOAT, QTR2) AS Q2Ptg, 
        CONVERT(FLOAT, QTR3) AS Q3Ptg, 
        CONVERT(FLOAT, QTR4) AS Q4Ptg, 
		DATASET,
		Eligibility
		--b.newComer

FROM(--shorten the dataset to only people in our current consultant
	select distinct a.*
	from [BSA].[dbo].[PBACO_ACOInsights_DataExtraction_Providers_Practice_Mapping] a
	left join(select distinct Npi from  #tTinNpiConsultantMapping )npiConsol
	on npiConsol.NPI = a.NPI
	left join(select distinct tin from #tTinConsultantMapping) tinConsol
		on tinConsol.TIN = a.tin
	where (npiConsol.NPI is not null or tinConsol.TIN is not null)
) a
INNER JOIN(select distinct npi, tin, [Period] /*newComer*/ from  #NpiAssignmentStraddlingYear) AS B 
	ON a.tin = B.tin and a.npi = b.npi
WHERE  dataset = @mostRecentPracticeMappingDataset
AND a.year = (Select Max(year) from #NpiAssignmentStraddlingYear)
AND(
	(Eligibility = 'Formulated' and b.[Period]= '00')--new starters use formulated
or
	(Eligibility = 'CMS' and b.[Period] <> '00') --the rest use CMS
)
AND MemberSource = 'All'--was assign% now is all
AND iSNumeric(a.npi) = 1 -- NOT LIKE '%Undet%'
AND Metric IN('30-Day Readmission Rate', '% PDV')
) k


drop table if exists #BSATable
SELECT R.Tin, 
    R.NPI, 
    AVG(CASE WHEN R.Rn = 1 THEN R.Q1Ptg END) as Q1ReadmPtg, 
    AVG(CASE WHEN R.Rn = 2 THEN R.Q1Ptg END) as Q1PDVPtg,
				
    AVG(CASE WHEN R.Rn = 1 THEN R.Q2Ptg END) as Q2ReadmPtg, 
    AVG(CASE WHEN R.Rn = 2 THEN R.Q2Ptg END) as Q2PDVPtg,

    AVG(CASE WHEN R.Rn = 1 THEN R.Q3Ptg END) as Q3ReadmPtg, 
    AVG(CASE WHEN R.Rn = 2 THEN R.Q3Ptg END) as Q3PDVPtg,

    AVG(CASE WHEN R.Rn = 1 THEN R.Q4Ptg END) as Q4ReadmPtg, 
    AVG(CASE WHEN R.Rn = 2 THEN R.Q4Ptg END) as Q4PDVPtg
	--max(Eligibility) as Eligibility
	--max(newComer) as newComer
into #BSATable
FROM #BSAMetrics AS R
GROUP BY TIN, Npi

/*
------------------- ALL DATA HAS BEEN GATHERED, PREPARING FOR EXPORT ------------------------------------
*/

SELECT
  *
FROM
(
	SELECT 
		--Provider info
		a.UserId, a.NpiId, a.NpiNum, a.Username, a.Provider, b.TIN, b.EntityName AS TINName, 
		--Consultant info
		isnull
		(
			CASE
				WHEN b.TIN IN(SELECT DISTINCT TIN FROM #tTinNpiConsultantMapping)
					THEN npiConsultant.Consultant
					ELSE tinConsultant.Consultant
			END,'no consultant'
		) AS ProviderConsultant,
		--alert statistics
		AlertsReceived, 
		--alert actions info
		AlertsWActions, AlertsWNoActions, (AlertsActionsLess24+AlertsActionsOneToThreeBD) AS AlertsWActionsUnder3BD,
		AlertsActionsLess24, AlertsActionsOneToThreeBD, AlertsActionsMoreThreeBD,
		--alert readings info
		AlertsRead, AlertsNotRead, 
		(AlertsReadLess24+AlertsReadOneToThreeBD) AS AlertsReadUnder3BD, AlertsReadLess24, AlertsReadOneToThreeBD, AlertsReadMoreThreeBD,
		--patient statistics
		PatientsReceived,
		--patient actions info
		PatientsWActions, PatientsWNoActions, (PatientsActionsLess24+PatientsActionsOneToThreeBD) AS PatientsWActionsUnder3BD, PatientsActionsLess24, PatientsActionsOneToThreeBD, PatientsActionsMoreThreeBD,
		--patient readings info
		PatientsRead, PatientsNotRead, (PatientsReadLess24+PatientsReadOneToThreeBD) AS PatientsReadUnder3BD, PatientsReadLess24, PatientsReadOneToThreeBD, PatientsReadMoreThreeBD,
		--BSA info
		coalesce(CONVERT(VARCHAR,e.Q1ReadmPtg), 'N/A') as q1ReadmPtg,
		coalesce(CONVERT(VARCHAR,e.Q1PDVPtg), 'N/A') as Q1PDVPtg,
		
		coalesce(CONVERT(VARCHAR,e.Q2ReadmPtg), 'N/A') as Q2ReadmPtg,
		coalesce(CONVERT(VARCHAR,e.Q2PDVPtg), 'N/A') as Q2PDVPtg,

		coalesce(CONVERT(VARCHAR,Q3ReadmPtg), 'N/A') Q3ReadmPtg,  
		coalesce(CONVERT(VARCHAR,Q3PDVPtg), 'N/A') Q3PDVPtg,

		coalesce(CONVERT(VARCHAR,Q4ReadmPtg), 'N/A') Q4ReadmPtg,  
		coalesce(CONVERT(VARCHAR,Q4PDVPtg), 'N/A') Q4PDVPtg
		--e.newComer,
		--e.Eligibility

	FROM #tAlertStatistics a
		LEFT JOIN #tNpiTinMapping b --(SELECT NpiId, TIN, EntityName FROM @tNpiTinMapping) b 
			ON a.NpiId=b.NpiId
		LEFT JOIN #tTinConsultantMapping tinConsultant--(SELECT TIN, Consultant AS TinConsultant FROM @tTinConsultantMapping) c
			ON b.TIN=tinConsultant.TIN
		LEFT JOIN #tTinNpiConsultantMapping npiConsultant --(SELECT Npi, Consultant AS NpiConsultant FROM @tTinNpiConsultantMapping) d
			ON a.NpiNum= npiConsultant.NPI
		LEFT JOIN #BSATable e 
			ON a.NpiNum=e.Npi AND b.TIN=e.TIN
) z
WHERE
	ProviderConsultant IN(@ProviderConsultantParam)
order by  PatientsReceived DESC
