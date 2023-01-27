select
st.name as TableName
,sc.name as ColumnName
,CONCAT('select * from ',st.name,';') as Selecao
From sys.columns sc
inner join sys.tables st on st.object_id = sc.object_id
Where sc.name like '%LOCALIDADEID%' and LEFT(st.name,9) = 'APLICADM_'
order by st.name;