------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
USE AgiliBlue_MT_Paranaita_Pref;

BEGIN TRANSACTION

SET XACT_ABORT ON;

SET NOCOUNT ON;

DROP TABLE IF EXISTS X_TEMP;

--SELECT
--DISTINCT
--STP.*
--FROM sys.tables ST
--INNER JOIN sys.columns SC ON ST.object_id = SC.object_id
--INNER JOIN sys.types STP ON SC.system_type_id = STP.system_type_id
--ORDER BY
--STP.system_type_id;

WITH CTE_FILTRO AS
(
SELECT
	*
FROM sys.tables
WHERE (LEFT(name,2) = 't_' OR LEFT(name,9) = 'contagil_' OR LEFT(name,16) = 'patrim_guardiao_' OR LEFT(name,4) = 'CPL_')
),
CTE_TMP AS
(
SELECT
	ROW_NUMBER()OVER(ORDER BY ST.name) AS SeqTable,
	ST.object_id,
	ST.name
FROM SYS.tables ST
INNER JOIN CTE_FILTRO F ON ST.object_id = F.object_id
GROUP BY
	ST.name,
	ST.object_id
),
CTE_MAX_COLUMN_ID AS
(
SELECT
	ST.object_id,
	MAX(SC.column_id) AS max_column_id
FROM sys.tables ST
INNER JOIN CTE_TMP T ON ST.object_id = T.object_id
INNER JOIN sys.columns SC ON ST.object_id = SC.object_id
INNER JOIN sys.types STP ON SC.system_type_id = STP.system_type_id
WHERE SC.system_type_id = SC.user_type_id
GROUP BY
	ST.object_id
),
CTE_MIN_COLUMN_ID AS
(
SELECT
	ST.object_id,
	MIN(SC.column_id) AS min_column_id
FROM sys.tables ST
INNER JOIN CTE_TMP T ON ST.object_id = T.object_id
INNER JOIN sys.columns SC ON ST.object_id = SC.object_id
INNER JOIN sys.types STP ON SC.system_type_id = STP.system_type_id
WHERE SC.system_type_id = SC.user_type_id
GROUP BY
	ST.object_id
)
SELECT
	T.SeqTable,
	ROW_NUMBER()OVER(PARTITION BY T.SeqTable ORDER BY ST.name) AS SeqColumn,
	ST.name AS NomeTabela,
	CONCAT(IIF(SC.column_id = MNCI.min_column_id,CONCAT('CREATE TABLE __',ST.name,'('),''),SC.name,' ',UPPER(STP.name),'',IIF(STP.system_type_id IN (167,231,175),CONCAT('(',IIF(SC.max_length < 0 OR SC.max_length > 4000,'MAX',CAST(SC.max_length AS VARCHAR(MAX))),')'),IIF(STP.system_type_id IN (106),CONCAT('(',SC.precision,',',SC.scale,')'),NULL)),' ',IIF(SC.is_nullable = 1,'NULL','NOT NULL'),IIF(SC.column_id = MCI.max_column_id,') ON Migracao',',')) AS ComandoCreateTESTE,
	SC.column_id,
	SC.name AS Coluna,
	UPPER(STP.name) AS Tipo,
	IIF(STP.system_type_id IN (167,231),'(MAX)',IIF(STP.system_type_id IN (106),CONCAT('(',SC.max_length,',',SC.precision,')'),NULL)) AS Precisao,
	IIF(SC.is_nullable = 1,'NULL','NOT NULL') AS IsNullable,
	MCI.max_column_id
INTO X_TEMP
FROM sys.tables ST
INNER JOIN CTE_TMP T ON ST.object_id = T.object_id
INNER JOIN CTE_MIN_COLUMN_ID MNCI ON ST.object_id = MNCI.object_id
INNER JOIN CTE_MAX_COLUMN_ID MCI ON ST.object_id = MCI.object_id
INNER JOIN sys.columns SC ON ST.object_id = SC.object_id
INNER JOIN sys.types STP ON SC.system_type_id = STP.system_type_id
WHERE SC.system_type_id = SC.user_type_id AND STP.name <> 'SYSNAME';

DECLARE @CONT BIGINT = 1,
		@CONT1 BIGINT = 1,
		@COMANDO NVARCHAR(MAX);

/* */		
WHILE @CONT <= (SELECT MAX(SeqTable) FROM X_TEMP)
BEGIN

	WHILE @CONT1 <= (SELECT MAX(SeqColumn) FROM X_TEMP WHERE SeqTable = @CONT)
	BEGIN

		SET @COMANDO = CONCAT(@COMANDO, (SELECT ComandoCreateTESTE FROM X_TEMP WHERE SeqTable = @CONT AND SeqColumn = @CONT1))
		SET @CONT1 = @CONT1 + 1;

	END;
	
	PRINT REPLACE(@COMANDO,'  ',' ');
	SET @CONT = @CONT + 1;
	SET @CONT1 = 0;
	EXEC SP_EXECUTESQL @COMANDO;
	SET @COMANDO = '';

END;

SET @CONT = 1;
SET @CONT1 = 1;
SET @COMANDO = '';

/* */
WHILE @CONT <= (SELECT MAX(SeqTable) FROM X_TEMP)
BEGIN

	SET @COMANDO = (SELECT DISTINCT CONCAT('INSERT INTO __',NomeTabela,' SELECT * FROM ',NomeTabela,';') FROM X_TEMP WHERE SeqTable = @CONT)
	PRINT @COMANDO;
	SET @CONT = @CONT + 1;
	EXEC SP_EXECUTESQL @COMANDO;
	SET @COMANDO = '';

END;

SET @CONT = 1;
SET @CONT1 = 1;
SET @COMANDO = '';

/* */
WHILE @CONT <= (SELECT MAX(SeqTable) FROM X_TEMP)
BEGIN

	SET @COMANDO = (SELECT DISTINCT CONCAT('DROP TABLE ',NomeTabela,';') FROM X_TEMP WHERE SeqTable = @CONT)
	PRINT @COMANDO;
	SET @CONT = @CONT + 1;
	EXEC SP_EXECUTESQL @COMANDO;
	SET @COMANDO = '';

END;

SET @CONT = 1;
SET @CONT1 = 1;
SET @COMANDO = '';

/* */
WHILE @CONT <= (SELECT MAX(SeqTable) FROM X_TEMP)
BEGIN

	SET @COMANDO = (SELECT DISTINCT CONCAT('sp_rename ','''','__',NomeTabela,'''',', ','''',NomeTabela,'''',';') FROM X_TEMP WHERE SeqTable = @CONT)
	PRINT @COMANDO;
	SET @CONT = @CONT + 1;
	EXEC SP_EXECUTESQL @COMANDO;
	SET @COMANDO = '';

END;

DROP TABLE IF EXISTS X_TEMP;

DBCC SHRINKDATABASE(N'AgiliBlue_MT_Paranaita_Pref' );

COMMIT;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------