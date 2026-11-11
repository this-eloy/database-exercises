-- Lista de exercicios: Automação e Auditoria com Triggers
-- modelo de script para resposta


-- ============================================================================
-- PARTE 1: PREPARAÇÃO DO AMBIENTE (Execute este bloco antes de começar)
-- ============================================================================

-- 1.1 Limpeza segura de objetos anteriores (caso precise resetar os testes)
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE AUDITORIA_FUNCIONARIO CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE AUDITORIA_DEPARTAMENTO CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE FUNCIONARIO CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE DEPARTAMENTO CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 1.2 Criação das tabelas base do esquema EMPRESA
CREATE TABLE DEPARTAMENTO (
    dnumero     NUMBER(5) PRIMARY KEY,
    dnome       VARCHAR2(50) NOT NULL UNIQUE,
    cpf_gerente VARCHAR2(11)
);

CREATE TABLE FUNCIONARIO (
    cpf         VARCHAR2(11) PRIMARY KEY,
    pnome       VARCHAR2(50) NOT NULL,
    salario     NUMBER(10,2) NOT NULL CHECK (salario > 0),
    dnumero     NUMBER(5),
    CONSTRAINT fk_func_depto FOREIGN KEY (dnumero) REFERENCES DEPARTAMENTO(dnumero)
);

-- 1.3 Carga inicial de dados (Massa de testes)
INSERT INTO DEPARTAMENTO (dnumero, dnome, cpf_gerente) VALUES (1, 'Tecnologia da Informacao', '11111111111');
INSERT INTO DEPARTAMENTO (dnumero, dnome, cpf_gerente) VALUES (2, 'Recursos Humanos', '22222222222');
INSERT INTO DEPARTAMENTO (dnumero, dnome, cpf_gerente) VALUES (3, 'Financeiro', NULL);

-- Funcionários alocados: 3 em TI, 2 em RH, 0 no Financeiro
INSERT INTO FUNCIONARIO (cpf, pnome, salario, dnumero) VALUES ('11111111111', 'Ana Silva', 8500.00, 1);
INSERT INTO FUNCIONARIO (cpf, pnome, salario, dnumero) VALUES ('11111111112', 'Bruno Costa', 5200.00, 1);
INSERT INTO FUNCIONARIO (cpf, pnome, salario, dnumero) VALUES ('11111111113', 'Carla Dias', 6100.00, 1);

INSERT INTO FUNCIONARIO (cpf, pnome, salario, dnumero) VALUES ('22222222222', 'Diego Souza', 7000.00, 2);
INSERT INTO FUNCIONARIO (cpf, pnome, salario, dnumero) VALUES ('22222222223', 'Elena Rocha', 4300.00, 2);

-- Caso de borda: Estagiário/Trainee ainda sem departamento alocado (dnumero IS NULL)
INSERT INTO FUNCIONARIO (cpf, pnome, salario, dnumero) VALUES ('99999999999', 'Lucas Mendes', 2000.00, NULL);

-- Integridade referencial do gerente após carga inicial
ALTER TABLE DEPARTAMENTO 
ADD CONSTRAINT fk_depto_gerente FOREIGN KEY (cpf_gerente) REFERENCES FUNCIONARIO(cpf);

COMMIT;

-- ============================================================================
-- PARTE 2: LISTA DE EXERCÍCIOS (Desenvolva suas soluções abaixo de cada item)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- EXERCÍCIO 1: Alteração de Estrutura (DDL)
-- Contexto: Para evitar consultas pesadas de contagem (COUNT) toda vez que o 
-- painel gerencial for aberto, vamos desnormalizar um dado de controle.
-- Tarefa: Altere a tabela DEPARTAMENTO adicionando a coluna QTE_FUNCIONARIOS 
-- do tipo NUMBER(5), com valor padrão 0 (DEFAULT 0) e NOT NULL.
-- ----------------------------------------------------------------------------

ALTER TABLE DEPARTAMENTO 
ADD QTE_FUNCIONARIOS NUMBER(5) DEFAULT 0 NOT NULL;

-- ----------------------------------------------------------------------------
-- EXERCÍCIO 2: Sincronização Inicial (DML)
-- Contexto: Como o banco já possui registros cadastrados, o novo campo 
-- precisa refletir a realidade atual antes de ativarmos a automação.
-- Tarefa: Atualize o campo QTE_FUNCIONARIOS de todos os departamentos 
-- contando quantos funcionários estão alocados em cada um.
-- Dica: Use uma subconsulta correlacionada no UPDATE e execute COMMIT ao final.
-- ----------------------------------------------------------------------------

