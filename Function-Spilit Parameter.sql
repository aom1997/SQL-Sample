USE[temp_Zeming]
GO
CREATE FUNCTION [dbo].[fn_MVParam]
   (@RepParam nvarchar(4000), @Delim char(1)= ',')
RETURNS @Values TABLE (Param nvarchar(4000))AS
  BEGIN
  DECLARE @chrind INT
  DECLARE @Piece nvarchar(100)
  SELECT @chrind = 1 
  WHILE @chrind > 0
    BEGIN
      SELECT @chrind = CHARINDEX(@Delim,@RepParam)
      IF @chrind  > 0
        SELECT @Piece = LEFT(@RepParam,@chrind - 1)
      ELSE
        SELECT @Piece = @RepParam
      INSERT  @Values(Param) VALUES(CAST(@Piece AS VARCHAR))
      SELECT @RepParam = RIGHT(@RepParam,LEN(@RepParam) - @chrind)
      IF LEN(@RepParam) = 0 BREAK
    END
  RETURN
  END

USE[temp_Zeming]
GO

  declare @sParameterString varchar(max) = '515515,  551515,   5545454'
  SELECT trim(Param) FROM dbo.fn_MVParam(@sParameterString,',')
