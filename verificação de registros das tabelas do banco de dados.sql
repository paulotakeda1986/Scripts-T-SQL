begin transaction

set xact_abort on;

If exists(select top 1 1 from sys.tables where name = 't_verificacao_DB_Atual')
	Drop table t_verificacao_DB_Atual;

create table t_verificacao_DB_Atual(
nometabela varchar(max) not null,
quantidaderegistros bigint not null default (0));

select
row_number()over(order by name) as seq,
concat('insert into t_verificacao_DB_Atual(nometabela, quantidaderegistros) select ''',st.name,''' ,count(*) from ',st.name,';') as comandocontar
into #temporaria
from sys.tables st
where st.type_desc = 'USER_TABLE' and name not in ('ControleSequencialExtracao','ExtratorGeradorSequencia','SaldoContaContabilTCE','SequenciaExtracao','TabelaChaveSequenciaExtracao')
order by name;

declare @cont bigint = 1,
		@comando nvarchar(max);

while @cont <= (select max(seq) from #temporaria)
begin

	set @comando = (select comandocontar from #temporaria t where t.seq = @cont);
	exec sp_executesql @comando;

	set @cont = @cont + 1;

end;

select * from t_verificacao_DB_Atual;

commit;