UPDATE DEPARTAMENTO d
SET qte_funcionarios = (
    SELECT COUNT(*) 
    FROM FUNCIONARIO f 
    WHERE f.dnumero = d.dnumero
);
COMMIT;

-- ----------------------------------------------------------------------------
-- EXERCÍCIO 3: Contratação de Funcionários (Trigger AFTER INSERT)
-- Tarefa: Crie um gatilho na tabela FUNCIONARIO que incremente (+ 1) o campo 
-- QTE_FUNCIONARIOS do departamento correspondente a cada inserção.
-- Atenção: Trate o caso em que o funcionário entra sem departamento (NULL).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_func_insert
AFTER INSERT ON FUNCIONARIO
FOR EACH ROW
BEGIN
    IF :NEW.dnumero IS NOT NULL THEN
        UPDATE DEPARTAMENTO
        SET qte_funcionarios = qte_funcionarios + 1
        WHERE dnumero = :NEW.dnumero;
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- EXERCÍCIO 4: Desligamento e Transferência (Triggers DELETE e UPDATE)
-- Tarefa A: Crie um gatilho (AFTER DELETE) que decremente (- 1) a quantidade 
-- de funcionários do antigo departamento (:OLD.dnumero).
-- Tarefa B: Crie um gatilho (AFTER UPDATE) que verifique se houve troca de 
-- departamento. Se mudou, decremente 1 do antigo (:OLD) e incremente 1 no novo (:NEW).
-- Dica: Lembre-se de usar NVL() para comparar valores que podem ser NULL.
-- ----------------------------------------------------------------------------

-- Tarefa A
CREATE OR REPLACE TRIGGER trg_func_delete
AFTER DELETE ON FUNCIONARIO
FOR EACH ROW
BEGIN
    IF :OLD.dnumero IS NOT NULL THEN
        UPDATE DEPARTAMENTO
        SET qte_funcionarios = qte_funcionarios - 1
        WHERE dnumero = :OLD.dnumero;
    END IF;
END;
/
-- Tarefa B
CREATE OR REPLACE TRIGGER trg_func_update
AFTER UPDATE OF dnumero ON FUNCIONARIO
FOR EACH ROW
BEGIN
    IF NVL(:OLD.dnumero, -1) <> NVL(:NEW.dnumero, -1) THEN
        -- Decrementa o antigo departamento, caso existisse
        IF :OLD.dnumero IS NOT NULL THEN
            UPDATE DEPARTAMENTO
            SET qte_funcionarios = qte_funcionarios - 1
            WHERE dnumero = :OLD.dnumero;
        END IF;
        
        -- Incrementa o novo departamento, caso exista
        IF :NEW.dnumero IS NOT NULL THEN
            UPDATE DEPARTAMENTO
            SET qte_funcionarios = qte_funcionarios + 1
            WHERE dnumero = :NEW.dnumero;
        END IF;
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- EXERCÍCIO 5: Segurança e Rastreabilidade (Auditoria Completa)
-- Tarefa Passo 1: Crie as tabelas AUDITORIA_FUNCIONARIO e AUDITORIA_DEPARTAMENTO
-- contendo: id_log (IDENTITY PK), operacao ('INSERT'/'UPDATE'/'DELETE'), 
-- usuario_banco (USER), data_hora (SYSTIMESTAMP), chave do registro alterado 
-- e os campos com valores antigos e novos (_antigo / _novo).
-- Tarefa Passo 2: Escreva os gatilhos para registrar todas as operações de 
-- INSERT, UPDATE e DELETE nas duas tabelas.
-- ----------------------------------------------------------------------------

--Tarefa A
CREATE TABLE AUDITORIA_FUNCIONARIO (
    id_log         NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    operacao       VARCHAR2(10) NOT NULL,
    usuario_banco  VARCHAR2(50) NOT NULL,
    data_hora      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    cpf_chave      VARCHAR2(11),
    pnome_antigo   VARCHAR2(50),
    salario_antigo NUMBER(10,2),
    dnumero_antigo NUMBER(5),
    pnome_novo     VARCHAR2(50),
    salario_novo   NUMBER(10,2),
    dnumero_novo   NUMBER(5)
);

