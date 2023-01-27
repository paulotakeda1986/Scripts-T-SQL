begin transaction

set xact_abort on;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Declare @flajuste001 bigint = 1, --Realiza ajuste nas parcelas que tem inscrição em dívida ativa, porém estão com a flag respectiva desmarcada;
		@flajuste002 bigint = 1, --Realiza ajustes nas parcelas de origem dos acordos, remontando as tabelas ParcelaDividaAtivaAcordo e DividaInclusaAcordo;
		@flajuste003 bigint = 1, --Realiza ajustes nas pessoas físicas, no tocante aos dados de RG;
		@flajuste004 bigint = 1, --Realiza ajustes nas observações dos imobiliários (urbanos e rurais);
		@flajuste005 bigint = 1, --Move final de vigência para receitas que estavam inativas no RECEITAS;
		@flajuste006 bigint = 1, --Deleta tributos e receitas que não estão sendo utilizadas em lançamentos da base de dados;
		@flajuste007 bigint = 1, --Cria extinção para parcelas com valores zerados;
		@flajuste008 bigint = 1, --Move a data de cancelamento para os lançamentos que possuem TODAS as parcelas extintas no tipo -18 (cancelamento de lançamento indevido);
		@flajuste009 bigint = 1, --Realiza tratamentos nos lançamentos de IPTU do exercício mais atual da base de dados migrada, criando apenas um grupo de opção de vencimento para os mesmos;
		@flajuste010 bigint = 1, --Atualiza Id da pessoa na tabela OperacaoBeneficioTribut para os casos onde existe o IdEconomico;
		@flajuste011 bigint = 1, --Atualiza tabela ParcelaLctoAcordo nos casos onde existem registros com a flag de inscrição em divida ativa marcadas, porém não tem registro na tabela InscricaoDividaAtiva;
		@flajuste012 bigint = 1; --Atualiza valores da tabela AcrescDescontoBaixa com valores de juros, multa, correção e desconto negativos para valores positivos;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste001 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Update
pla
set pla.FlInscritaDividaAtiva = 1
from ParcelaLctoAcordo pla
inner join InscricaoDividaAtiva ida on ida.IdParcelaLctoAcordo = pla.Id
where ida.DataEstornoInscricao is null and pla.FlInscritaDividaAtiva = 0;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste002 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Delete
pdaa
from AcordoReceita ar
inner join t_AcordoReceita tar on tar.Id = ar.Id
inner join ParcelaDividaAtivaAcordo pdaa on pdaa.IdAcordoReceita = ar.Id;

Delete
dia
from AcordoReceita ar
inner join t_AcordoReceita tar on tar.Id = ar.Id
inner join RequerimentoAcordo ra on ra.Id = ar.IdRequerimentoAcordo
inner join DividaInclusaAcordo dia on dia.IdRequerimentoAcordo = ra.Id;

set identity_insert ParcelaDividaAtivaAcordo on;

Insert into ParcelaDividaAtivaAcordo(
Id,
IdAcordoReceita,
IdParcelaLctoAcordo)
select
ROW_NUMBER()OVER(order by ar.Id) + isnull((select MAX(Id) from ParcelaDividaAtivaAcordo),0) as Id,
ar.Id as IdAcordoReceita,
stp.IdParcelaLctoAcordo
from AcordoReceita ar
inner join t_AcordoReceita tar on tar.Id = ar.Id
inner join DadosLctoAcordoReceita dlara on dlara.Id = ar.Id
inner join OpcaoVencimentoLctoAcordo ovlaa on ovlaa.IdDadosLctoAcordoReceita = dlara.Id
inner join ParcelaLctoAcordo plaa on plaa.IdOpcaoVencimentoLctoAcordo = ovlaa.Id
inner join SaldoTributoParcela stpa on stpa.IdParcelaLctoAcordo = plaa.Id
inner join VincParcAcordoComDebOrig vpa on vpa.IdSaldoTributoParcelaAcordo = stpa.Id
inner join SaldoTributoParcela stp on stp.Id = vpa.IdSaldoTributoParcelaOrigem
group by
ar.Id,
stp.IdParcelaLctoAcordo;

set identity_insert ParcelaDividaAtivaAcordo off;

Delete
dia
from AcordoReceita ar
inner join t_AcordoReceita tar on tar.Id = ar.Id
inner join RequerimentoAcordo ra on ra.Id = ar.IdRequerimentoAcordo
inner join DividaInclusaAcordo dia on dia.IdRequerimentoAcordo = ra.Id;

set identity_insert DividaInclusaAcordo on;

Insert into DividaInclusaAcordo(
Id,
IdRequerimentoAcordo,
IdParcelaLctoAcordo,
ValorTributo,
ValorDesconto,
ValorJuros,
ValorMulta,
ValorCorrecao,
ValorLiquidoParcela)
select
ROW_NUMBER()OVER(order by ar.IdRequerimentoAcordo) + isnull((select MAX(Id) from DividaInclusaAcordo),0) as Id,
ar.IdRequerimentoAcordo,
stp.IdParcelaLctoAcordo,
0 as ValorTributo,
0 as ValorDesconto,
0 as ValorJuros,
0 as ValorMulta,
0 as ValorCorrecao,
0 as ValorLiquidoParcela
from AcordoReceita ar
inner join t_AcordoReceita tar on tar.Id = ar.Id
inner join DadosLctoAcordoReceita dlara on dlara.Id = ar.Id
inner join OpcaoVencimentoLctoAcordo ovlaa on ovlaa.IdDadosLctoAcordoReceita = dlara.Id
inner join ParcelaLctoAcordo plaa on plaa.IdOpcaoVencimentoLctoAcordo = ovlaa.Id
inner join SaldoTributoParcela stpa on stpa.IdParcelaLctoAcordo = plaa.Id
inner join VincParcAcordoComDebOrig vpa on vpa.IdSaldoTributoParcelaAcordo = stpa.Id
inner join SaldoTributoParcela stp on stp.Id = vpa.IdSaldoTributoParcelaOrigem
group by
ar.IdRequerimentoAcordo,
stp.IdParcelaLctoAcordo;

