--TEST DATASET
/*
--#################################Backup data #################################
DROP TABLE IF EXISTS #Part_A_2024
Select Beneficiary_ID,cur_clm_uniq_id,clm_from_dt,clm_line_num,clm_type_cd,clm_line_from_dt,clm_line_thru_dt,TRIM(clm_line_hcpcs_cd) AS clm_line_hcpcs_cd,oprtg_prvdr_npi_num
	,[prncpl_dgns_cd],[prncpl_dgns],[fac_prvdr_npi_num],atndg_prvdr_npi_num,othr_prvdr_npi_num,clm_adjsmt_type_cd,clm_line_srvc_unit_qty,clm_header_pmt_amnt,clm_line_pmt_amnt
INTO #Part_A_2024 from [_Internal_Reporting].[dbo].[CCLF_PartA_Claim_Line_Level_Amt]
WHERE clm_from_dt>'2023-01-01'

DROP TABLE IF EXISTS #Part_B_2024
Select beneficiary_id,ClaimID,cur_clm_uniq_id,clm_line_num,clm_line_cvrd_pd_amt,TRIM(clm_line_hcpcs_cd) AS clm_line_hcpcs_cd,clm_line_dgns_cd,	clm_line_dgns,clm_dgns_1_cd,clm_dgns_1,clm_dgns_2_cd,clm_dgns_2_,clm_dgns_3_cd,	clm_dgns3,clm_dgns_4_cd,clm_dgns_4,	clm_dgns_5_cd,clm_dgns_5,clm_dgns_6_cd,	clm_dgns_6,	clm_dgns_7_cd,	clm_dgns_7,	clm_dgns_8_cd,clm_dgns_8,clm_dgns_9_cd,clm_dgns_9,clm_dgns_10_cd,	clm_dgns_10,clm_dgns_11_cd,	clm_dgns_11,clm_dgns_12_cd,	clm_dgns_12,clm_type_cd,clm_from_dt,clm_thru_dt,clm_rndrg_prvdr_tax_num,rndrg_prvdr_npi_num,clm_prvdr_spclty_cd,clm_line_from_dt,	clm_line_thru_dt,clm_line_srvc_unit_qty,clm_line_alowd_chrg_amt,clm_adjsmt_type_cd,CLM_RNDRG_PRVDR_NPI_NUM,	CLM_RFRG_PRVDR_NPI_NUM
INTO #Part_B_2024 from [_Internal_Reporting].[dbo].[CCLF5_PartB_Claim_Line_Level_Amt]
WHERE clm_from_dt>'2023-01-01'
*/


