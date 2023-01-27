EXECUTE sys.sp_executesql N'
if exists (select top 1 1 from sys.all_objects where name = ''AspNumeracaoAutomatica'')
	drop procedure AspNumeracaoAutomatica;';

GO

create procedure AspNumeracaoAutomatica as

begin

declare @cont bigint = 1,
		@comando nvarchar(max);

truncate table tblNumeracaoAutomatica;

IF OBJECT_ID(N'tempdb.dbo.#NumeracaoAutomatica') IS NOT NULL
	DROP TABLE #NumeracaoAutomatica;

Create table #NumeracaoAutomatica(
nmTabela varchar(max) not null,
noAtual bigint null);

IF OBJECT_ID(N'tempdb.dbo.#ComandoSQL') IS NOT NULL
	DROP TABLE #ComandoSQL;

select
ROW_NUMBER()OVER(order by sc.column_id) as seq,
OBJECT_NAME(sc.object_id) as Tabela,
cast(CONCAT('Insert into #NumeracaoAutomatica(nmTabela,noAtual) select ''',OBJECT_NAME(sc.object_id),''',max(',name,') from ',OBJECT_NAME(sc.object_id),';') as nvarchar(max)) as Comando
into #ComandoSQL
from sys.columns sc
where LEFT(OBJECT_NAME(sc.object_id),3) = 'tbl' and sc.column_id = 1;

while @cont <= (select MAX(seq) from #ComandoSQL)
begin

	set @comando = (select Comando from #ComandoSQL where seq = @cont);

	execute sys.sp_executesql @comando;

	set @cont = @cont + 1;

end;

delete from #NumeracaoAutomatica where noAtual is null;

Insert into tblNumeracaoAutomatica(
idNumeracaoAutomatica,
nmTabela,
noAtual,
dsComplemento)
select
ROW_NUMBER()OVER(order by nmTabela) as idNumeracaoAutomatica,
nmTabela,
noAtual,
null as dsComplemento
from #NumeracaoAutomatica;

end;