set identity_insert DividaInclusaAcordo off;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste003 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Update PessoaFisica set RG = null where RG = '';

;with t as(
select
pf.Id
from PessoaFisica pf
where pf.RG is null or pf.DataEmissaoRG is null or pf.IdEstadoRG is null or pf.OrgaoEmissorRG is null or pf.DataEmissaoRG is null)
Update
pf
set pf.OrgaoEmissorRG = null,
	pf.IdEstadoRG = null,
	pf.DataEmissaoRG = null
from t
inner join PessoaFisica pf on pf.Id = t.Id
where pf.IdEstadoRG is not null and pf.RG is null;

;with t as(
select
pf.Id
from PessoaFisica pf
where pf.RG is null or pf.DataEmissaoRG is null or pf.IdEstadoRG is null or pf.OrgaoEmissorRG is null or pf.DataEmissaoRG is null)
Update
pf
set pf.OrgaoEmissorRG = 'SSP'
from t
inner join PessoaFisica pf on pf.Id = t.Id
where pf.RG is not null and pf.OrgaoEmissorRG is null;

;with t as(
select
pf.Id
from PessoaFisica pf
where pf.RG is null or pf.DataEmissaoRG is null or pf.IdEstadoRG is null or pf.OrgaoEmissorRG is null or pf.DataEmissaoRG is null)
Update
pf
set pf.IdEstadoRG = (select EstadoLocal from Parametros)
from t
inner join PessoaFisica pf on pf.Id = t.Id
where pf.RG is not null and pf.IdEstadoRG is null;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste004 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
set identity_insert ObservacaoImobiliario on;

Insert into ObservacaoImobiliario(
Id,
IdImobiliario,
Observacao,
DataObservacao)
select
ROW_NUMBER()OVER(order by imo.Id) + isnull((select MAX(Id) from ObservacaoImobiliario),0) as Id,
imo.Id as IdImobiliario,
'Cadastro de imobiliário.' as Observacao,
CAST('1900-01-02' as date) as DataObservacao
from Imobiliario imo
left join ObservacaoImobiliario oi on oi.IdImobiliario = imo.Id
where oi.IdImobiliario is null;

set identity_insert ObservacaoImobiliario off;

Update
oi
set oi.Observacao = 'Cadastro de imobiliário.'
from ObservacaoImobiliario oi
where oi.Observacao = '';
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste005 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Update
r
set r.DataFimVigencia = CAST('1900-01-02' as date)
from Receita r
inner join t_Receita tr on tr.Id = r.Id
inner join Receimpo impo on impo.IMPO_CODIGO = tr.CodigoAnterior
and impo.IMPO_TIPO = tr.DE_DA
where impo.IMPO_VERIFICACAO = 1;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste006 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Delete
cctv
from TributoVerba tv
inner join ConfigTributoXCodContab cctv on cctv.IdTributoVerba = tv.Id
left join ReceitaXTributoVerba rtv on rtv.IdTributoVerba = tv.Id
where rtv.IdTributoVerba is null;

Delete
tv
from TributoVerba tv
left join ReceitaXTributoVerba rtv on rtv.IdTributoVerba = tv.Id
where rtv.IdTributoVerba is null;

Delete
racb
from Receita r
inner join ReceitaAcordoConvBanc racb on racb.IdReceita = r.Id
left join ReceitaXTributoVerba rtv on rtv.IdReceita = r.Id
where rtv.IdReceita is null;

Delete
rr
from Receita r
inner join ReceitaXREFIS rr on rr.IdReceita = r.Id
left join ReceitaXTributoVerba rtv on rtv.IdReceita = r.Id
where rtv.IdReceita is null;

Delete
ar
from Receita r
inner join AcrescimosReceita ar on ar.IdReceita = r.Id
left join ReceitaXTributoVerba rtv on rtv.IdReceita = r.Id
where rtv.IdReceita is null;

Delete
rc
from Receita r
inner join RegraCalculo rc on rc.IdReceita = r.Id
left join ReceitaXTributoVerba rtv on rtv.IdReceita = r.Id
where rtv.IdReceita is null;

Delete
rtpa
from Receita r
inner join ReceitaXTipoAlvara rtpa on rtpa.IdReceita = r.Id
left join ReceitaXTributoVerba rtv on rtv.IdReceita = r.Id
where rtv.IdReceita is null;

Delete
r
from Receita r
left join ReceitaXTributoVerba rtv on rtv.IdReceita = r.Id
where rtv.IdReceita is null;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste007 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If exists(select top 1 1 from sys.tables where name = 't_Parcelas_Zeradas_Ativas_Filtro')
	Drop table t_Parcelas_Zeradas_Ativas_Filtro;