--#################################Identify all Pts DIAGNOSISED WITH CANCER AND RECEIVED ONCOLOGY TREATMENT by Cpt codes, AS SOME OFFICE VISIT CLAIMS NEED BE INCLUDED 
/*
DROP TABLE IF EXISTS [temp_Zeming].[dbo].BENE
DROP TABLE IF EXISTS #BENE --PULL ALL BENE TO AVOID INCLUDE OFFICE VISIT CLAIMS, OR USE CLAIM ID

SELECT * INTO [temp_Zeming].[dbo].BENE FROM 
(
	SELECT DISTINCT beneficiary_id 
	FROM #Part_A_2024 A 
	LEFT JOIN [Claims_Files].[dbo].[CCLF4] B ON A.cur_clm_uniq_id = B.cur_clm_uniq_id 
	WHERE clm_line_hcpcs_cd IN 
	(
'77261','77262','77263','77280','77281','77282','77283','77284','77285','77286','77287','77288','77289','77290','77293','77295','77300','77301','77306','77307','77316','77317','77318','77321','77331','77332','77333','77334','77336','77338','77370','77401','77402','77407','77412','G6003','G6004','G6005','G6006','G6007','G6008','G6009','G6010','G6011','G6012','G6013','G6014','77385','77386','G6015','G6016','77417','77387','G6001','G6002','G6017','77014','77520','77521','77522','77523','77524','77525','77422','77423','77373','77372','77600','77601','77602','77603','77604','77605','77606','77607','77608','77609','77610','77611','77612','77613','77614','77615','77616','77617','77618','77619','77620','77778','77770','77772','0394T','0395T','77424','77425','77789','77750','77761','77762','77763','77790','77427','77431','77432','77435','77469','77470','77767','77768','77771','77371','G0339','G0340','19294','A9609','79101','79005','79403','A9512','A9543','A9590','A9595','A9606','A9607','A9699','19296','19297','19298','31643','32553','41019','49411','49412','55875','55876','55920','57155','57156','58346','76873','76965','61796','61797','61798','61799','61800'
	) -- RADIATION TREATMENT DELIVERY CODES
	AND 
	clm_dgns_cd IN
	(
	SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes] --CANCER DIAGNOSIS CODES
	)

	UNION 

	SELECT DISTINCT beneficiary_id FROM #Part_B_2024 
	WHERE clm_line_hcpcs_cd IN 
	(
'77261','77262','77263','77280','77281','77282','77283','77284','77285','77286','77287','77288','77289','77290','77293','77295','77300','77301','77306','77307','77316','77317','77318','77321','77331','77332','77333','77334','77336','77338','77370','77401','77402','77407','77412','G6003','G6004','G6005','G6006','G6007','G6008','G6009','G6010','G6011','G6012','G6013','G6014','77385','77386','G6015','G6016','77417','77387','G6001','G6002','G6017','77014','77520','77521','77522','77523','77524','77525','77422','77423','77373','77372','77600','77601','77602','77603','77604','77605','77606','77607','77608','77609','77610','77611','77612','77613','77614','77615','77616','77617','77618','77619','77620','77778','77770','77772','0394T','0395T','77424','77425','77789','77750','77761','77762','77763','77790','77427','77431','77432','77435','77469','77470','77767','77768','77771','77371','G0339','G0340','19294','A9609','79101','79005','79403','A9512','A9543','A9590','A9595','A9606','A9607','A9699','19296','19297','19298','31643','32553','41019','49411','49412','55875','55876','55920','57155','57156','58346','76873','76965','61796','61797','61798','61799','61800'
	) -- RADIATION TREATMENT DELIVERY CODES
   AND  
    (
	clm_line_dgns_cd 	in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes]) 
	OR clm_dgns_1_cd  in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])
	OR clm_dgns_2_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])
	OR clm_dgns_3_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])
	OR clm_dgns_4_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])
	OR clm_dgns_5_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])
	)	
) A

SELECT * INTO #BENE FROM [temp_Zeming].[dbo].BENE
*/

--#################################Identify all the Part A oncology treatment claims for these pts by diagnosis codes and cpt codes 
drop table if exists #All_PartA_treatment_claims
;WITH CTE AS
(
	SELECT a.*, b.clm_val_sqnc_num, b.clm_dgns_cd, c.description
	FROM 
	(	
		SELECT * FROM #Part_A_2024 
		WHERE beneficiary_id IN (SELECT DISTINCT Beneficiary_ID FROM #BENE) --BENE HAVE BEEN DIAGNOSISED CANCER AND RECEIVED ONCOLOGY TREATMENT
		AND trim(clm_line_hcpcs_cd) IN --FILTER BY CPT
(
'99201','99202','99203','99204','99205','99211','99212','99213','99214','99215','99241','99242','99243','99244','99245','99251','99252','99253','99254','99255','99221','99222','99223','99231','99232','99233','77261','77262','77263','77280','77281','77282','77283','77284','77285','77286','77287','77288','77289','77290','77293','77295','77300','77301','77306','77307','77316','77317','77318','77321','77331','77332','77333','77334','77336','77338','77370','77401','77402','77407','77412','G6003','G6004','G6005','G6006','G6007','G6008','G6009','G6010','G6011','G6012','G6013','G6014','77385','77386','G6015','G6016','77417','77387','G6001','G6002','G6017','77014','77520','77521','77522','77523','77524','77525','77422','77423','77373','77372','77600','77601','77602','77603','77604','77605','77606','77607','77608','77609','77610','77611','77612','77613','77614','77615','77616','77617','77618','77619','77620','77778','77770','77772','0394T','0395T','77424','77425','77789','77750','77761','77762','77763','77790','77427','77431','77432','77435','77469','77470','77767','77768','77771','77371','G0339','G0340','19294','A9609','79101','79005','79403','A9512','A9543','A9590','A9595','A9606','A9607','A9699','19296','19297','19298','31643','32553','41019','49411','49412','55875','55876','55920','57155','57156','58346','76873','76965','61796','61797','61798','61799','61800'
) --INCLUDE OFFCIE VISIT
	) A
	LEFT JOIN [Claims_Files].[dbo].[CCLF4] B ON A.cur_clm_uniq_id = B.cur_clm_uniq_id
	LEFT JOIN [CodeSets].[dbo].[LU_ICD10] C ON B.clm_dgns_cd=C.ICD10
	WHERE b.clm_dgns_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes]) 
)

