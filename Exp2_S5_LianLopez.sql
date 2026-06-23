SET SERVEROUTPUT ON;
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';


VARIABLE b_fecha_proceso VARCHAR2(6);
EXEC :b_fecha_proceso := '062021';

VARIABLE b_limite_asignacion NUMBER;
EXEC :b_limite_asignacion := 250000;

DECLARE
  CURSOR c_profesionales IS
    SELECT p.numrun_prof,
           p.dvrun_prof,
           p.cod_comuna,
           p.cod_profesion,
           p.appaterno,
           p.apmaterno,
           p.nombre,
           p.sueldo,
           p.cod_tpcontrato,
           pr.nombre_profesion
    FROM profesional p
         JOIN profesion pr
           ON pr.cod_profesion = p.cod_profesion
    WHERE EXISTS (
            SELECT 1
            FROM asesoria a
            WHERE a.numrun_prof = p.numrun_prof
              AND TO_CHAR(a.inicio_asesoria, 'MMYYYY') = :b_fecha_proceso
          )
    ORDER BY pr.nombre_profesion,
             p.appaterno,
             p.nombre;

  /* Registro para almacenar la informacion obtenida por el cursor */
  v_prof c_profesionales%ROWTYPE;

  /* VARRAY con los 5 porcentajes de asignacion de movilizacion extra:
     1: Santiago, 2: Nunoa, 3: La Reina, 4: La Florida, 5: Macul */
  TYPE t_porc_movil IS VARRAY(5) OF NUMBER;
  v_porc_movil t_porc_movil := t_porc_movil(2, 4, 5, 7, 9);

  /* Excepcion definida por el usuario para controlar asignaciones sobre el limite */
  e_total_superado EXCEPTION;

  /* Variables del periodo de proceso */
  v_mes_proceso       NUMBER(6);
  v_anno_proceso      NUMBER(6);
  v_anno_mes_proceso  NUMBER(6);

  /* Variables de calculo por profesional */
  v_run_profesional          detalle_asignacion_mes.run_profesional%TYPE;
  v_nombre_profesional       detalle_asignacion_mes.nombre_profesional%TYPE;
  v_nro_asesorias            detalle_asignacion_mes.nro_asesorias%TYPE;
  v_monto_honorarios         detalle_asignacion_mes.monto_honorarios%TYPE;
  v_monto_movil_extra        detalle_asignacion_mes.monto_movil_extra%TYPE;
  v_monto_asig_tipocont      detalle_asignacion_mes.monto_asig_tipocont%TYPE;
  v_monto_asig_profesion     detalle_asignacion_mes.monto_asig_profesion%TYPE;
  v_monto_total_asignaciones detalle_asignacion_mes.monto_total_asignaciones%TYPE;
  v_monto_total_original     NUMBER;

  /* Variables para porcentajes obtenidos mediante SELECT separados */
  v_porc_tipocont  tipo_contrato.incentivo%TYPE;
  v_porc_profesion porcentaje_profesion.asignacion%TYPE;

  /* Variables para construir el resumen mensual por profesion. */
  v_total_asesorias      resumen_mes_profesion.total_asesorias%TYPE;
  v_total_honorarios     resumen_mes_profesion.monto_total_honorarios%TYPE;
  v_total_movil_extra    resumen_mes_profesion.monto_total_movil_extra%TYPE;
  v_total_asig_tipocont  resumen_mes_profesion.monto_total_asig_tipocont%TYPE;
  v_total_asig_prof      resumen_mes_profesion.monto_total_asig_prof%TYPE;
  v_total_asignaciones   resumen_mes_profesion.monto_total_asignaciones%TYPE;

