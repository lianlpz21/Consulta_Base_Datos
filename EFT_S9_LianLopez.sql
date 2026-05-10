-- PRY2205 - EFT Semana 9

-- USUARIO: SYSTEM
-- CASO 1: ESTRATEGIA DE SEGURIDAD
-- Creación de perfil, usuarios, roles y privilegios generales
ALTER SESSION SET CONTAINER = XEPDB1;

SHOW USER;

SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;


-- Perfil de seguridad solicitado
CREATE PROFILE PRY2205_PERFIL_SEGURIDAD LIMIT
    PASSWORD_LIFE_TIME 90
    FAILED_LOGIN_ATTEMPTS 3
    PASSWORD_LOCK_TIME 1;

-- Usuario owner del modelo
CREATE USER PRY2205_EFT
IDENTIFIED BY "DuocUC2026**"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON USERS
PROFILE PRY2205_PERFIL_SEGURIDAD;

-- Usuario desarrollador
CREATE USER PRY2205_EFT_DES
IDENTIFIED BY "DesUC2026**"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON USERS
PROFILE PRY2205_PERFIL_SEGURIDAD;

-- Usuario consultor
CREATE USER PRY2205_EFT_CON
IDENTIFIED BY "ConUC2026**"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON USERS
PROFILE PRY2205_PERFIL_SEGURIDAD;

-- Privilegios minimos de conexion
GRANT CREATE SESSION TO PRY2205_EFT;
GRANT CREATE SESSION TO PRY2205_EFT_DES;
GRANT CREATE SESSION TO PRY2205_EFT_CON;

-- Privilegios del owner PRY2205_EFT.
GRANT CREATE TABLE TO PRY2205_EFT;
GRANT CREATE VIEW TO PRY2205_EFT;
GRANT CREATE SEQUENCE TO PRY2205_EFT;
GRANT CREATE SYNONYM TO PRY2205_EFT;
GRANT CREATE PUBLIC SYNONYM TO PRY2205_EFT;


-- Privilegios del usuario desarrollador PRY2205_EFT_DES
GRANT CREATE VIEW TO PRY2205_EFT_DES;
GRANT CREATE SEQUENCE TO PRY2205_EFT_DES;
GRANT CREATE PROCEDURE TO PRY2205_EFT_DES;
GRANT CREATE SYNONYM TO PRY2205_EFT_DES;

-- Roles solicitados
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_C;

-- Asignación de roles
GRANT PRY2205_ROL_D TO PRY2205_EFT_DES;
GRANT PRY2205_ROL_C TO PRY2205_EFT_CON;

-- Verificación de usuarios
SELECT username, default_tablespace, temporary_tablespace, profile
FROM dba_users
WHERE username IN ('PRY2205_EFT', 'PRY2205_EFT_DES', 'PRY2205_EFT_CON')
ORDER BY username;

-- Verificación de roles
SELECT role
FROM dba_roles
WHERE role IN ('PRY2205_ROL_D', 'PRY2205_ROL_C')
ORDER BY role;


-- ============================================================================
-- USUARIO: PRY2205_EFT
SHOW USER;

-- Verificacion posterior a ejecutar el script base
SELECT table_name
FROM user_tables
ORDER BY table_name;

SELECT sequence_name
FROM user_sequences
WHERE sequence_name = 'SEQ_T_ANALISIS';

-- ============================================================================
-- USUARIO: PRY2205_EFT
-- CASO 1
SHOW USER;


-- Sininimos publicos para que los usuarios no utilicen directamente
-- los nombres reales de las tablas.
CREATE OR REPLACE PUBLIC SYNONYM SYN_DEU FOR PRY2205_EFT.DEUDOR;
CREATE OR REPLACE PUBLIC SYNONYM SYN_TAR FOR PRY2205_EFT.TARJETA_DEUDOR;
CREATE OR REPLACE PUBLIC SYNONYM SYN_CUO FOR PRY2205_EFT.CUOTA_TARJETAS;
CREATE OR REPLACE PUBLIC SYNONYM SYN_OCU FOR PRY2205_EFT.OCUPACION;
CREATE OR REPLACE PUBLIC SYNONYM SYN_TRA FOR PRY2205_EFT.TRANSACCION_TARJETA_DEUDOR;
CREATE OR REPLACE PUBLIC SYNONYM SYN_SUC FOR PRY2205_EFT.SUCURSAL;
CREATE OR REPLACE PUBLIC SYNONYM SYN_ANA_TAR FOR PRY2205_EFT.T_ANALISIS_TARJETAS;
CREATE OR REPLACE PUBLIC SYNONYM SYN_SEQ_ANA FOR PRY2205_EFT.SEQ_T_ANALISIS;