SELECT A.*, 
case when trim(clm_line_hcpcs_cd) in ('99201','99202','99203','99204','99205','99211','99212','99213','99214','99215','99241','99242','99243','99244','99245','99251','99252','99253','99254','99255','99221','99222','99223','99231','99232','99233') then '1-Consultation'
when trim(clm_line_hcpcs_cd) in ('77261','77262','77263','77280','77281','77282','77283','77284','77285','77286','77287','77288','77289','77290','77293') then '2-Simulation'
when trim(clm_line_hcpcs_cd) in ('77295','77300','77301','77306','77307','77316','77317','77318','77321','77331','77332','77333','77334','77336','77338','77370') then '3-Planning'
when trim(clm_line_hcpcs_cd) in ('77401','77402','77407','77412','G6003','G6004','G6005','G6006','G6007','G6008','G6009','G6010','G6011','G6012','G6013','G6014','77385','77386','G6015','G6016','77417','77387','G6001','G6002','G6017','77014','77520','77521','77522','77523','77524','77525','77422','77423','77373','77372','77600','77601','77602','77603','77604','77605','77606','77607','77608','77609','77610','77611','77612','77613','77614','77615','77616','77617','77618','77619','77620','77778','77770','77772','0394T','0395T','77424','77425','77789','77750','77761','77762','77763','77790'
) then '4-Radiation'
when trim(clm_line_hcpcs_cd) in ('77427','77431','77432','77435','77469','77470') then '5-Management'
else 'Unknown' end as [Treatment_Process],

case when clm_dgns_cd in('C500','C5001','C50011','C50012','C50019','C5002','C50021','C50022','C50029','C501','C5011','C50111','C50112','C50119','C5012','C50121','C50122','C50129','C502','C5021','C50211','C50212','C50219','C5022','C50221','C50222','C50229','C503','C5031','C50311','C50312','C50319','C5032','C50321','C50322','C50329','C504','C5041','C50411','C50412','C50419','C5042','C50421','C50422','C50429','C505','C5051','C50511','C50512','C50519','C5052','C50521','C50522','C50529','C506','C5061','C50611','C50612','C50619','C5062','C50621','C50622','C50629','C508','C5081','C50811','C50812','C50819','C5082','C50821','C50822','C50829','C509','C5091','C50911','C50912','C50919','C5092','C50921','C50922','C50929') then 'breast'
when  clm_dgns_cd in ('C340','C3400','C3401','C3402','C341','C3410','C3411','C3412','C342','C343','C3430','C3431','C3432','C348','C3480','C3481','C3482','C349','C3490','C3491','C3492') then 'lung' 
when  clm_dgns_cd in ('C4A0','C4A1','C4A10','C4A11','C4A111','C4A112','C4A12','C4A121','C4A122','C4A2','C4A20','C4A21','C4A22','C4A3','C4A30','C4A31','C4A39','C4A4','C4A5','C4A51','C4A52','C4A59','C4A6','C4A60','C4A61','C4A62','C4A7','C4A70','C4A71','C4A72','C4A8','C4A9','C430','C431','C4310','C4311','C43111','C43112','C4312','C43121','C43122','C432','C4320','C4321','C4322','C433','C4330','C4331','C4339','C434','C435','C4351','C4352','C4359','C436','C4360','C4361','C4362','C437','C4370','C4371','C4372','C438','C439','C440','C4400','C4401','C4402','C4409','C441','C4410','C44101','C44102','C441021','C441022','C44109','C441091') then 'skin' 
when clm_dgns_cd in ('C61') then 'prostate' else 'Unknown' end as [Body_Area]
INTO #All_PartA_treatment_claims
FROM (SELECT *, ROW_NUMBER()OVER(PARTITION BY cur_clm_uniq_id,clm_line_num ORDER BY clm_val_sqnc_num ASC) AS RN FROM CTE) A --GET ONE RELATED DIAGNOSIS CODE FOR EACH CLAIM 
WHERE RN=1