;with t as(
select
hstp.IdSaldoTributoParcela,
MAX(Sequencia) as Sequencia
from SaldoTributoParcela stp
inner join HSaldoTributoParcela hstp on hstp.IdSaldoTributoParcela = stp.Id
group by
hstp.IdSaldoTributoParcela)
select
distinct
dlar.Id as IdDadosLctoAcordoReceita,
p.NomeRazaoSocial,
dlar.Numero,
dlar.Exercicio,
pla.NumeroParcela,
hstp.Sequencia as Sequencia,
SUM(hstp.Valor) as Valor
into t_Parcelas_Zeradas_Ativas_Filtro
from DadosLctoAcordoReceita dlar
inner join SujeitoPassivoObrigacao spo on spo.IdDadosLctoAcordoReceita = dlar.Id
inner join Pessoa p on p.Id = spo.IdContribuinte
inner join LancamentoReceita lr on lr.Id = dlar.Id
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = dlar.Id
inner join OpcaoVencimento ov on ov.Id = ovla.IdOpcaoVencimento
inner join ParcelaLctoAcordo pla on pla.IdOpcaoVencimentoLctoAcordo = ovla.Id
inner join SaldoTributoParcela stp on stp.IdParcelaLctoAcordo = pla.Id
inner join HSaldoTributoParcela hstp on hstp.IdSaldoTributoParcela = stp.Id
inner join t on t.IdSaldoTributoParcela = stp.Id
and t.Sequencia = hstp.Sequencia
where pla.IdSituacaoParcelaLancamento = -1
group by
dlar.Id,
p.NomeRazaoSocial,
dlar.Numero,
dlar.Exercicio,
hstp.Sequencia,
pla.NumeroParcela
having
SUM(hstp.Valor) = 0
order by
p.NomeRazaoSocial;

If exists(select top 1 1 from sys.tables where name = 't_Parcelas_Zeradas_Ativas')
	Drop table t_Parcelas_Zeradas_Ativas;

;with t as(
select
hstp.IdSaldoTributoParcela,
MAX(Sequencia) as Sequencia
from SaldoTributoParcela stp
inner join HSaldoTributoParcela hstp on hstp.IdSaldoTributoParcela = stp.Id
group by
hstp.IdSaldoTributoParcela)
select
distinct
dlar.Id as IdDadosLctoAcordoReceita,
p.NomeRazaoSocial,
dlar.Numero,
dlar.Exercicio,
ovla.Id as IdOpcaoVencimentoLctoAcordo,
ov.Descricao as OpcaoVencimento,
pla.Id as IdParcelaLctoAcordo,
pla.NumeroParcela,
hstp.Sequencia as Sequencia,
SUM(hstp.Valor) as Valor
into t_Parcelas_Zeradas_Ativas
from DadosLctoAcordoReceita dlar
inner join SujeitoPassivoObrigacao spo on spo.IdDadosLctoAcordoReceita = dlar.Id
inner join Pessoa p on p.Id = spo.IdContribuinte
inner join LancamentoReceita lr on lr.Id = dlar.Id
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = dlar.Id
inner join OpcaoVencimento ov on ov.Id = ovla.IdOpcaoVencimento
inner join ParcelaLctoAcordo pla on pla.IdOpcaoVencimentoLctoAcordo = ovla.Id
inner join SaldoTributoParcela stp on stp.IdParcelaLctoAcordo = pla.Id
inner join HSaldoTributoParcela hstp on hstp.IdSaldoTributoParcela = stp.Id
inner join t on t.IdSaldoTributoParcela = stp.Id
and t.Sequencia = hstp.Sequencia
inner join t_Parcelas_Zeradas_Ativas_Filtro pzaf on pzaf.NumeroParcela = pla.NumeroParcela
and pzaf.IdDadosLctoAcordoReceita = dlar.Id
and pzaf.Sequencia = hstp.Sequencia
where pla.IdSituacaoParcelaLancamento = -1
group by
dlar.Id,
p.NomeRazaoSocial,
dlar.Numero,
dlar.Exercicio,
ovla.Id,
pla.Id,
hstp.Sequencia,
ov.Descricao,
pla.NumeroParcela
having
SUM(hstp.Valor) = 0;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If Exists(select top 1 1 from sys.tables where name like 't_LoteExtincaoCreditoTrib_Valores_Zerados')
	Drop table t_LoteExtincaoCreditoTrib_Valores_Zerados;
	
Select
*
into t_LoteExtincaoCreditoTrib_Valores_Zerados
from LoteExtincaoCreditoTrib
Where Id = -1000000;

If exists(select top 1 1 from sys.tables where name = 't_max_Numero_Lote')
	Drop table t_max_Numero_Lote;

select
IdUnidadeGestora
,isnull(max(NumeroLote),0) as NumeroLote
,Exercicio
into t_max_Numero_Lote
from LoteExtincaoCreditoTrib lect
group by
IdUnidadeGestora
,Exercicio;

set identity_insert t_LoteExtincaoCreditoTrib_Valores_Zerados on;

Insert Into t_LoteExtincaoCreditoTrib_Valores_Zerados(
Id
,IdUnidadeGestora
,IdUsuario
,IdTipoSitLoteArrecadTrib
,IdTipoLoteExtincao
,IdContaBancariaCaixa
,NumeroLote
,Exercicio
,IdLoteCobrancaBancaria
,QuantidadeExtincoesArquiv
,QuantidadeExtincoesSucess
,IdConvenioBancario
,NomeArquivoRetornoBanco
,LinhaCabecalho
,DataGeracaoArquivo)
values(
(select MAX(Id) from LoteExtincaoCreditoTrib) + 1 --Id
,dbo.fn_retorna_parametro('IdUnidadeGestora') --IdUnidadeGestora
,dbo.fn_retorna_parametro('IdUsuario') --IdUsuario
,null --IdTipoSitLoteArrecadTrib
,-3 --IdTipoLoteExtincao
,null --IdContaBancariaCaixa
,(select MAX(NumeroLote) + 1 from LoteExtincaoCreditoTrib where Exercicio = 2000) --NumeroLote
,2000 --Exercicio
,null --IdLoteCobrancaBancaria
,0 --QuantidadeExtincoesArquiv
,0 --QuantidadeExtincoesSucess
,null --IdConvenioBancario
,null --NomeArquivoRetornoBanco
,null --LinhaCabecalho
,cast('2000-01-02' as date)); --DataGeracaoArquivo)

