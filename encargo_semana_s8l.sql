------          SYSYEM          -------------
-- CASO 1
ALTER SESSION SET "_ORACLE_SCRIPT"=TRUE;

-- Crear usuarios

CREATE USER PRY2205_USER1 IDENTIFIED BY clave123
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

CREATE USER PRY2205_USER2 IDENTIFIED BY clave123
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

-- Crear roles


CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_P;

-- Asignar privilegios a los roles

-- ROL_D: Para USER1 (dueño de las tablas)
GRANT CREATE SESSION        TO PRY2205_ROL_D;
GRANT CREATE TABLE          TO PRY2205_ROL_D;
GRANT CREATE VIEW           TO PRY2205_ROL_D;
GRANT CREATE SYNONYM        TO PRY2205_ROL_D;
GRANT CREATE PUBLIC SYNONYM TO PRY2205_ROL_D;

-- ROL_P: Para USER2 (desarrollador)
GRANT CREATE SESSION  TO PRY2205_ROL_P;
GRANT CREATE VIEW     TO PRY2205_ROL_P;
GRANT CREATE PROFILE  TO PRY2205_ROL_P;
GRANT CREATE USER     TO PRY2205_ROL_P;
GRANT CREATE SYNONYM  TO PRY2205_ROL_P;


-- Asignar roles a los usuarios
GRANT PRY2205_ROL_D TO PRY2205_USER1;
GRANT PRY2205_ROL_P TO PRY2205_USER2;

-- Privilegio adicional directo a USER2
GRANT CREATE VIEW TO PRY2205_USER2;

-- Crear sinónimos públicos
CREATE PUBLIC SYNONYM SYN_BONO_CONSULTA        FOR PRY2205_USER1.BONO_CONSULTA;
CREATE PUBLIC SYNONYM SYN_CARGO                FOR PRY2205_USER1.CARGO;
CREATE PUBLIC SYNONYM SYN_CANT_BONOS_PAC_ANNIO FOR PRY2205_USER1.CANT_BONOS_PACIENTES_ANNIO;
CREATE PUBLIC SYNONYM SYN_DET_ESPECIALIDAD_MED FOR PRY2205_USER1.DET_ESPECIALIDAD_MED;
CREATE PUBLIC SYNONYM SYN_ESPECIALIDAD_MEDICA  FOR PRY2205_USER1.ESPECIALIDAD_MEDICA;
CREATE PUBLIC SYNONYM SYN_MEDICO               FOR PRY2205_USER1.MEDICO;
CREATE PUBLIC SYNONYM SYN_PACIENTE             FOR PRY2205_USER1.PACIENTE;
CREATE PUBLIC SYNONYM SYN_PAGOS                FOR PRY2205_USER1.PAGOS;
CREATE PUBLIC SYNONYM SYN_PCT_DESCTO           FOR PRY2205_USER1.PCT_DESCTO_ADULTO_MAYOR;
CREATE PUBLIC SYNONYM SYN_SALUD                FOR PRY2205_USER1.SALUD;
CREATE PUBLIC SYNONYM SYN_SISTEMA_SALUD        FOR PRY2205_USER1.SISTEMA_SALUD;
CREATE PUBLIC SYNONYM SYN_UNIDAD_CONSULTA      FOR PRY2205_USER1.UNIDAD_CONSULTA;


-- Dar acceso SELECT a ROL_P
GRANT SELECT ON PRY2205_USER1.BONO_CONSULTA       TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.PACIENTE            TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.SALUD               TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.SISTEMA_SALUD       TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.ESPECIALIDAD_MEDICA TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.MEDICO              TO PRY2205_ROL_P;
GRANT SELECT ON PRY2205_USER1.CARGO               TO PRY2205_ROL_P;

-- Permisos directos a USER2
GRANT SELECT ON PRY2205_USER1.BONO_CONSULTA  TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.PACIENTE       TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.SALUD          TO PRY2205_USER2;
GRANT SELECT ON PRY2205_USER1.SISTEMA_SALUD  TO PRY2205_USER2;

-- Verificar usuarios
SELECT username, account_status FROM dba_users 
WHERE username IN ('PRY2205_USER1','PRY2205_USER2');

-- Verificar roles
SELECT role FROM dba_roles 
WHERE role IN ('PRY2205_ROL_D','PRY2205_ROL_P');

-- Verificar sinónimos públicos
SELECT synonym_name FROM dba_synonyms 
WHERE synonym_name LIKE 'SYN_%';

----------          FIN SYSTEM      ---------------------------------


----------          USER1           ---------------------------------

