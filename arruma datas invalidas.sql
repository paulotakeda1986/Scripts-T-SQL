begin transaction

--Update
--sc
--set sc.is_nullable = 1
--from sys.tables st
--inner join sys.schemas ss on ss.schema_id = st.schema_id
--inner join sys.columns sc on sc.object_id = st.object_id
--inner join sys.types stp on stp.system_type_id = sc.system_type_id
--where (stp.name = 'date' or stp.name = 'datetime2') and sc.is_nullable = 0;

declare @contador bigint = 1,
		@comando nvarchar(max);

If OBJECT_ID('TEMPDB..#temp') IS NOT NULL
Drop table #temp;
		
select
ROW_NUMBER()OVER(order by st.name) as Seq,
st.name as nometabela,
sc.name as nomecoluna,
cast(concat('Update ',ss.name,'.',st.name,' set ',sc.name,' = null where YEAR(',sc.name,') < 1900;') as nvarchar(max)) as comando,
stp.name as tipo
into #temp
from sys.tables st
inner join sys.schemas ss on ss.schema_id = st.schema_id
inner join sys.columns sc on sc.object_id = st.object_id
inner join sys.types stp on stp.system_type_id = sc.system_type_id
where 
--left(st.name,4) = 't_TB' 
--and
(stp.name = 'date' or stp.name = 'datetime2')
order by st.name;

while @contador <= (select max(Seq) from #temp)
begin
	
	set @comando = (select comando from #temp where Seq = @contador);
	exec sys.sp_executesql @comando;
	
	set @contador = @contador + 1;

end;

commit;