-- Permisos al rol del desarrollador
GRANT SELECT ON DEUDOR TO PRY2205_ROL_D;
GRANT SELECT ON TARJETA_DEUDOR TO PRY2205_ROL_D;
GRANT SELECT ON CUOTA_TARJETAS TO PRY2205_ROL_D;
GRANT SELECT ON OCUPACION TO PRY2205_ROL_D;

-- Permisos directos al desarrollador
GRANT SELECT ON DEUDOR TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON TARJETA_DEUDOR TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON CUOTA_TARJETAS TO PRY2205_EFT_DES WITH GRANT OPTION;
GRANT SELECT ON OCUPACION TO PRY2205_EFT_DES WITH GRANT OPTION;

-- Permisos al rol del consultor
GRANT SELECT ON DEUDOR TO PRY2205_ROL_C;
GRANT SELECT ON TARJETA_DEUDOR TO PRY2205_ROL_C;
GRANT SELECT ON CUOTA_TARJETAS TO PRY2205_ROL_C;
GRANT SELECT ON OCUPACION TO PRY2205_ROL_C;
GRANT SELECT ON TRANSACCION_TARJETA_DEUDOR TO PRY2205_ROL_C;
GRANT SELECT ON SUCURSAL TO PRY2205_ROL_C;
GRANT SELECT ON T_ANALISIS_TARJETAS TO PRY2205_ROL_C;

-- Verificacion de sinonimos publicos
SELECT synonym_name, table_owner, table_name
FROM all_synonyms
WHERE synonym_name IN (
    'SYN_DEU',
    'SYN_TAR',
    'SYN_CUO',
    'SYN_OCU',
    'SYN_TRA',
    'SYN_SUC',
    'SYN_ANA_TAR',
    'SYN_SEQ_ANA'
)
ORDER BY synonym_name;

-- Verificacion de privilegios entregados
SELECT grantee, table_name, privilege
FROM user_tab_privs_made
WHERE grantee IN ('PRY2205_ROL_D', 'PRY2205_ROL_C', 'PRY2205_EFT_DES')
ORDER BY grantee, table_name;


-- ============================================================================
-- USUARIO: PRY2205_EFT_DES
-- CASO 2: CREACIÓN DE VISTA VW_ANALISIS_DEUDORES_PERIODO

SHOW USER;

-- Prueba de acceso mediante sinonimos publicos
SELECT COUNT(*) AS total_deudores
FROM SYN_DEU;

SELECT COUNT(*) AS total_tarjetas
FROM SYN_TAR;

SELECT COUNT(*) AS total_cuotas
FROM SYN_CUO;

SELECT COUNT(*) AS total_ocupaciones
FROM SYN_OCU;

-- Vista para analisis de deudores
CREATE OR REPLACE VIEW VW_ANALISIS_DEUDORES_PERIODO AS
SELECT
    TO_CHAR(d.numrun) || '-' || d.dvrun AS rut_deudor,

    INITCAP(TRIM(d.pnombre)) || ' ' ||
    INITCAP(TRIM(d.appaterno)) || ' ' ||
    INITCAP(TRIM(NVL(d.apmaterno, ''))) AS nombre_deudor,

    COUNT(c.nro_cuota) AS total_cuotas,

    ROUND(AVG(c.valor_cuota)) AS promedio_valor_cuotas,

    TO_CHAR(MIN(c.fecha_venc_cuota), 'DD/MM/YYYY') AS fecha_mas_antigua,

    NVL(TO_CHAR(d.fono_contacto), 'Sin Información') AS telefono,

    UPPER(o.nombre_prof_ofic) AS ocupacion,

    t.cupo_disp_compra AS cupo_disp_compra
FROM SYN_DEU d
JOIN SYN_OCU o
    ON d.cod_ocupacion = o.cod_ocupacion
JOIN SYN_TAR t
    ON d.numrun = t.numrun
JOIN SYN_CUO c
    ON t.nro_tarjeta = c.nro_tarjeta
WHERE UPPER(o.nombre_prof_ofic) NOT LIKE '%INGENIERO%'
  AND EXTRACT(YEAR FROM c.fecha_venc_cuota) =
      EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12))
GROUP BY
    d.numrun,
    d.dvrun,
    d.pnombre,
    d.appaterno,
    d.apmaterno,
    d.fono_contacto,
    o.nombre_prof_ofic,
    t.nro_tarjeta,
    t.cupo_disp_compra
HAVING ROUND(AVG(c.valor_cuota)) < (
    SELECT MAX(promedio_general)
    FROM (
        SELECT AVG(c2.valor_cuota) AS promedio_general
        FROM SYN_CUO c2
        GROUP BY c2.nro_tarjeta
    )
);