set identity_insert t_LoteExtincaoCreditoTrib_Valores_Zerados off;

set identity_insert LoteExtincaoCreditoTrib on;

Insert Into LoteExtincaoCreditoTrib(
Id
,IdUnidadeGestora
,IdUsuario
,IdTipoSitLoteArrecadTrib
,IdTipoLoteExtincao
,IdContaBancariaCaixa
,NumeroLote
,Exercicio
,IdLoteCobrancaBancaria
,QuantidadeExtincoesArquiv
,QuantidadeExtincoesSucess
,IdConvenioBancario
,NomeArquivoRetornoBanco
,LinhaCabecalho
,DataGeracaoArquivo)
Select
Id
,IdUnidadeGestora
,IdUsuario
,IdTipoSitLoteArrecadTrib
,IdTipoLoteExtincao
,IdContaBancariaCaixa
,NumeroLote
,Exercicio
,IdLoteCobrancaBancaria
,QuantidadeExtincoesArquiv
,QuantidadeExtincoesSucess
,IdConvenioBancario
,NomeArquivoRetornoBanco
,LinhaCabecalho
,DataGeracaoArquivo
from t_LoteExtincaoCreditoTrib_Valores_Zerados;

set identity_insert LoteExtincaoCreditoTrib off;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO SituacaoLoteExtincao (
  IdLoteExtincaoCreditoTrib,
  IdUsuario,
  IdTipoSitLoteArrecadTrib,
  DataHoraRegistro,
  Observacao
)
SELECT
  LECT.Id IdLoteExtincaoCreditoTrib,
  dbo.fn_retorna_parametro('IdUsuario'),
  -1 IdTipoSitLoteArrecadTrib,
  CAST(CONCAT(lect.Exercicio,'-01-01') as date) DataHoraRegistro,
  'Situação criada durante cópia de dados de sistema legado (Cancelamento de débitos).' Observacao
FROM t_LoteExtincaoCreditoTrib_Valores_Zerados LECT;

INSERT INTO SituacaoLoteExtincao (
  IdLoteExtincaoCreditoTrib,
  IdUsuario,
  IdTipoSitLoteArrecadTrib,
  DataHoraRegistro,
  Observacao
)
SELECT
  LECT.Id IdLoteExtincaoCreditoTrib,
  dbo.fn_retorna_parametro('IdUsuario'),
  -2 IdTipoSitLoteArrecadTrib,
  dateadd(DAY,1,CAST(CONCAT(lect.Exercicio,'-01-01') as date)) DataHoraRegistro,
  'Situação criada durante cópia de dados de sistema legado (Cancelamento de débitos).' Observacao
FROM t_LoteExtincaoCreditoTrib_Valores_Zerados LECT;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If Exists(select top 1 1 from sys.tables where name like 't_ExtincaoCreditoEntidade_Valores_Zerados')
	Drop table t_ExtincaoCreditoEntidade_Valores_Zerados;

Select
*
,CAST(null as bigint) as FlParcelaBaixaAntecipada
,CAST(null as bigint) as FlInscritaDividaAtiva
,CAST(null as bigint) as IdSituacaoParcelaLancamento
,CAST(null as bigint) as IdParcelaLctoAcordo
,CAST(null as bigint) as Sequencia
into t_ExtincaoCreditoEntidade_Valores_Zerados
from ExtincaoCreditoEntidade
Where Id = -1000000;

set identity_insert t_ExtincaoCreditoEntidade_Valores_Zerados on;

-------- Inserindo extinções por cancelamento
Insert Into t_ExtincaoCreditoEntidade_Valores_Zerados(
Id
,IdUsuario
,IdLoteExtincaoCreditoTrib
,IdTipoExtincaoCreditoTrib
,Observacao
,DataExtincao
,DataHoraRegistro
,ValorExtinto
,IdParcelaLctoAcordo
,FlParcelaBaixaAntecipada
,FlInscritaDividaAtiva
,IdSituacaoParcelaLancamento
,Sequencia)
select
ROW_NUMBER()OVER(order by tpla.IdParcelaLctoAcordo) + (select MAX(Id) from ExtincaoCreditoEntidade) as Id
,dbo.fn_retorna_parametro('IdUsuario') as IdUsuario
,(select Id from t_LoteExtincaoCreditoTrib_Valores_Zerados) as IdLoteExtincaoCreditoTrib
,-17 as IdTipoExtincaoCreditoTrib
,'Baixa de parcelas com valores totalmente zerados ainda ativas.' as Oservacao
,CAST('2000-01-02' as date) as DataExtincao
,CAST('2000-01-02' as date) as DataHoraRegistro
,0 as ValorExtinto
,tpla.IdParcelaLctoAcordo as IdParcelaLctoAcordo
,pla.FlBaixaAntecipada
,pla.FlInscritaDividaAtiva
,pla.IdSituacaoParcelaLancamento
,tpla.Sequencia as Sequencia
from t_Parcelas_Zeradas_Ativas tpla
inner join ParcelaLctoAcordo pla on pla.Id = tpla.IdParcelaLctoAcordo;