CREATE TABLE AUDITORIA_DEPARTAMENTO (
    id_log             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    operacao           VARCHAR2(10) NOT NULL,
    usuario_banco      VARCHAR2(50) NOT NULL,
    data_hora          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    dnumero_chave      NUMBER(5),
    dnome_antigo       VARCHAR2(50),
    cpf_gerente_antigo VARCHAR2(11),
    qte_func_antigo    NUMBER(5),
    dnome_novo         VARCHAR2(50),
    cpf_gerente_novo   VARCHAR2(11),
    qte_func_novo      NUMBER(5)
);

-- Tarefa B
CREATE OR REPLACE TRIGGER trg_audit_funcionario
AFTER INSERT OR UPDATE OR DELETE ON FUNCIONARIO
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO AUDITORIA_FUNCIONARIO (
            operacao, usuario_banco, data_hora, cpf_chave,
            pnome_antigo, salario_antigo, dnumero_antigo,
            pnome_novo, salario_novo, dnumero_novo
        ) VALUES (
            'INSERT', USER, SYSTIMESTAMP, :NEW.cpf,
            NULL, NULL, NULL,
            :NEW.pnome, :NEW.salario, :NEW.dnumero
        );
    ELSIF UPDATING THEN
        INSERT INTO AUDITORIA_FUNCIONARIO (
            operacao, usuario_banco, data_hora, cpf_chave,
            pnome_antigo, salario_antigo, dnumero_antigo,
            pnome_novo, salario_novo, dnumero_novo
        ) VALUES (
            'UPDATE', USER, SYSTIMESTAMP, :NEW.cpf,
            :OLD.pnome, :OLD.salario, :OLD.dnumero,
            :NEW.pnome, :NEW.salario, :NEW.dnumero
        );
    ELSIF DELETING THEN
        INSERT INTO AUDITORIA_FUNCIONARIO (
            operacao, usuario_banco, data_hora, cpf_chave,
            pnome_antigo, salario_antigo, dnumero_antigo,
            pnome_novo, salario_novo, dnumero_novo
        ) VALUES (
            'DELETE', USER, SYSTIMESTAMP, :OLD.cpf,
            :OLD.pnome, :OLD.salario, :OLD.dnumero,
            NULL, NULL, NULL
        );
    END IF;
END;
/
-- ============================================================================
-- PARTE 3: ROTEIRO DE VALIDAÇÃO (Execute após concluir os exercícios 1 a 5)
-- ============================================================================

-- TESTE 1: Contratação no Financeiro (Depto 3 deve ir de 0 para 1)
INSERT INTO FUNCIONARIO (cpf, pnome, salario, dnumero) 
VALUES ('33333333333', 'Fernanda Lima', 5500.00, 3);

-- TESTE 2: Transferência de Bruno (11111111112) de TI (1) para RH (2)
-- Esperado: TI cai para 2 | RH sobe para 3
UPDATE FUNCIONARIO 
SET dnumero = 2 
WHERE cpf = '11111111112';

-- TESTE 3: Alocação do funcionário sem departamento (Lucas - 99999999999) para TI (1)
-- Esperado: TI sobe para 3
UPDATE FUNCIONARIO 
SET dnumero = 1 
WHERE cpf = '99999999999';

-- TESTE 4: Aumento salarial sem troca de departamento (Não deve alterar contagem)
UPDATE FUNCIONARIO 
SET salario = 9000.00 
WHERE cpf = '11111111111';

-- TESTE 5: Demissão de Elena (22222222223) do RH (2)
-- Esperado: RH cai para 2
DELETE FROM FUNCIONARIO 
WHERE cpf = '22222222223';

-- TESTE 6: Alteração de nome de departamento (Testando auditoria de DEPARTAMENTO)
UPDATE DEPARTAMENTO 
SET dnome = 'TI e Inovacao' 
WHERE dnumero = 1;

COMMIT;

-- ============================================================================
-- PARTE 4: CONSULTAS DE CONFERÊNCIA FINAL
-- ============================================================================
-- Resultado esperado: TI = 3 | RH = 2 | Financeiro = 1
SELECT dnumero, dnome, QTE_FUNCIONARIOS FROM DEPARTAMENTO ORDER BY dnumero;

-- Deve listar 5 eventos na tabela FUNCIONARIO (1 INSERT, 3 UPDATEs, 1 DELETE)
SELECT * FROM AUDITORIA_FUNCIONARIO ORDER BY id_log;

-- Deve listar os updates em cascata da contagem + o update do nome do depto
SELECT * FROM AUDITORIA_DEPARTAMENTO ORDER BY id_log;