-- Consulta de validacion del informe
SELECT *
FROM VW_ANALISIS_DEUDORES_PERIODO
ORDER BY total_cuotas ASC, cupo_disp_compra ASC;


-- Permiso solicitado al usuario consultor sobre la vista
GRANT SELECT ON VW_ANALISIS_DEUDORES_PERIODO TO PRY2205_EFT_CON;

-- ============================================================================
-- USUARIO: PRY2205_EFT
-- CASO 3.1: CARGA DE DATOS EN T_ANALISIS_TARJETAS
SHOW USER;

-- Verificacion de estructura y secuencia
DESC T_ANALISIS_TARJETAS;

SELECT sequence_name
FROM user_sequences
WHERE sequence_name = 'SEQ_T_ANALISIS';


-- Consulta base del informe usando sinonimos publicos
SELECT
    tr.nro_tarjeta AS nro_tarjeta,
    tr.total_cuotas_transaccion AS total_cuotas,
    tr.monto_total_transaccion AS monto_total_transa,
    TO_CHAR(tr.fecha_transaccion, 'DD/MM/YYYY') AS fecha_transaccion,
    INITCAP(s.direccion) AS direccion,
    ROUND(
        tr.monto_total_transaccion +
        CASE
            WHEN tr.monto_total_transaccion BETWEEN 200000 AND 300000
                THEN tr.monto_total_transaccion * 0.05
            WHEN tr.monto_total_transaccion BETWEEN 300001 AND 500000
                THEN tr.monto_total_transaccion * 0.07
            ELSE 0
        END
    ) AS monto_reajustado
FROM SYN_TRA tr
JOIN SYN_SUC s
    ON tr.id_sucursal = s.id_sucursal
WHERE UPPER(s.direccion) LIKE 'A%'
  AND tr.monto_total_transaccion >= 200000
ORDER BY
    tr.nro_tarjeta ASC,
    monto_reajustado DESC;


-- Carga de datos en la tabla solicitada
TRUNCATE TABLE T_ANALISIS_TARJETAS;

INSERT INTO T_ANALISIS_TARJETAS (
    num_analisis,
    nro_tarjeta,
    total_cuotas,
    monto_total_transa,
    fecha_transaccion,
    direccion,
    monto_reajustado
)
SELECT
    SYN_SEQ_ANA.NEXTVAL,
    datos.nro_tarjeta,
    datos.total_cuotas,
    datos.monto_total_transa,
    datos.fecha_transaccion,
    datos.direccion,
    datos.monto_reajustado
FROM (
    SELECT
        tr.nro_tarjeta AS nro_tarjeta,
        tr.total_cuotas_transaccion AS total_cuotas,
        tr.monto_total_transaccion AS monto_total_transa,
        TO_CHAR(tr.fecha_transaccion, 'DD/MM/YYYY') AS fecha_transaccion,
        INITCAP(s.direccion) AS direccion,
        ROUND(
            tr.monto_total_transaccion +
            CASE
                WHEN tr.monto_total_transaccion BETWEEN 200000 AND 300000
                    THEN tr.monto_total_transaccion * 0.05
                WHEN tr.monto_total_transaccion BETWEEN 300001 AND 500000
                    THEN tr.monto_total_transaccion * 0.07
                ELSE 0
            END
        ) AS monto_reajustado
    FROM SYN_TRA tr
    JOIN SYN_SUC s
        ON tr.id_sucursal = s.id_sucursal
    WHERE UPPER(s.direccion) LIKE 'A%'
      AND tr.monto_total_transaccion >= 200000
    ORDER BY
        tr.nro_tarjeta ASC,
        monto_reajustado DESC
) datos;

COMMIT;


-- Consulta de validacion
SELECT *
FROM T_ANALISIS_TARJETAS
ORDER BY nro_tarjeta ASC, monto_reajustado DESC;

-- Permiso solicitado al usuario consultor sobre la tabla
GRANT SELECT ON T_ANALISIS_TARJETAS TO PRY2205_EFT_CON;


-- ============================================================================
-- USUARIO: PRY2205_EFT
-- CASO 3.2: PLAN DE EJECUCIÓN E ÍNDICES
SHOW USER;


-- PLAN DE EJECUCION ANTES DE CREAR INDICES.
EXPLAIN PLAN FOR
INSERT INTO T_ANALISIS_TARJETAS (
    num_analisis,
    nro_tarjeta,
    total_cuotas,
    monto_total_transa,
    fecha_transaccion,
    direccion,
    monto_reajustado
)
SELECT
    SYN_SEQ_ANA.NEXTVAL,
    datos.nro_tarjeta,
    datos.total_cuotas,
    datos.monto_total_transa,
    datos.fecha_transaccion,
    datos.direccion,
    datos.monto_reajustado