BEGIN
  /* Se obtiene el mes, ano y periodo YYYYMM desde la variable BIND MMYYYY */
  v_mes_proceso      := TO_NUMBER(SUBSTR(:b_fecha_proceso, 1, 2));
  v_anno_proceso     := TO_NUMBER(SUBSTR(:b_fecha_proceso, 3, 4));
  v_anno_mes_proceso := (v_anno_proceso * 100) + v_mes_proceso;

  /* Limpieza de tablas de resultado en tiempo de ejecucion */
  EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_asignacion_mes';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE resumen_mes_profesion';
  EXECUTE IMMEDIATE 'TRUNCATE TABLE errores_proceso';

  /* Eliminacion y recreacion de la secuencia usada para errores */
  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE sq_errores';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -2289 THEN
        RAISE;
      END IF;
  END;

  EXECUTE IMMEDIATE 'CREATE SEQUENCE sq_errores START WITH 1 INCREMENT BY 1 NOCACHE';

  /* Procesamiento de profesionales con asesorias iniciadas en el periodo indicado */
  OPEN c_profesionales;
  LOOP
    FETCH c_profesionales INTO v_prof;
    EXIT WHEN c_profesionales%NOTFOUND;

    /* Inicializacion de variables por cada profesional procesado */
    v_nro_asesorias            := 0;
    v_monto_honorarios         := 0;
    v_monto_movil_extra        := 0;
    v_monto_asig_tipocont      := 0;
    v_monto_asig_profesion     := 0;
    v_monto_total_asignaciones := 0;
    v_monto_total_original     := 0;
    v_porc_tipocont            := 0;
    v_porc_profesion           := 0;

    v_run_profesional    := v_prof.numrun_prof || '-' || v_prof.dvrun_prof;
    v_nombre_profesional := v_prof.appaterno || ' ' || v_prof.nombre;

    /* SELECT separado para obtener cantidad de asesorias y suma de honorarios */
    SELECT COUNT(*), NVL(SUM(a.honorario), 0)
      INTO v_nro_asesorias, v_monto_honorarios
      FROM asesoria a
     WHERE a.numrun_prof = v_prof.numrun_prof
       AND TO_CHAR(a.inicio_asesoria, 'MMYYYY') = :b_fecha_proceso;

    /* Calculo PL/SQL de asignacion de movilizacion extra segun comuna y reglas */
    IF v_prof.cod_comuna = 82 AND v_monto_honorarios < 350000 THEN
      v_monto_movil_extra := ROUND(v_monto_honorarios * v_porc_movil(1) / 100);
    ELSIF v_prof.cod_comuna = 83 THEN
      v_monto_movil_extra := ROUND(v_monto_honorarios * v_porc_movil(2) / 100);
    ELSIF v_prof.cod_comuna = 85 AND v_monto_honorarios < 400000 THEN
      v_monto_movil_extra := ROUND(v_monto_honorarios * v_porc_movil(3) / 100);
    ELSIF v_prof.cod_comuna = 86 AND v_monto_honorarios < 800000 THEN
      v_monto_movil_extra := ROUND(v_monto_honorarios * v_porc_movil(4) / 100);
    ELSIF v_prof.cod_comuna = 89 AND v_monto_honorarios < 680000 THEN
      v_monto_movil_extra := ROUND(v_monto_honorarios * v_porc_movil(5) / 100);
    ELSE
      v_monto_movil_extra := 0;
    END IF;

    /* SELECT separado para obtener porcentaje de incentivo por tipo de contrato */
    SELECT tc.incentivo
      INTO v_porc_tipocont
      FROM tipo_contrato tc
     WHERE tc.cod_tpcontrato = v_prof.cod_tpcontrato;

    /* Calculo PL/SQL de asignacion por tipo de contrato */
    v_monto_asig_tipocont := ROUND(v_monto_honorarios * v_porc_tipocont / 100);

    /* SELECT separado para obtener porcentaje de asignacion por profesion.
       Se controla cualquier error Oracle al recuperar este porcentaje */
    BEGIN
      SELECT pp.asignacion
        INTO v_porc_profesion
        FROM porcentaje_profesion pp
       WHERE pp.cod_profesion = v_prof.cod_profesion;

      v_monto_asig_profesion := ROUND(v_prof.sueldo * v_porc_profesion / 100);
    EXCEPTION
      WHEN OTHERS THEN
        v_monto_asig_profesion := 0;

        INSERT INTO errores_proceso (
          error_id,
          mensaje_error_oracle,
          mensaje_error_usr
        ) VALUES (
          sq_errores.NEXTVAL,
          SUBSTR(SQLERRM, 1, 300),
          SUBSTR('Error al obtener porcentaje de asignacion para el RUN Nro. '
                 || v_prof.numrun_prof, 1, 300)
        );
    END;

    /* Calculo PL/SQL del total de asignaciones. */
    v_monto_total_asignaciones := ROUND(v_monto_movil_extra
                                      + v_monto_asig_tipocont
                                      + v_monto_asig_profesion);

    /* Control de excepcion definida por el usuario si supera el limite indicado */
    BEGIN
      IF v_monto_total_asignaciones > :b_limite_asignacion THEN
        v_monto_total_original := v_monto_total_asignaciones;
        RAISE e_total_superado;
      END IF;
    EXCEPTION
      WHEN e_total_superado THEN
        INSERT INTO errores_proceso (
          error_id,
          mensaje_error_oracle,
          mensaje_error_usr
        ) VALUES (
          sq_errores.NEXTVAL,
          'TOTAL_SUPERADO',
          SUBSTR('Se reemplazo el monto total de las asignaciones calculadas '
                 || v_monto_total_original
                 || ' por el monto limite de '
                 || :b_limite_asignacion
                 || ' para el RUN Nro. '
                 || v_prof.numrun_prof, 1, 300)
        );

        v_monto_total_asignaciones := :b_limite_asignacion;
    END;

    /* Insercion del detalle mensual por profesional en el orden solicitado */
    INSERT INTO detalle_asignacion_mes (
      mes_proceso,
      anno_proceso,
      run_profesional,
      nombre_profesional,
      profesion,
      nro_asesorias,
      monto_honorarios,
      monto_movil_extra,
      monto_asig_tipocont,
      monto_asig_profesion,
      monto_total_asignaciones
    ) VALUES (
      v_mes_proceso,
      v_anno_proceso,
      v_run_profesional,
      v_nombre_profesional,
      v_prof.nombre_profesion,
      v_nro_asesorias,
      v_monto_honorarios,
      v_monto_movil_extra,
      v_monto_asig_tipocont,
      v_monto_asig_profesion,
      v_monto_total_asignaciones
    );
  END LOOP;
  CLOSE c_profesionales;

  /* Generacion del resumen por profesion en forma ascendente por profesion */
  FOR r_resumen IN (
    SELECT DISTINCT dam.profesion
      FROM detalle_asignacion_mes dam
     WHERE dam.mes_proceso  = v_mes_proceso
       AND dam.anno_proceso = v_anno_proceso
     ORDER BY dam.profesion
  ) LOOP
    /* SELECT separado con funciones de grupo para totalizar la tabla detalle */
    SELECT SUM(dam.nro_asesorias),
           SUM(dam.monto_honorarios),
           SUM(dam.monto_movil_extra),
           SUM(dam.monto_asig_tipocont),
           SUM(dam.monto_asig_profesion),
           SUM(dam.monto_total_asignaciones)
      INTO v_total_asesorias,
           v_total_honorarios,
           v_total_movil_extra,
           v_total_asig_tipocont,
           v_total_asig_prof,
           v_total_asignaciones
      FROM detalle_asignacion_mes dam
     WHERE dam.mes_proceso  = v_mes_proceso
       AND dam.anno_proceso = v_anno_proceso
       AND dam.profesion    = r_resumen.profesion;

    INSERT INTO resumen_mes_profesion (
      anno_mes_proceso,
      profesion,
      total_asesorias,
      monto_total_honorarios,
      monto_total_movil_extra,
      monto_total_asig_tipocont,
      monto_total_asig_prof,
      monto_total_asignaciones
    ) VALUES (
      v_anno_mes_proceso,
      r_resumen.profesion,
      v_total_asesorias,
      v_total_honorarios,
      v_total_movil_extra,
      v_total_asig_tipocont,
      v_total_asig_prof,
      v_total_asignaciones
    );
  END LOOP;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Proceso finalizado correctamente.');
  DBMS_OUTPUT.PUT_LINE('Periodo procesado : ' || :b_fecha_proceso);
  DBMS_OUTPUT.PUT_LINE('Limite aplicado   : ' || :b_limite_asignacion);