-- CASO 3.1

CREATE OR REPLACE VIEW VW_AUM_MEDICO_X_CARGO AS
SELECT
    m.rut_med || '-' || m.dv_run                              AS "RUT MEDICO",
    INITCAP(m.apaterno || ' ' || m.amaterno || ', '
            || m.pnombre || ' ' || m.snombre)                 AS "NOMBRE MEDICO",
    INITCAP(c.nombre)                                         AS "CARGO",
    TO_CHAR(m.fecha_contrato, 'DD/MM/YYYY')                  AS "FECHA CONTRATO",
    m.sueldo_base                                             AS "SUELDO BASE",
    ROUND(m.sueldo_base * 1.15)                              AS "SUELDO AUMENTADO"
FROM SYN_MEDICO m
JOIN SYN_CARGO  c ON m.car_id = c.car_id
WHERE UPPER(c.nombre) LIKE '%ATEN%'
ORDER BY ROUND(m.sueldo_base * 1.15) DESC;

-- Verificación
SELECT * FROM VW_AUM_MEDICO_X_CARGO;

-- CASO 3.2

-- Plan de ejecución ANTES de crear los índices
-- (capturar pantalla en SQL Developer - pestaña "Plan de Ejecución")
EXPLAIN PLAN FOR
SELECT * FROM VW_AUM_MEDICO_X_CARGO;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

-- Creación de índices
-- Índice sobre la FK de MEDICO usada en el JOIN con CARGO
CREATE INDEX IDX_MEDICO_CAR_ID
    ON PRY2205_USER1.MEDICO (car_id);

-- Índice sobre NOMBRE de CARGO usado en el WHERE con LIKE
CREATE INDEX IDX_CARGO_NOMBRE
    ON PRY2205_USER1.CARGO (nombre);

-- Plan de ejecución DESPUÉS de crear los índices
EXPLAIN PLAN FOR
SELECT * FROM VW_AUM_MEDICO_X_CARGO;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY())

-- Verificar que las tablas existen
SELECT table_name FROM user_tables ORDER BY table_name;

-- Verificar la vista
SELECT * FROM VW_AUM_MEDICO_X_CARGO;

-- Verificar los índices
SELECT index_name FROM user_indexes WHERE index_name LIKE 'IDX_%';
----------------            FIN USER1           -------------------


----------------            USER2               -------------------
-- CASO 2: VISTA VW_RECALCULO_COSTOS
CREATE OR REPLACE VIEW VW_RECALCULO_COSTOS AS
SELECT
    bc.id_bono                                              AS "ID BONO",
    TO_CHAR(bc.fecha_bono, 'DD/MM/YYYY')                   AS "FECHA BONO",
    bc.hr_consulta                                          AS "HORA CONSULTA",
    p.pac_run || '-' || p.dv_run                            AS "RUT PACIENTE",
    INITCAP(p.apaterno || ' ' || p.amaterno || ', '
            || p.pnombre || ' ' || p.snombre)               AS "NOMBRE PACIENTE",
    -- Subconsulta escalar: obtiene descripción del sistema de salud
    (SELECT ss.descripcion
     FROM SYN_SISTEMA_SALUD ss
     JOIN SYN_SALUD s2 ON s2.tipo_sal_id = ss.tipo_sal_id
     WHERE s2.sal_id = p.sal_id)                            AS "SISTEMA SALUD",
    bc.costo                                                AS "COSTO ORIGINAL",
    CASE
        WHEN bc.costo BETWEEN 15000 AND 25000
            THEN ROUND(bc.costo * 1.15)
        WHEN bc.costo > 25000
            THEN ROUND(bc.costo * 1.20)
        ELSE bc.costo
    END                                                     AS "COSTO REAJUSTADO"
FROM SYN_BONO_CONSULTA bc
JOIN SYN_PACIENTE       p ON bc.pac_run = p.pac_run
WHERE TO_CHAR(bc.fecha_bono, 'YYYY') = TO_CHAR(SYSDATE - INTERVAL '1' YEAR, 'YYYY')
  AND bc.hr_consulta > '17:15'
  -- Subconsulta en WHERE: filtra solo Isapre (I) y Fonasa (F)
  AND p.sal_id IN (
      SELECT s.sal_id
      FROM SYN_SALUD s
      WHERE s.tipo_sal_id IN ('I', 'F')
  )
ORDER BY bc.fecha_bono, p.pac_run;

-- Verificación
SELECT * FROM VW_RECALCULO_COSTOS;

-------------           FIN USER2           ------------------------------------
