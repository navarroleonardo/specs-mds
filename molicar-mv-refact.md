# Requisito: View Estável para Materialized Views

## Contexto

A função `dbaprd1.sp_normalize_molicar` executa um hot swap atômico na tabela fato `dbaprd1.tAvalcTbelaMlcar`. O swap renomeia a tabela, suas 27 partições e a primary key (sufixo `_bkp` na tabela antiga, remoção do sufixo `_new` na shadow).

As materialized views que consultam a tabela fato guardam a dependência por OID interno, não por nome. Após o swap, o OID referenciado continua apontando para a tabela antiga (agora `_bkp`), causando:

1. Perda de dados nas materialized views após refresh
2. Exceção após a segunda execução, quando a tabela `_bkp` é dropada

## Objetivo

Eliminar a dependência por OID introduzindo uma view estável entre a tabela fato e as materialized views, sem indisponibilidade de consultas em produção e preservando backup e rollback.

## Solução

Criar a view `dbaprd1.vw_tAvalcTbelaMlcar` como camada de indireção. A view mantém OID estável independente dos swaps da tabela fato. As materialized views passam a consultar a view; o backend Java permanece inalterado (resolve nome por execução).

## Mudanças por arquivo

### 01-ddl.sql

Adicionar criação da view estável após a criação da tabela fato `dbaprd1.tAvalcTbelaMlcar`:

```sql
CREATE OR REPLACE VIEW dbaprd1.vw_tAvalcTbelaMlcar AS
SELECT * FROM dbaprd1.tAvalcTbelaMlcar;
```

### 04-sp-normalize.sql

Na etapa 7 (table swap atômico), após os renames que tornam a shadow a tabela oficial, adicionar o reapontamento atômico da view, dentro da mesma transação do swap:

```sql
-- Ao final da etapa 7, após fato_new virar fato
CREATE OR REPLACE VIEW dbaprd1.vw_tAvalcTbelaMlcar AS
SELECT * FROM dbaprd1.tAvalcTbelaMlcar;
```

Justificativa: como o swap mantém o nome final `tAvalcTbelaMlcar`, o `CREATE OR REPLACE VIEW` garante que a view aponte para a tabela ativa correta, preservando seu próprio OID e, consequentemente, as dependências das materialized views.

### 05-materialized-views.sql

Alterar a fonte de dados de cada materialized view, trocando `dbaprd1.tAvalcTbelaMlcar` por `dbaprd1.vw_tAvalcTbelaMlcar`. Os joins com tabelas de dimensão (marcas, modelos, configurações) permanecem inalterados, pois essas tabelas sofrem upsert e mantêm OID estável.

Materialized views afetadas:
- `dbaprd1.mv_fipe_para_mlcar`
- `dbaprd1.mv_modelos_por_tipo_ano_marca`
- `dbaprd1.mv_marcas_por_tipo_ano`
- `dbaprd1.mv_anos_por_tipo`

### 06-grants.sql

Conceder permissão de SELECT na nova view ao usuário sistêmico, mantendo o princípio de menor privilégio:

```sql
GRANT SELECT ON dbaprd1.vw_tAvalcTbelaMlcar TO <usuario_sistemico>;
```

## Critérios de validação

1. Após duas execuções consecutivas da carga, as materialized views devem conter dados corretos e atualizados, sem exceção de tabela inexistente.
2. Consultas do backend Java durante e após o swap retornam dados consistentes sem erro.
3. O rollback automático existente continua funcional: ao restaurar `tAvalcTbelaMlcar` a partir de `_bkp`, a view deve ser reapontada para a tabela restaurada.
4. Nenhuma indisponibilidade de leitura percebida pelo cliente durante o swap.

## Considerações de rollback

O fluxo de rollback existente, ao reverter o swap, deve incluir o reapontamento da view para a tabela restaurada:

```sql
CREATE OR REPLACE VIEW dbaprd1.vw_tAvalcTbelaMlcar AS
SELECT * FROM dbaprd1.tAvalcTbelaMlcar;
```

Como o rollback restaura o nome `tAvalcTbelaMlcar`, o reapontamento é idempotente e seguro.

## Restrições

- O schema de colunas da tabela `tAvalcTbelaMlcar` deve permanecer idêntico entre versões. Alteração de colunas exige atualização coordenada da view e das materialized views, pois `CREATE OR REPLACE VIEW` falha se a lista de colunas mudar de forma incompatível.
- Toda a estrutura permanece no schema `dbaprd1`.
- Arquivos DDL e grants executados com usuário `pg_admin`; função e consultas executadas com usuário sistêmico, mantendo `SECURITY DEFINER` na função.