--#################################Identify all the Part B oncology treatment claims for these pts by diagnosis codes and cpt codes 
drop table if exists #All_PartB_treatment_claims
;WITH CTE AS
(
	SELECT a.*, 
	CASE WHEN (clm_line_dgns_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_line_dgns_cd
	WHEN (clm_dgns_1_cd  in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_1_cd
	WHEN (clm_dgns_2_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_2_cd
	WHEN (clm_dgns_3_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_3_cd
	WHEN (clm_dgns_4_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_4_cd
	WHEN (clm_dgns_5_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_5_cd ELSE NULL END AS clm_dgns_cd,

	CASE WHEN (clm_line_dgns_cd 	in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_line_dgns
	WHEN (clm_dgns_1_cd  in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_1
	WHEN (clm_dgns_2_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_2_
	WHEN (clm_dgns_3_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns3
	WHEN (clm_dgns_4_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_4
	WHEN (clm_dgns_5_cd in (SELECT [ICD CODES] FROM [temp_Zeming].[dbo].[ICD Codes])) THEN clm_dgns_5 ELSE NULL END AS [description]
	FROM 
	(	
		SELECT * FROM #Part_B_2024 
		WHERE beneficiary_id IN (SELECT DISTINCT Beneficiary_ID FROM #BENE) 
		AND trim(clm_line_hcpcs_cd) IN --FILTER BY CPT
(
'99201','99202','99203','99204','99205','99211','99212','99213','99214','99215','99241','99242','99243','99244','99245','99251','99252','99253','99254','99255','99221','99222','99223','99231','99232','99233','77261','77262','77263','77280','77281','77282','77283','77284','77285','77286','77287','77288','77289','77290','77293','77295','77300','77301','77306','77307','77316','77317','77318','77321','77331','77332','77333','77334','77336','77338','77370','77401','77402','77407','77412','G6003','G6004','G6005','G6006','G6007','G6008','G6009','G6010','G6011','G6012','G6013','G6014','77385','77386','G6015','G6016','77417','77387','G6001','G6002','G6017','77014','77520','77521','77522','77523','77524','77525','77422','77423','77373','77372','77600','77601','77602','77603','77604','77605','77606','77607','77608','77609','77610','77611','77612','77613','77614','77615','77616','77617','77618','77619','77620','77778','77770','77772','0394T','0395T','77424','77425','77789','77750','77761','77762','77763','77790','77427','77431','77432','77435','77469','77470','77767','77768','77771','77371','G0339','G0340','19294','A9609','79101','79005','79403','A9512','A9543','A9590','A9595','A9606','A9607','A9699','19296','19297','19298','31643','32553','41019','49411','49412','55875','55876','55920','57155','57156','58346','76873','76965','61796','61797','61798','61799','61800'
)
	) A
)

SELECT A.*, 
case when trim(clm_line_hcpcs_cd) in ('99201','99202','99203','99204','99205','99211','99212','99213','99214','99215','99241','99242','99243','99244','99245','99251','99252','99253','99254','99255','99221','99222','99223','99231','99232','99233') then '1-Consultation'
when trim(clm_line_hcpcs_cd) in ('77261','77262','77263','77280','77281','77282','77283','77284','77285','77286','77287','77288','77289','77290','77293') then '2-Simulation'
when trim(clm_line_hcpcs_cd) in ('77295','77300','77301','77306','77307','77316','77317','77318','77321','77331','77332','77333','77334','77336','77338','77370') then '3-Planning'
when trim(clm_line_hcpcs_cd) in ('77401','77402','77407','77412','G6003','G6004','G6005','G6006','G6007','G6008','G6009','G6010','G6011','G6012','G6013','G6014','77385','77386','G6015','G6016','77417','77387','G6001','G6002','G6017','77014','77520','77521','77522','77523','77524','77525','77422','77423','77373','77372','77600','77601','77602','77603','77604','77605','77606','77607','77608','77609','77610','77611','77612','77613','77614','77615','77616','77617','77618','77619','77620','77778','77770','77772','0394T','0395T','77424','77425','77789','77750','77761','77762','77763','77790'
) then '4-Radiation'
when trim(clm_line_hcpcs_cd) in ('77427','77431','77432','77435','77469','77470') then '5-Management'
else 'Unknown' end as [Treatment_Process],

case when clm_dgns_cd in('C500','C5001','C50011','C50012','C50019','C5002','C50021','C50022','C50029','C501','C5011','C50111','C50112','C50119','C5012','C50121','C50122','C50129','C502','C5021','C50211','C50212','C50219','C5022','C50221','C50222','C50229','C503','C5031','C50311','C50312','C50319','C5032','C50321','C50322','C50329','C504','C5041','C50411','C50412','C50419','C5042','C50421','C50422','C50429','C505','C5051','C50511','C50512','C50519','C5052','C50521','C50522','C50529','C506','C5061','C50611','C50612','C50619','C5062','C50621','C50622','C50629','C508','C5081','C50811','C50812','C50819','C5082','C50821','C50822','C50829','C509','C5091','C50911','C50912','C50919','C5092','C50921','C50922','C50929') then 'breast'
when  clm_dgns_cd in ('C340','C3400','C3401','C3402','C341','C3410','C3411','C3412','C342','C343','C3430','C3431','C3432','C348','C3480','C3481','C3482','C349','C3490','C3491','C3492') then 'lung' 
when  clm_dgns_cd in ('C4A0','C4A1','C4A10','C4A11','C4A111','C4A112','C4A12','C4A121','C4A122','C4A2','C4A20','C4A21','C4A22','C4A3','C4A30','C4A31','C4A39','C4A4','C4A5','C4A51','C4A52','C4A59','C4A6','C4A60','C4A61','C4A62','C4A7','C4A70','C4A71','C4A72','C4A8','C4A9','C430','C431','C4310','C4311','C43111','C43112','C4312','C43121','C43122','C432','C4320','C4321','C4322','C433','C4330','C4331','C4339','C434','C435','C4351','C4352','C4359','C436','C4360','C4361','C4362','C437','C4370','C4371','C4372','C438','C439','C440','C4400','C4401','C4402','C4409','C441','C4410','C44101','C44102','C441021','C441022','C44109','C441091') then 'skin' 
when clm_dgns_cd in ('C61') then 'prostate' else 'Unknown' end as [Body_Area]

INTO #All_PartB_treatment_claims
FROM CTE A --GET ONE RELATED DIAGNOSIS CODE FOR EACH CLAIM
WHERE clm_dgns_cd IS NOT  NULL

--################################# UNION Part A and Part B, Filter Consultation IN 60 DAYS
DROP TABLE IF exists #FILTERD_CLAIMS-- Filter Consultation IN 60 DAYS
;WITH Combined_Claims as
(
	SELECT *,
	CASE WHEN trim(clm_line_hcpcs_cd) IN ('77767','77768','77770','77771','77772') THEN 'Brachytherapy'
	WHEN trim(clm_line_hcpcs_cd) IN ('G6015','77385','77386','G6016') THEN 'IMRT'
	WHEN trim(clm_line_hcpcs_cd) IN ('77373') THEN 'SBRT'
	WHEN trim(clm_line_hcpcs_cd) IN ('G6012','G6013') THEN '3D'
	ELSE 'Unknown'  END AS  Treatment_Type
	FROM
	(
	SELECT 'PartA' as PTA,Beneficiary_ID,cur_clm_uniq_id,clm_from_dt,clm_line_num,clm_type_cd,clm_line_from_dt,clm_line_thru_dt,clm_line_hcpcs_cd,Treatment_Process,clm_dgns_cd,description,Body_Area
	,[prncpl_dgns_cd],[prncpl_dgns],[fac_prvdr_npi_num]
	,CASE WHEN oprtg_prvdr_npi_num IS NULL THEN atndg_prvdr_npi_num WHEN oprtg_prvdr_npi_num ='~         ' THEN atndg_prvdr_npi_num WHEN oprtg_prvdr_npi_num ='' THEN atndg_prvdr_npi_num ELSE oprtg_prvdr_npi_num END AS oprtg_prvdr_npi_num
	,atndg_prvdr_npi_num,othr_prvdr_npi_num,clm_adjsmt_type_cd,clm_line_srvc_unit_qty,clm_header_pmt_amnt,clm_line_pmt_amnt
	FROM #All_PartA_treatment_claims
	union all
	SELECT 'PartB' as PTB,Beneficiary_ID,cur_clm_uniq_id,clm_from_dt,clm_line_num,clm_type_cd,clm_line_from_dt,clm_line_thru_dt,trim(clm_line_hcpcs_cd),Treatment_Process,clm_dgns_cd,description,Body_Area
	,'' AS [prncpl_dgns_cd],'' AS [prncpl_dgns],'' AS fac_prvdr_npi_num
	,RNDRG_PRVDR_NPI_NUM as oprtg_prvdr_npi_num,CLM_RFRG_PRVDR_NPI_NUM as atndg_prvdr_npi_num,'' AS othr_prvdr_npi_num,clm_adjsmt_type_cd,clm_line_srvc_unit_qty,'' AS clm_header_pmt_amnt,CLM_LINE_CVRD_PD_AMT AS clm_line_pmt_amnt
	FROM #All_PartB_treatment_claims
	) a
)

,ALL_CONSULTATION AS
(
	SELECT * FROM
	(
		SELECT *, ROW_NUMBER()OVER(PARTITION BY cur_clm_uniq_id, clm_line_num ORDER BY DIFF ASC) AS RN 
		FROM
		(
			SELECT * FROM
			(
				SELECT A.*, DATEDIFF(DAY,A.clm_line_from_dt,B.clm_line_from_dt) AS DIFF --DO OFFICE VISIT FIRST
				FROM
				(SELECT * FROM Combined_Claims WHERE Treatment_Process='1-Consultation') A JOIN 
				(SELECT * FROM Combined_Claims WHERE Treatment_Process<>'1-Consultation') B
				ON A.BENEFICIARY_ID =B.BENEFICIARY_ID
			) A WHERE DIFF BETWEEN 0 AND 60 -- THE OFFICE VISIT MUST TAKE PRIPOR TOONCOLOGT TREATMENT AND WITHIN 60 DAYS
		) A
	) A WHERE RN=1
)

SELECT * 
INTO #FILTERD_CLAIMS
FROM Combined_Claims WHERE Treatment_Process<>'1-Consultation' --EXCLUDE ALL OFFICE VISIT
UNION ALL --ADD OFFICE VISIT MEET REQUIREMENT
SELECT PTA,	Beneficiary_ID,	cur_clm_uniq_id,	clm_from_dt,	clm_line_num,	clm_type_cd,	clm_line_from_dt,	clm_line_thru_dt,	trim(clm_line_hcpcs_cd),	Treatment_Process,	clm_dgns_cd,	description,	Body_Area,	prncpl_dgns_cd,	prncpl_dgns,	fac_prvdr_npi_num,	oprtg_prvdr_npi_num,	atndg_prvdr_npi_num,	othr_prvdr_npi_num,	clm_adjsmt_type_cd,	clm_line_srvc_unit_qty,	clm_header_pmt_amnt,	clm_line_pmt_amnt,Treatment_Type FROM ALL_CONSULTATION


--################################# Identify Treatment_Group
--Identify Simulation Group for all Treatment Claims
DROP TABLE IF EXISTS #ALL_CLAIMS_WITH_SIMU_GROUP
;With Treatment_Group as --GET TREATMENT GROUP NUMBER BY THE SIMULATION FIELD, EVERY TREATMENT GROUP IDENTIFYED BY SIMULATION
(
	SELECT * , row_number()over(order by beneficiary_id,clm_line_from_dt asc) as Treatment_Group
	FROM (SELECT * FROM #FILTERD_CLAIMS WHERE Treatment_Process='2-Simulation') A
)

, ALL_CLAIMS_WITH_SIMU_GROUP AS
(
	SELECT *
	FROM
	(
		SELECT * FROM --IDENTIFY SIMULATION GROUP FOR CONSULTATION CLAIMS
		(
			SELECT *, ROW_NUMBER()OVER(PARTITION BY cur_clm_uniq_id, clm_line_num ORDER BY DIFF ASC) AS RN
			FROM
			(
				SELECT * FROM 
				(
					SELECT A.*, B.clm_line_from_dt AS BDATE,B.Treatment_Group, DATEDIFF(DAY,A.clm_line_from_dt,B.clm_line_from_dt) AS DIFF--most recent consultation before simulation
					FROM (SELECT * FROM #FILTERD_CLAIMS WHERE Treatment_Process='1-Consultation') A 
					LEFT JOIN Treatment_Group B ON A.Beneficiary_ID=B.Beneficiary_ID
				) A WHERE DIFF >= 0  --OFFICE VISIT MUST PRIOR TO THE SIMULATION
			)A
		) A WHERE RN=1

		UNION ALL
		SELECT * FROM --IDENTIFY SIMULATION GROUP FOR TREATMENT CLAIMS EXCEPT SIMULATION
		(
			SELECT *, ROW_NUMBER()OVER(PARTITION BY cur_clm_uniq_id, clm_line_num ORDER BY DIFF ASC) AS RN
			FROM
			(
				SELECT * FROM 
				(
					SELECT A.*, B.clm_line_from_dt AS BDATE,B.Treatment_Group, DATEDIFF(DAY,B.clm_line_from_dt,A.clm_line_from_dt) AS DIFF--most recent consultation before simulation
					FROM (SELECT * FROM #FILTERD_CLAIMS WHERE Treatment_Process NOT IN ('1-Consultation','2-Simulation')) A 
					LEFT JOIN Treatment_Group B ON A.Beneficiary_ID=B.Beneficiary_ID
				) A WHERE DIFF>= 0  --OTHER TREEATMENT MUST AFTER THE SIMULATION 
			)A
		) A WHERE RN=1

		UNION ALL
		SELECT A.*, B.clm_line_from_dt AS BDATE,B.Treatment_Group, DATEDIFF(DAY,B.clm_line_from_dt,A.clm_line_from_dt) AS DIFF,0 AS RN--most recent consultation before simulation
		FROM (SELECT * FROM #FILTERD_CLAIMS WHERE Treatment_Process ='2-Simulation') A 
		LEFT JOIN Treatment_Group B ON A.cur_clm_uniq_id=B.cur_clm_uniq_id AND A.clm_line_num=B.clm_line_num
	) A
)

SELECT A.*, B.Treatment_Group 
INTO #ALL_CLAIMS_WITH_SIMU_GROUP
FROM #FILTERD_CLAIMS A LEFT JOIN ALL_CLAIMS_WITH_SIMU_GROUP B ON A.cur_clm_uniq_id=B.cur_clm_uniq_id AND A.clm_line_num=B.clm_line_num


--################################# Identify Treatment Type, SOME SIMULATION GROUP SHOULD HAVE SAME TREATMENT TYPE
DROP TABLE IF EXISTS #FINAL
;WITH TREATMENT_TYPE AS --ONLY KEEP ONE TREATMENT GROUP FOR EACH TREATMENT COURSE
(
	SELECT Treatment_Group,Treatment_Type
	FROM
	(
		SELECT Treatment_Group,Treatment_Type, ROW_NUMBER()OVER(PARTITION BY Treatment_Group ORDER BY RN ASC) AS RN2 FROM 
		(
			SELECT DISTINCT Treatment_Group,Treatment_Type
			, CASE WHEN Treatment_Type='IMRT' THEN 1 
			WHEN Treatment_Type='SBRT' THEN 2 WHEN
			Treatment_Type='3D' then 3 when
			Treatment_Type='IMRT' then 1  ELSE 5 END AS RN
			FROM #ALL_CLAIMS_WITH_SIMU_GROUP
		) A
	) A WHERE RN2=1
)


SELECT PTA as [PartA/B],Beneficiary_ID,	
cur_clm_uniq_id,clm_from_dt,clm_line_num,clm_type_cd,clm_line_from_dt,clm_line_thru_dt,	clm_line_hcpcs_cd,Treatment_Group,B_TYPE AS Treatment_Type,Treatment_Process,clm_dgns_cd,description,Body_Area,oprtg_prvdr_npi_num,atndg_prvdr_npi_num,clm_adjsmt_type_cd,clm_line_srvc_unit_qty,clm_header_pmt_amnt
,case when clm_adjsmt_type_cd='1' then -clm_line_pmt_amnt else clm_line_pmt_amnt end as clm_line_pmt_amnt
INTO #FINAL
FROM
(
	SELECT A.*, COALESCE(B.Treatment_Type,A.Treatment_Type) AS B_TYPE, B.Treatment_Group AS B_GROUP
	FROM
	(
		select *
		from #ALL_CLAIMS_WITH_SIMU_GROUP
		where clm_type_cd<>'50' 
	) A 
	LEFT JOIN TREATMENT_TYPE B 
	ON A.Treatment_Group=B.Treatment_Group
) A
ORDER BY Beneficiary_ID,clm_line_from_dt asc,cur_clm_uniq_id,Treatment_Process asc


SELECT Body_Area, SUM(clm_line_pmt_amnt) AS TOTAL_COST,COUNT(DISTINCT BENEFICIARY_ID) AS [# Distince Patients],
SUM(CASE WHEN Treatment_Process='4-Radiation' then 1 else 0 end) as [# Treatment Delivery]
FROM #FINAL 
WHERE oprtg_prvdr_npi_num='1295926277'
GROUP BY Body_Area
order by Body_Area desc


SELECT Body_Area,Treatment_Type, SUM(clm_line_pmt_amnt) as Total_Cost
,COUNT(DISTINCT Treatment_Group)  AS Total_Treatments
,COUNT(DISTINCT Beneficiary_ID) AS [# Distince Patients]
,SUM(CASE WHEN Treatment_Process='4-Radiation' then 1 else 0 end) as [# Treatment Delivery]
FROM #FINAL 
WHERE Treatment_Group IS NOT NULL --ONLY INCLUDES CLAIMS ASSOCIATED WITH COURSE OF TREATMENT
AND oprtg_prvdr_npi_num='1164425237'
GROUP BY Body_Area,Treatment_Type
order by Body_Area DESC,Treatment_Type ASC


select [PartA/B],	Beneficiary_ID,	cur_clm_uniq_id,clm_from_dt,clm_line_num,clm_type_cd,clm_line_from_dt,clm_line_thru_dt,
Treatment_Group,Treatment_Type,clm_line_hcpcs_cd,Treatment_Process,clm_dgns_cd,description,Body_Area
,oprtg_prvdr_npi_num,atndg_prvdr_npi_num
,clm_adjsmt_type_cd,clm_line_srvc_unit_qty,clm_header_pmt_amnt,clm_line_pmt_amnt
from #FINAL
order by
Beneficiary_ID,clm_line_from_dt asc,cur_clm_uniq_id,Treatment_Process asc