END;
/

/* Consultas finales para validar los resultados del proceso */
PROMPT ===============================================================
PROMPT TABLA DETALLE_ASIGNACION_MES
PROMPT ===============================================================
SELECT *
FROM detalle_asignacion_mes
ORDER BY profesion, nombre_profesional;

PROMPT ===============================================================
PROMPT TABLA RESUMEN_MES_PROFESION
PROMPT ===============================================================
SELECT *
FROM resumen_mes_profesion
ORDER BY profesion;

PROMPT ===============================================================
PROMPT TABLA ERRORES_PROCESO
PROMPT ===============================================================
SELECT *
FROM errores_proceso
ORDER BY error_id;


-- Revisar que las tablas base tengan datos
SELECT 'PROFESIONAL' tabla, COUNT(*) cantidad FROM profesional
UNION ALL
SELECT 'ASESORIA', COUNT(*) FROM asesoria
UNION ALL
SELECT 'TIPO_CONTRATO', COUNT(*) FROM tipo_contrato
UNION ALL
SELECT 'PORCENTAJE_PROFESION', COUNT(*) FROM porcentaje_profesion;

-- Revisar cuántos profesionales tienen asesorías en junio 2021
SELECT COUNT(DISTINCT numrun_prof) AS profesionales_con_asesoria_junio_2021
FROM asesoria
WHERE TO_CHAR(inicio_asesoria, 'MMYYYY') = '062021';

