-- exercicio 1
-- o usuário precisa ter o privilégio "CREATE PUBLIC SYNONYM"
    
CREATE PUBLIC SYNONYM notas    
FOR REGISTRO.historico_escolar;

-- exercício 2
-- comandos do dba ***corrigir
GRANT SELECT ON RH.vw_salarios_gerais TO usuario_auditoria;
CREATE PUBLIC SYNONYM salarios FOR RH.vw_salarios_gerais;

-- comando do usuario_auditoria
SELECT * FROM salarios;

-- exercício 3
-- o oracle mostraria para o usuário desenvolvedor_web a própria tabela clientes,
-- pois o banco de dados prioriza os objetos do esquema do usuário logado antes de procurar por sinônimos públicos.

-- exercício 4
-- caso tabela original seja excluída, o sinônimo não será apagado automaticamente, mas causará erro na execução
CREATE OR REPLACE SYNONYM vendas FOR vendas@link_portugal;
SELECT * FROM vendas;