FROM (
    SELECT
        tr.nro_tarjeta AS nro_tarjeta,
        tr.total_cuotas_transaccion AS total_cuotas,
        tr.monto_total_transaccion AS monto_total_transa,
        TO_CHAR(tr.fecha_transaccion, 'DD/MM/YYYY') AS fecha_transaccion,
        INITCAP(s.direccion) AS direccion,
        ROUND(
            tr.monto_total_transaccion +
            CASE
                WHEN tr.monto_total_transaccion BETWEEN 200000 AND 300000
                    THEN tr.monto_total_transaccion * 0.05
                WHEN tr.monto_total_transaccion BETWEEN 300001 AND 500000
                    THEN tr.monto_total_transaccion * 0.07
                ELSE 0
            END
        ) AS monto_reajustado
    FROM SYN_TRA tr
    JOIN SYN_SUC s
        ON tr.id_sucursal = s.id_sucursal
    WHERE UPPER(s.direccion) LIKE 'A%'
      AND tr.monto_total_transaccion >= 200000
    ORDER BY
        tr.nro_tarjeta ASC,
        monto_reajustado DESC
) datos;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);


-- Creacion de indices para optimizar filtros, join y ordenamiento.
CREATE INDEX IDX_TRA_SUC_MONTO
ON TRANSACCION_TARJETA_DEUDOR(id_sucursal, monto_total_transaccion);

CREATE INDEX IDX_SUC_DIRECCION
ON SUCURSAL(UPPER(direccion));

CREATE INDEX IDX_TRA_TARJETA
ON TRANSACCION_TARJETA_DEUDOR(nro_tarjeta);


-- PLAN DE EJECUCION DESPUES DE CREAR INDICES.
EXPLAIN PLAN FOR
INSERT INTO T_ANALISIS_TARJETAS (
    num_analisis,
    nro_tarjeta,
    total_cuotas,
    monto_total_transa,
    fecha_transaccion,
    direccion,
    monto_reajustado
)
SELECT
    SYN_SEQ_ANA.NEXTVAL,
    datos.nro_tarjeta,
    datos.total_cuotas,
    datos.monto_total_transa,
    datos.fecha_transaccion,
    datos.direccion,
    datos.monto_reajustado
FROM (
    SELECT
        tr.nro_tarjeta AS nro_tarjeta,
        tr.total_cuotas_transaccion AS total_cuotas,
        tr.monto_total_transaccion AS monto_total_transa,
        TO_CHAR(tr.fecha_transaccion, 'DD/MM/YYYY') AS fecha_transaccion,
        INITCAP(s.direccion) AS direccion,
        ROUND(
            tr.monto_total_transaccion +
            CASE
                WHEN tr.monto_total_transaccion BETWEEN 200000 AND 300000
                    THEN tr.monto_total_transaccion * 0.05
                WHEN tr.monto_total_transaccion BETWEEN 300001 AND 500000
                    THEN tr.monto_total_transaccion * 0.07
                ELSE 0
            END
        ) AS monto_reajustado
    FROM SYN_TRA tr
    JOIN SYN_SUC s
        ON tr.id_sucursal = s.id_sucursal
    WHERE UPPER(s.direccion) LIKE 'A%'
      AND tr.monto_total_transaccion >= 200000
    ORDER BY
        tr.nro_tarjeta ASC,
        monto_reajustado DESC
) datos;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);


-- Verificacion de indices creados
SELECT index_name, table_name
FROM user_indexes
WHERE index_name IN (
    'IDX_TRA_SUC_MONTO',
    'IDX_SUC_DIRECCION',
    'IDX_TRA_TARJETA'
)
ORDER BY table_name, index_name;


-- ============================================================================
-- USUARIO: PRY2205_EFT_CON
-- VALIDACION FINAL DEL USUARIO CONSULTOR
SHOW USER;


-- Consulta de la vista creada por PRY2205_EFT_DES
SELECT *
FROM PRY2205_EFT_DES.VW_ANALISIS_DEUDORES_PERIODO
ORDER BY total_cuotas ASC, cupo_disp_compra ASC;


-- Consulta de la tabla de analisis usando sinonimo publico
SELECT *
FROM SYN_ANA_TAR
ORDER BY nro_tarjeta ASC, monto_reajustado DESC;


-- Consulta de la tabla de analisis usando nombre completo
SELECT *
FROM PRY2205_EFT.T_ANALISIS_TARJETAS
ORDER BY nro_tarjeta ASC, monto_reajustado DESC;