set identity_insert t_ExtincaoCreditoEntidade_Valores_Zerados off;

set identity_insert ExtincaoCreditoEntidade on;

Insert Into ExtincaoCreditoEntidade(
Id
,IdUsuario
,IdLoteExtincaoCreditoTrib
,IdTipoExtincaoCreditoTrib
,Observacao
,DataExtincao
,DataCredito
,DataHoraRegistro
,ValorExtinto)
Select
a.Id
,a.IdUsuario
,a.IdLoteExtincaoCreditoTrib
,a.IdTipoExtincaoCreditoTrib
,a.Observacao
,a.DataExtincao
,a.DataCredito
,a.DataHoraRegistro
,a.ValorExtinto
From t_ExtincaoCreditoEntidade_Valores_Zerados a;

set identity_insert ExtincaoCreditoEntidade off;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If Exists(select top 1 1 from sys.tables where name like 't_BaixaParcelaTributaria_Valores_Zerados')
	Drop table t_BaixaParcelaTributaria_Valores_Zerados;

Select
*
into t_BaixaParcelaTributaria_Valores_Zerados
from BaixaParcelaTributaria
Where Id = -1000000;

set identity_insert t_BaixaParcelaTributaria_Valores_Zerados on;

Insert Into t_BaixaParcelaTributaria_Valores_Zerados(
Id
,IdExtincaoCreditoEntidade
,IdParcelaLctoAcordo
,FlBaixaCancelada
,FlParcelaBaixaAntecipada
,FlInscritaDividaAtiva
,IdSituacaoParcelaLancamento)
Select
ROW_NUMBER()OVER(order by Id) + (select max(Id) from BaixaParcelaTributaria) as Id
,Id
,IdParcelaLctoAcordo
,0
,0
,ece.FlInscritaDividaAtiva
,ece.IdSituacaoParcelaLancamento
from t_ExtincaoCreditoEntidade_Valores_Zerados ece;

set identity_insert t_BaixaParcelaTributaria_Valores_Zerados off;

set identity_insert BaixaParcelaTributaria on;

Insert Into BaixaParcelaTributaria(
Id
,IdExtincaoCreditoEntidade
,IdParcelaLctoAcordo
,FlBaixaCancelada
,FlParcelaBaixaAntecipada
,FlInscritaDividaAtiva
,IdSituacaoParcelaLancamento)
Select
Id
,IdExtincaoCreditoEntidade
,IdParcelaLctoAcordo
,FlBaixaCancelada
,FlParcelaBaixaAntecipada
,FlInscritaDividaAtiva
,IdSituacaoParcelaLancamento
From t_BaixaParcelaTributaria_Valores_Zerados;

set identity_insert BaixaParcelaTributaria off;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If Exists(select top 1 1 from sys.tables where name like 't_BaixaParcelaXTribRec_Valores_Zerados')
	Drop table t_BaixaParcelaXTribRec_Valores_Zerados;

Select
*
into t_BaixaParcelaXTribRec_Valores_Zerados
from BaixaParcelaXTribRec
Where Id = -1000000;

set identity_insert t_BaixaParcelaXTribRec_Valores_Zerados on;

Insert Into t_BaixaParcelaXTribRec_Valores_Zerados(
Id
,IdBaixaParcelaTributaria
,IdSaldoTributoParcela
,Valor
,ValorDiferenca
,FlOriginalInscritaDivAtiv)
Select
ROW_NUMBER()OVER(order by bpt.Id) + (select MAX(Id) from BaixaParcelaXTribRec)
,bpt.Id
,stp.Id
,hstp.Valor
,0 as ValorDiferenca
,0
from t_BaixaParcelaTributaria_Valores_Zerados bpt
inner join t_Parcelas_Zeradas_Ativas pza on pza.IdParcelaLctoAcordo = bpt.IdParcelaLctoAcordo
inner join SaldoTributoParcela stp on stp.IdParcelaLctoAcordo = bpt.IdParcelaLctoAcordo
inner join HSaldoTributoParcela hstp on hstp.IdSaldoTributoParcela = stp.Id
and hstp.Sequencia = pza.Sequencia;

set identity_insert t_BaixaParcelaXTribRec_Valores_Zerados off;

set identity_insert BaixaParcelaXTribRec on;

Insert Into BaixaParcelaXTribRec(
Id
,IdBaixaParcelaTributaria
,IdSaldoTributoParcela
,Valor
,ValorDiferenca
,FlOriginalInscritaDivAtiv)
Select
Id
,IdBaixaParcelaTributaria
,IdSaldoTributoParcela
,Valor
,ValorDiferenca
,FlOriginalInscritaDivAtiv
From t_BaixaParcelaXTribRec_Valores_Zerados;

set identity_insert BaixaParcelaXTribRec off;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If Exists(select top 1 1 from sys.tables where name like 't_ValorCalculadoAntesBaixa_Valores_Zerados')
	Drop table t_ValorCalculadoAntesBaixa_Valores_Zerados;

Select
*
into t_ValorCalculadoAntesBaixa_Valores_Zerados
from ValorCalculadoAntesBaixa
Where Id = -1000000;