-- Revisar cuántos registros generó tu proceso
SELECT COUNT(*) AS registros_detalle
FROM detalle_asignacion_mes;

SELECT COUNT(*) AS registros_resumen
FROM resumen_mes_profesion;

SELECT COUNT(*) AS registros_errores
FROM errores_proceso;

-- Revisar que el periodo sea junio 2021
SELECT DISTINCT mes_proceso, anno_proceso
FROM detalle_asignacion_mes;

SELECT DISTINCT anno_mes_proceso
FROM resumen_mes_profesion;

-- Revisar que ningún total supere el límite de 250000
SELECT *
FROM detalle_asignacion_mes
WHERE monto_total_asignaciones > 250000;

-- Revisar que los totales del detalle coincidan con el resumen
SELECT 
    d.profesion,
    SUM(d.nro_asesorias) AS total_asesorias_detalle,
    r.total_asesorias AS total_asesorias_resumen,
    SUM(d.monto_honorarios) AS honorarios_detalle,
    r.monto_total_honorarios AS honorarios_resumen,
    SUM(d.monto_total_asignaciones) AS total_asig_detalle,
    r.monto_total_asignaciones AS total_asig_resumen
FROM detalle_asignacion_mes d
JOIN resumen_mes_profesion r
  ON r.profesion = d.profesion
GROUP BY 
    d.profesion,
    r.total_asesorias,
    r.monto_total_honorarios,
    r.monto_total_asignaciones
ORDER BY d.profesion;

-- Ver resultados finales ordenados
SELECT *
FROM detalle_asignacion_mes
ORDER BY profesion, nombre_profesional;

SELECT *
FROM resumen_mes_profesion
ORDER BY profesion;

SELECT *
FROM errores_proceso
ORDER BY error_id;
