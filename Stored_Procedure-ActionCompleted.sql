/****** Object:  StoredProcedure [dbo].[usp_get_statsActionCompletedData]    Script Date: 4/5/2023 1:45:57 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_get_statsActionCompletedData]
    @LogInUserId [nvarchar](max),
    @SelectedUserId [nvarchar](max),
    @Category [nvarchar](max),
    @Practice [nvarchar](max),
    @Payer [nvarchar](max),
    @Physician [nvarchar](max),
    @startdate [datetime],
    @enddate [datetime],
    @npiType [nvarchar](max)
AS
BEGIN
       DROP TABLE IF EXISTS #finalData  
    DROP TABLE IF EXISTS #RequiredCTBeneficiaryID  
    DROP TABLE IF EXISTS #Result
    DROP TABLE IF EXISTS #CTEData
    
    	Create table #RequiredCTBeneficiaryID(CTBeneficiaryID uniqueidentifier)
    	Create nonclustered index IX_CTBeneficiaryID on #RequiredCTBeneficiaryID(CTBeneficiaryID)
    
    DECLARE @AllUserId [nvarchar](Max)=''    
    SELECT @AllUserId=(CAST(@LogInUserId AS NVARCHAR(MAX)))    
    DECLARE @vRoles VARCHAR(25);    
    
    SELECT @startdate=CASE WHEN @startdate='' THEN (SELECT Min(CreatedDate) FROM dbo.CTBeneficiaryCategoryTracking)    
    else @startdate end,    
    @enddate=CASE WHEN @enddate='' then (Select MAX(CreatedDate) from dbo.CTBeneficiaryCategoryTracking)    
    else @enddate end    
    
    SELECT @vRoles = R.RoleName          
    FROM dbo.CTUserRoles Ur          
    JOIN dbo.CTRole R ON (R.RoleId = Ur.RoleId)          
    WHERE ( UR.UserId = @LogInUserId AND R.RoleName in('SUPERVISOR','REPORT'));          
    
    
    	IF (@vRoles IS NULL OR @vRoles = '')          
    BEGIN          
    SELECT @vRoles = R.RoleName          
    FROM dbo.CTUserRoles Ur          
    JOIN dbo.CTRole R ON (R.RoleId = Ur.RoleId)          
    WHERE (UR.UserId = @LogInUserId AND R.RoleName IN ('PROVIDER','REVIEWER USER'));          
    END    
    
    IF (@vRoles IS NULL OR @vRoles = '')          
    BEGIN          
    SELECT @vRoles = R.RoleName          
    FROM dbo.CTUserRoles Ur          
    JOIN dbo.CTRole R ON (R.RoleId = Ur.RoleId)          
    WHERE (UR.UserId = @LogInUserId AND R.RoleName IN ('USER','DATA'));          
    END    
    
    print(@vRoles);
    
    Insert into #RequiredCTBeneficiaryID(CTBeneficiaryID)
    SELECT  DISTINCT BT.CTBeneficiaryID    
    FROM CTBeneficiary ccsb   
    JOIN dbo.CTBeneficiaryCategoryTracking BT ON (BT.CTBeneficiaryID = ccsb.ID) and CONVERT(date,BT.CreatedDate) <= @enddate  
    WHERE   BT.IsReqforHistory=1 AND
    ( @Payer<>'' and  ccsb.Insurance In (SELECT value FROM STRING_SPLIT(@Payer,';'))  
    OR  
    (@Payer=''))  
    and ( @Physician<>'' and  ccsb.PhysicianName In (SELECT value FROM STRING_SPLIT(@Physician,';'))  
    OR  
    (@Physician=''))  
    AND    
    EXISTS     
    (SELECT 1    
    FROM dbo.NpiSubscriptions NS    
    Join dbo.Users U on u.UserId=NS.UserId and NS.ShowCareTracker=1 and  U.UserId = Case when (@vRoles = 'SUPERVISOR' OR @vRoles = 'REPORT') then U.UserId else @LogInUserId end
    JOIN dbo.Npis np on np.NpiId= NS.NpiId 
    JOIN dbo.NpiLocations NL ON (NL.NPIId = NS.NpiId)      
    JOIN dbo.Locations L ON (L.LocationId = NL.LocationId)      
    JOIN dbo.EntityLocations EL ON (EL.LocationId = L.LocationId)      
    JOIN dbo.Entities E ON (E.EntityId = EL.EntityId) and E.Active=1 and ((@Practice<>'' and  E.EntityName In (SELECT value FROM STRING_SPLIT(@Practice,';')))OR(@Practice=''))  
    and  ns.NpiId = ccsb.NPIId      
    AND E.EntityId = CCSB.EntityId  
    	and ((@npiType<>'' and  np.NpiType In (SELECT value FROM STRING_SPLIT(@npiType,';')))OR(@npiType='')) 
    )      
    ;WITH totalDataCount AS (    
    SELECT COUNT(ctb.Id) [total],c.CategoryCode,ctb.StatusId--into #tempdata     
    FROM  CTBeneficiaryCategoryTracking ctb     
    JOIN CTBeneficiaryCategory cc on cc.Id = ctb.CTBeneficiaryCategoryID    
    JOIN CTCategory c on c.Id = cc.CategoryId    
    WHERE ctb.IsReqforHistory=1 AND CONVERT(date,ctb.CreatedDate) BETWEEN @startdate and @enddate and ctb.CTBeneficiaryID in(SELECT CTBeneficiaryID FROM #RequiredCTBeneficiaryID)  
    	AND
    	(ctb.IsCustomActionTaken is null or  ctb.IsCustomActionTaken=0)  
    AND   
    
    ((@SelectedUserId<>'' AND ctb.CreatedBy In (Select value from STRING_SPLIT(@SelectedUserId,';')))      
    OR (((@vRoles<>'SUPERVISOR' OR @vRoles<>'REPORT' OR @vRoles<>'PROVIDER' OR @vRoles<> 'REVIEWER USER') AND ctb.CreatedBy = @LogInUserId AND @SelectedUserId = '')     
    OR (@SelectedUserId = '' AND (@vRoles = 'SUPERVISOR' OR @vRoles = 'REPORT' OR @vRoles='PROVIDER' OR @vRoles<> 'REVIEWER USER'))))    
    
    GROUP BY c.CategoryCode ,ctb.StatusId)  
    , cte AS(    
    SELECT SUM(t.total) As ActionsCount, s.Status [Status],s.Id  
    FROM CTStatus s    
    LEFT JOIN totalDataCount t on s.Id = t.StatusId     
    WHERE ((@Category<>'' AND  t.CategoryCode In (SELECT value FROM STRING_SPLIT(@Category,';')))OR(@Category=''))  
    GROUP BY s.Status,s.Id    
    )    
    
    SELECT ActionsCount,Status  
    ,SUM(ActionsCount) OVER() as TotalActions  
    ,Id INTO #finalData   
    FROM cte WHERE Status ! ='OPEN' GROUP by Status,Id,ActionsCount  
    
    DECLARE  @totalCount int;  
    SELECT @totalCount = TotalActions FROM #finalData  
    
    	print(@vRoles);
    
    	--Calculate Total Actions Available
    
    	 declare @TotalActions int=0
    
    ;with cte as( 
    SELECT BT.CreatedDate AS CreatedDate ,BT.UploadDate ,BT.Id AS Id,A.ActionName,A.ActionId,
    BT.CTBeneficiaryID,CTBeneficiaryCategoryID,cb.CategoryId     
    ,RANK() OVER (PARTITION BY B.CTBeneficiaryID,BT.CTBeneficiaryCategoryID ORDER BY bt.createddate desc) AS RN,
    CS.StatusCategory     
    FROM  #RequiredCTBeneficiaryID B           
    JOIN CTBeneficiaryCategoryTracking BT ON (BT.CTBeneficiaryID = B.CTBeneficiaryID)     
    JOIN CTBeneficiaryCategory CB ON CB.Id=BT.CTBeneficiaryCategoryID     
    	JOIN CTCategory CT on CT.Id=CB.CategoryId
    JOIN CTStatus CS on CS.id = BT.StatusId      
    JOIN dbo.CTActions A on BT.ActionId=A.Id
    		where BT.IsReqforHistory=1 AND
    			CreatedDate <= DATEADD(DAY,1,@enddate)
    			AND ((@Category<>'' AND  CategoryCode In (SELECT value FROM STRING_SPLIT(@Category,';')))OR(@Category=''))	
    			AND (BT.IsCustomActionTaken is null or  BT.IsCustomActionTaken=0) --and 
    --			((@SelectedUserId<>'' AND BT.CreatedBy In (Select value from STRING_SPLIT(@SelectedUserId,';')))      
    --OR (((@vRoles<>'SUPERVISOR' OR @vRoles<>'REPORT' OR @vRoles<>'PROVIDER') AND BT.CreatedBy = @LogInUserId AND @SelectedUserId = '')     
    --OR (@SelectedUserId = '' AND (@vRoles = 'SUPERVISOR' OR @vRoles = 'REPORT' OR @vRoles='PROVIDER'))))  
    )
    
    	Select @TotalActions = (Select count(*) from cte where RN=1 and StatusCategory='OPEN')
    
    	Select @TotalActions=@TotalActions+ISNULL(@totalCount,0);
    
    	--Calculated Aggregated count for Each Action
    	
    Select CTBeneficiaryID,Count(*)[RowCount],StatusCategory,Status,CreatedDate into #StatusRowCount from 
    
    (
    	 SELECT 
    BT.CTBeneficiaryID,CTBeneficiaryCategoryID,StatusCategory,CS.Status,BT.CreatedDate
    
    
    From #RequiredCTBeneficiaryID B   
    	JOIN CTBeneficiaryCategoryTracking BT ON (BT.CTBeneficiaryID = B.CTBeneficiaryID)  
    JOIN CTBeneficiaryCategory CB ON CB.Id=BT.CTBeneficiaryCategoryID     
    	JOIN CTCategory CT on CT.Id=CB.CategoryId
    JOIN CTStatus CS on CS.id = BT.StatusId      
    JOIN dbo.CTActions A on BT.ActionId=A.Id
    	where BT.IsReqforHistory=1 AND
    CreatedDate between @startdate and DATEADD(DAY,1,@enddate)
    AND ((@Category<>'' AND  CategoryCode In (SELECT value FROM STRING_SPLIT(@Category,';')))OR(@Category=''))	
    AND (BT.IsCustomActionTaken is null or  BT.IsCustomActionTaken=0) and 
    ((@SelectedUserId<>'' AND BT.CreatedBy In (Select value from STRING_SPLIT(@SelectedUserId,';')))      
    OR (((@vRoles<>'SUPERVISOR' OR @vRoles<>'REPORT' OR @vRoles<>'PROVIDER' OR @vRoles<> 'REVIEWER USER') AND BT.CreatedBy = @LogInUserId AND @SelectedUserId = '')     
    OR (@SelectedUserId = '' AND (@vRoles = 'SUPERVISOR' OR @vRoles = 'REPORT' OR @vRoles='PROVIDER' OR @vRoles<> 'REVIEWER USER'))))  
    
    	group by BT.CTBeneficiaryID,CTBeneficiaryCategoryID,StatusCategory,CS.Status,BT.CreatedDate
    	) as Temp
    	group by CTBeneficiaryID,StatusCategory,Status,CreatedDate
    
    
    	Select * into #RowCountOther from #StatusRowCount where StatusCategory<>'OPEN'
    
    
    --	Select CTBeneficiaryID,Count(*)[RowCount],StatusCategory,Status,CreatedDate into #StatusRowCountOpen from 
    --(
    --	 SELECT 
    --BT.CTBeneficiaryID,CTBeneficiaryCategoryID,StatusCategory,CS.Status,BT.CreatedDate
    --	From CTBeneficiaryCategoryTracking BT  
    --JOIN CTBeneficiaryCategory CB ON CB.Id=BT.CTBeneficiaryCategoryID     
    --	JOIN CTCategory CT on CT.Id=CB.CategoryId
    --JOIN CTStatus CS on CS.id = BT.StatusId      
    --JOIN dbo.CTActions A on BT.ActionId=A.Id
    --	where 
    ----((@Category<>'' AND  CategoryCode In (SELECT value FROM STRING_SPLIT(@Category,';')))OR(@Category=''))	
    ---- AND 
    --	(BT.IsCustomActionTaken is null or  BT.IsCustomActionTaken=0)  
    --	AND BT.CTBeneficiaryID In (Select CTBeneficiaryID from #StatusRowCount)
    --	group by BT.CTBeneficiaryID,CTBeneficiaryCategoryID,StatusCategory,CS.Status,BT.CreatedDate
    --	) as Temp
    --	group by CTBeneficiaryID,StatusCategory,Status,CreatedDate
    
    	Select Status,Sum(IsAggregated) AggregatedTotal into #StatusAggregatedData from 
    	(
    	Select t1.Status,t1.[RowCount] as Actedon,Case when (t1.[RowCount] >= 1) then 1 else 0 end IsAggregated  from  #RowCountOther t1
    	) as New
    	group by Status
    
    	declare @TotalAggregatedActions int=0;
    
    	Select  @TotalAggregatedActions = (Select Sum(AggregatedTotal) from #StatusAggregatedData)
    
    	;With FinalAggregatedData as
    	(
    	Select * from #StatusAggregatedData
    	UNION 
    	Select 'Total Actions Completed' as status ,@TotalAggregatedActions as AggregatedTotal
    	)
    
    	Select *  into #FinalAggregatedData from FinalAggregatedData
    
    	print(@TotalAggregatedActions); 
    
    	Create table #Result(Category nvarchar(250),TotalAction int,TotalActPecentage nvarchar(50), AggregratedTotal nvarchar(50))
    
    	Insert into #Result(Category,TotalAction ,TotalActPecentage)
    	Select 'Total Actions Available' as Category,@TotalActions as TotalAction,'' as TotalActPecentage 
    
    ;WITH final AS(  
    SELECT 'Total Actions Completed' as Category, isnull(@totalCount,0) As 'TotalAction', 100 as 'TotalActionPecentage'  
    UNION ALL  
    SELECT   
    s.Status as 'Category'  
    ,ISNULL(ct.ActionsCount,0) as 'TotalAction'  
    ,ISNULL((CONVERT(DECIMAL(10,2),ISNULL(ct.ActionsCount,0))/@totalCount)*100,0) AS 'TotalActionPecentage'  
    FROM CTStatus s  
    LEFT JOIN #finalData CT on s.Id= ct.Id  
    WHERE s.Status ! ='OPEN'   
    )  
    
    Insert into #Result(Category,TotalAction,TotalActPecentage)
    SELECT Category,TotalAction,case when TotalActionPecentage = 100 AND TotalAction != 0 then '100.00%'
    when TotalAction = 0 and TotalActionPecentage = 100 then '0.00%' 
    else  
    CONVERT(nvarchar(20),CONVERT(DECIMAL(10,2),TotalActionPecentage))+'%' end as TotalActPecentage FROM final 
    	
    	Select Category,ISNULL(TotalAction,0) as TotalAction,TotalActPecentage, Case when Category='Total Actions Available' then '' else  ISNULL(CAST(A.AggregatedTotal AS varchar),'0') end AggregatedTotal from #Result R
    		left join #FinalAggregatedData A on R.Category=A.Status  
END
GO