Insert Into t_ValorCalculadoAntesBaixa_Valores_Zerados(
Id
,ValorTributo
,DescontoValorTributo
,BeneficioValorTributo
,ValorJuros
,DescontoValorJuros
,BeneficioValorJuros
,ValorMulta
,DescontoValorMulta
,BeneficioValorMulta
,ValorCorrecao
,DescontoValorCorrecao
,BeneficioValorCorrecao)
select
bplt.Id as Id
,0 as Valor
,0 as DescontoValorTributo
,0 as BeneficioValorTributo
,0 as ValorJuros
,0 as ValorDescontoJuros
,0 as ValorBeneficioJuros
,0 as ValorMulta
,0 as ValorDescontoMulta
,0 as ValorBeneficioMulta
,0 as ValorCorrecao
,0 as ValorDescontoCorrecao
,0 as ValorBeneficioCorrecao
from t_BaixaParcelaXTribRec_Valores_Zerados bplt;

Insert Into ValorCalculadoAntesBaixa(
Id
,ValorTributo
,DescontoValorTributo
,BeneficioValorTributo
,ValorJuros
,DescontoValorJuros
,BeneficioValorJuros
,ValorMulta
,DescontoValorMulta
,BeneficioValorMulta
,ValorCorrecao
,DescontoValorCorrecao
,BeneficioValorCorrecao)
Select
Id
,ValorTributo
,DescontoValorTributo
,BeneficioValorTributo
,ValorJuros
,DescontoValorJuros
,BeneficioValorJuros
,ValorMulta
,DescontoValorMulta
,BeneficioValorMulta
,ValorCorrecao
,DescontoValorCorrecao
,BeneficioValorCorrecao
From t_ValorCalculadoAntesBaixa_Valores_Zerados;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Update
pla
set pla.IdSituacaoParcelaLancamento = -4
from t_Parcelas_Zeradas_Ativas pza
inner join ParcelaLctoAcordo pla on pla.Id = pza.IdParcelaLctoAcordo;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste008 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin

set xact_abort on;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If exists(select top 1 1 from sys.tables where name = 't_Lancamentos_totais_parcelas01')
	Drop table t_Lancamentos_totais_parcelas01;

select
dlar.Id as IdDadosLctoAcordoReceita, 
dlar.Numero,
dlar.Exercicio,
count(*) as QuantidadeTotalParcelas
into t_Lancamentos_totais_parcelas01
from LancamentoReceita lr
inner join Receita r on r.Id = lr.IdReceita
inner join DadosLctoAcordoReceita dlar on dlar.Id = lr.Id
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = dlar.Id
inner join ParcelaLctoAcordo pla on pla.IdOpcaoVencimentoLctoAcordo = ovla.Id
group by
dlar.Id, 
dlar.Numero,
dlar.Exercicio;

If exists(select top 1 1 from sys.tables where name = 't_Lancamentos_totais_parcelas02')
	Drop table t_Lancamentos_totais_parcelas02;

select
dlar.Id as IdDadosLctoAcordoReceita, 
dlar.Numero,
dlar.Exercicio,
count(*) as QuantidadeTotalParcelas
into t_Lancamentos_totais_parcelas02
from LancamentoReceita lr
inner join Receita r on r.Id = lr.IdReceita
inner join DadosLctoAcordoReceita dlar on dlar.Id = lr.Id
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = dlar.Id
inner join ParcelaLctoAcordo pla on pla.IdOpcaoVencimentoLctoAcordo = ovla.Id
where pla.IdSituacaoParcelaLancamento = -3
group by
dlar.Id, 
dlar.Numero,
dlar.Exercicio;

;with t as(
select
tlp1.*
from t_Lancamentos_totais_parcelas01 tlp1
inner join t_Lancamentos_totais_parcelas02 tlp2 on tlp1.IdDadosLctoAcordoReceita = tlp2.IdDadosLctoAcordoReceita
and tlp1.QuantidadeTotalParcelas = tlp2.QuantidadeTotalParcelas)
Update
ovla
set ovla.IdEstadoOpcaoVencimento = -3
from t
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = t.IdDadosLctoAcordoReceita
where ovla.IdEstadoOpcaoVencimento <> -3;

If exists(select top 1 1 from sys.tables where name = 't_Lancamentos_totais_parcelas03')
	Drop table t_Lancamentos_totais_parcelas03;

select
dlar.Id as IdDadosLctoAcordoReceita, 
dlar.Numero,
dlar.Exercicio,
count(*) as QuantidadeTotalParcelas
into t_Lancamentos_totais_parcelas03
from LancamentoReceita lr
inner join Receita r on r.Id = lr.IdReceita
inner join DadosLctoAcordoReceita dlar on dlar.Id = lr.Id
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = dlar.Id
inner join ParcelaLctoAcordo pla on pla.IdOpcaoVencimentoLctoAcordo = ovla.Id
inner join BaixaParcelaTributaria bpt on bpt.IdParcelaLctoAcordo = pla.Id
inner join ExtincaoCreditoEntidade ece on ece.Id = bpt.IdExtincaoCreditoEntidade
where pla.IdSituacaoParcelaLancamento = -4 and ece.IdTipoExtincaoCreditoTrib in (-18,-6)
group by
dlar.Id, 
dlar.Numero,
dlar.Exercicio;

;with t as(
select
tlp1.*
from t_Lancamentos_totais_parcelas01 tlp1
inner join t_Lancamentos_totais_parcelas03 tlp3 on tlp1.IdDadosLctoAcordoReceita = tlp3.IdDadosLctoAcordoReceita
and tlp1.QuantidadeTotalParcelas = tlp3.QuantidadeTotalParcelas)
Update
dlar
set dlar.DataCancelamento = dlar.DataLancamentoAcordo,
	dlar.IdMotivoCancelamento = -1,
	dlar.IdUsuarioCancelamento = (select min(Id) from Usuario),
	dlar.ObsCancelamento = 'Cancelamento de Lançamento (**********).'
