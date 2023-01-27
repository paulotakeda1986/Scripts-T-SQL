[15:29] Leandro Henrique Pereira Chaves
begin transaction
 
set nocount on;
 
select 
ROW_NUMBER()OVER(order by sc.object_id) as Seq,
object_name(sc.object_id) as nometabela,
sc.name as nomecampo,
concat('Insert into t_tabela_texto(nometabela,nomecampo,valor) select ''',OBJECT_NAME(object_id),''',''',sc.name,''',',sc.name,' from ',object_name(object_id),' where ',sc.name,' like ''%Técnico ou Cientifico%'';') as comando
into t_temporaria
from sys.columns sc
where sc.system_type_id = 231 and left(object_name(object_id),8) = 'Técnico ou Cientifico'
order by object_name(object_id);
 
create table t_tabela_texto(
nometabela varchar(max) not null,
nomecampo varchar(max) not null,
valor varchar(max) not null);
 
declare @cont bigint = 1,
        @comando nvarchar(max);
 
while @cont <= (select max(seq) from t_temporaria)
begin
    set @comando = (select comando from t_temporaria where Seq = @cont);
    print @comando;
    exec sp_executesql @comando;
 
    set @cont = @cont + 1;
 
end;
 
select
*
from t_tabela_texto;
 
drop table t_temporaria;
drop table t_tabela_texto;
 
rollback;

