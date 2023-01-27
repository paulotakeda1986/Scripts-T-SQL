select
OBJECT_NAME(sfkc.referenced_object_id) tabelareferenciada,
scr.name colunareferenciada,
OBJECT_NAME(sfkc.parent_object_id) tabelaligada,
scp.name colunatabelaligada,
concat('select * from ',OBJECT_NAME(sfkc.parent_object_id),' where ',scp.name,' is not null;') as consulta
from sys.foreign_key_columns sfkc
inner join sys.columns scr on scr.object_id = sfkc.referenced_object_id
and scr.column_id = sfkc.referenced_column_id
inner join sys.columns scp on scp.object_id = sfkc.parent_object_id
and scp.column_id = sfkc.parent_column_id
where OBJECT_NAME(sfkc.referenced_object_id) = 'NaturezaDespesa'
order by
sfkc.parent_object_id;