from t
inner join DadosLctoAcordoReceita dlar on dlar.Id = t.IdDadosLctoAcordoReceita
where dlar.DataCancelamento is null;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste009 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin

set xact_abort on;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Declare @Exercicio bigint = (select max(IPTU_EXERCICIO) from receiptu);
Declare @IdRegraCalculo bigint = (select rc.Id from t_Receita tr inner join RegraCalculo rc on rc.IdReceita = tr.Id inner join Receiptu iptu on iptu.IPTU_IMPOSTO = tr.CodigoAnterior and tr.DE_DA = 1 and iptu.IPTU_EXERCICIO = @Exercicio)
		
If exists(select top 1 1 from sys.tables where name = 't_DadosLctoAcordoReceita_ajuste01')
	Drop table t_DadosLctoAcordoReceita_ajuste01;

select
ovla.IdDadosLctoAcordoReceita,
dlar.Numero,
dlar.Exercicio,
dlar.DataCancelamento,
dlar.IdUsuarioCancelamento,
dlar.IdMotivoCancelamento,
dlar.ObsCancelamento,
ovla.Id as IdOpcaoVencimentoLctoAcordo,
ovla.IdOpcaoVencimento,
cast('0' as bigint) as FlOpcaoVencimentoPaga,
cast('0' as bigint) as FlOpcaoVencimentoCanc,
ovla.IdGrupoOpVencTributoRegra,
cast(null as bigint) as IdGrupoOpVencTributoRegraNovo,
ovla.IdEstadoOpcaoVencimento,
cast(null as bigint) as IdEstadoOpcaoVencimentoNova
into t_DadosLctoAcordoReceita_ajuste01
from LancamentoReceita lr
inner join MemoriaCalculo mc on mc.Id = lr.IdMemoriaCalculo
inner join DadosLctoAcordoReceita dlar on dlar.Id = lr.Id
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = dlar.Id
where mc.IdRegraCalculo = @IdRegraCalculo and lr.Exercicio = @Exercicio;

;with t as(
select
IdDadosLctoAcordoReceita,
min(IdGrupoOpVencTributoRegra) as IdGrupoOpVencTributoRegra
from t_DadosLctoAcordoReceita_ajuste01
group by IdDadosLctoAcordoReceita)
Update
tdlar
set tdlar.IdGrupoOpVencTributoRegraNovo = t.IdGrupoOpVencTributoRegra
from t_DadosLctoAcordoReceita_ajuste01 tdlar
inner join t on t.IdDadosLctoAcordoReceita = tdlar.IdDadosLctoAcordoReceita;

Update
tdlar
set tdlar.FlOpcaoVencimentoPaga = 1
from t_DadosLctoAcordoReceita_ajuste01 tdlar
inner join ParcelaLctoAcordo pla on pla.IdOpcaoVencimentoLctoAcordo = tdlar.IdOpcaoVencimentoLctoAcordo
inner join BaixaParcelaTributaria bpt on bpt.IdParcelaLctoAcordo = pla.Id
inner join ExtincaoCreditoEntidade ece on ece.Id = bpt.IdExtincaoCreditoEntidade
where ece.IdTipoExtincaoCreditoTrib = -1 and pla.IdSituacaoParcelaLancamento = -4;

Update
tdlar
set tdlar.FlOpcaoVencimentoCanc = 1
from t_DadosLctoAcordoReceita_ajuste01 tdlar
inner join ParcelaLctoAcordo pla on pla.IdOpcaoVencimentoLctoAcordo = tdlar.IdOpcaoVencimentoLctoAcordo
inner join BaixaParcelaTributaria bpt on bpt.IdParcelaLctoAcordo = pla.Id
inner join ExtincaoCreditoEntidade ece on ece.Id = bpt.IdExtincaoCreditoEntidade
where ece.IdTipoExtincaoCreditoTrib <> -1 and pla.IdSituacaoParcelaLancamento = -4;

Delete from t_DadosLctoAcordoReceita_ajuste01 where DataCancelamento is not null;

--select
--IdDadosLctoAcordoReceita,
--sum(FlOpcaoVencimentoPaga) as contapagamentos
--from t_DadosLctoAcordoReceita_ajuste01
--group by
--IdDadosLctoAcordoReceita
--having sum(FlOpcaoVencimentoPaga) > 1
--order by
--IdDadosLctoAcordoReceita;

If exists(select top 1 1 from sys.tables where name = 't_DadosLctoAcordoReceita_ajuste02')
	Drop table t_DadosLctoAcordoReceita_ajuste02;

;with t as(
select
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo,
sum(FlOpcaoVencimentoPaga) as contapagamentos
from t_DadosLctoAcordoReceita_ajuste01
group by
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo
having sum(FlOpcaoVencimentoPaga) = 0)
select
tdlar.*
into t_DadosLctoAcordoReceita_ajuste02
from t
inner join t_DadosLctoAcordoReceita_ajuste01 tdlar on tdlar.IdDadosLctoAcordoReceita = t.IdDadosLctoAcordoReceita
where tdlar.IdEstadoOpcaoVencimento = -1
order by tdlar.Exercicio,tdlar.Numero;

;with t as(
select
Numero,
Exercicio
from t_DadosLctoAcordoReceita_ajuste02 tdlar2
group by
Numero,
Exercicio
having count(*) > 1)
Delete
tdlar
from t_DadosLctoAcordoReceita_ajuste01 tdlar
inner join t on t.Numero = tdlar.Numero
and t.Exercicio = tdlar.Exercicio;

;with t as(
select
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo,
sum(FlOpcaoVencimentoPaga) as contapagamentos
from t_DadosLctoAcordoReceita_ajuste01
group by
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo
having sum(FlOpcaoVencimentoPaga) = 0)
Update
ovla
set ovla.IdGrupoOpVencTributoRegra = t.IdGrupoOpVencTributoRegraNovo
from t
inner join t_DadosLctoAcordoReceita_ajuste01 tdlar on tdlar.IdDadosLctoAcordoReceita = t.IdDadosLctoAcordoReceita
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = tdlar.IdDadosLctoAcordoReceita;

If exists(select top 1 1 from sys.tables where name = 't_DadosLctoAcordoReceita_ajuste03')
	Drop table t_DadosLctoAcordoReceita_ajuste03;

;with t as(
select
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo,
sum(FlOpcaoVencimentoPaga) as contapagamentos
from t_DadosLctoAcordoReceita_ajuste01
group by
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo
having sum(FlOpcaoVencimentoPaga) = 1)
select
tdlar.*
into t_DadosLctoAcordoReceita_ajuste03
from t
inner join t_DadosLctoAcordoReceita_ajuste01 tdlar on tdlar.IdDadosLctoAcordoReceita = t.IdDadosLctoAcordoReceita
where tdlar.IdEstadoOpcaoVencimento = -1
order by tdlar.Exercicio,tdlar.Numero;

;with t as(
select
Numero,
Exercicio
from t_DadosLctoAcordoReceita_ajuste03
group by
Numero,
Exercicio
having count(*) > 1)
Delete
tdlar
from t_DadosLctoAcordoReceita_ajuste01 tdlar
inner join t on t.Numero = tdlar.Numero
and t.Exercicio = tdlar.Exercicio;;

;with t as(
select
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo,
sum(FlOpcaoVencimentoPaga) as contapagamentos
from t_DadosLctoAcordoReceita_ajuste01
group by
IdDadosLctoAcordoReceita,
IdGrupoOpVencTributoRegraNovo
having sum(FlOpcaoVencimentoPaga) = 1)
Update
ovla
set ovla.IdGrupoOpVencTributoRegra = t.IdGrupoOpVencTributoRegraNovo
from t
inner join t_DadosLctoAcordoReceita_ajuste01 tdlar on tdlar.IdDadosLctoAcordoReceita = t.IdDadosLctoAcordoReceita
inner join OpcaoVencimentoLctoAcordo ovla on ovla.IdDadosLctoAcordoReceita = tdlar.IdDadosLctoAcordoReceita;

Create table t_DadosLctoAcordoReceita_inconsistentes01(
Numero bigint not null,
Exercicio bigint not null);

Insert into t_DadosLctoAcordoReceita_inconsistentes01(
Numero,
Exercicio)
select
Numero,
Exercicio
from t_DadosLctoAcordoReceita_ajuste02 tdlar2
group by
Numero,
Exercicio
having count(*) > 1
union
select
Numero,
Exercicio
from t_DadosLctoAcordoReceita_ajuste03
group by
Numero,
Exercicio
having count(*) > 1;

select
*
from t_DadosLctoAcordoReceita_inconsistentes01;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste010 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin

set xact_abort on;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Update
obt
set obt.IdPessoaContribuinte = e.IdFornecedor
from OperacaoBeneficioTribut obt
inner join Economico e on e.Id = obt.IdEconomico
where obt.IdEconomico is not null and obt.IdPessoaContribuinte is null;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste011 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin

set xact_abort on;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Update
pla
set pla.FlInscritaDividaAtiva = 0
from ParcelaLctoAcordo pla
left join InscricaoDividaAtiva ida on ida.IdParcelaLctoAcordo = pla.Id
where pla.FlInscritaDividaAtiva = 1 and ida.IdParcelaLctoAcordo is null;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If @flajuste012 = 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
begin

set xact_abort on;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
If exists(
select
top 1 1
from AcrescDescontoBaixa adb
inner join TipoVincValoresMonetarios tvvm on tvvm.Id = adb.IdTipoVincValoresMonetarios
where tvvm.FlDesconto = 1
and (adb.ValorJuros < 0 or adb.ValorMulta < 0 or adb.ValorCorrecao < 0 or adb.ValorDesconto < 0))

begin

Update
adb
set adb.ValorJuros = adb.ValorJuros * (-1)
from AcrescDescontoBaixa adb
inner join TipoVincValoresMonetarios tvvm on tvvm.Id = adb.IdTipoVincValoresMonetarios
where tvvm.FlDesconto = 1
and adb.ValorJuros < 0;

Update
adb
set adb.ValorMulta = adb.ValorMulta * (-1)
from AcrescDescontoBaixa adb
inner join TipoVincValoresMonetarios tvvm on tvvm.Id = adb.IdTipoVincValoresMonetarios
where tvvm.FlDesconto = 1
and adb.ValorMulta < 0;

Update
adb
set adb.ValorCorrecao = adb.ValorCorrecao * (-1)
from AcrescDescontoBaixa adb
inner join TipoVincValoresMonetarios tvvm on tvvm.Id = adb.IdTipoVincValoresMonetarios
where tvvm.FlDesconto = 1
and adb.ValorCorrecao < 0;

Update
adb
set adb.ValorDesconto = adb.ValorDesconto * (-1)
from AcrescDescontoBaixa adb
inner join TipoVincValoresMonetarios tvvm on tvvm.Id = adb.IdTipoVincValoresMonetarios
where tvvm.FlDesconto = 1
and adb.ValorDesconto < 0;

end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--If @flajuste008 = 1
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--begin

--set xact_abort on;
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--end;
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
commit;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------