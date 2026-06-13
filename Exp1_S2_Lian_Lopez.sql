SET SERVEROUTPUT ON;

/* Variables BIND requeridas para el periodo y mes del proceso */
VARIABLE b_periodo VARCHAR2(6);
VARIABLE b_mes VARCHAR2(2);

EXEC :b_periodo := TO_CHAR(SYSDATE, 'MMYYYY');
EXEC :b_mes := TO_CHAR(SYSDATE, 'MM');

/* se limpia la tabla de resultados antes de iniciar el proceso */
TRUNCATE TABLE detalle_de_clientes;

DECLARE
    v_total_clientes NUMBER := 0;
    v_contador       NUMBER := 0;

    /* Variables escalares declaradas usando %TYPE */
    v_edad           detalle_de_clientes.edad%TYPE;
    v_puntaje        detalle_de_clientes.puntaje%TYPE;
    v_correo         detalle_de_clientes.correo_corp%TYPE;
    v_porcentaje     tramo_edad.porcentaje%TYPE;
    v_cliente        detalle_de_clientes.cliente%TYPE;

    /* Cursor que recupera todos los clientes que seran procesados uno a uno */
    CURSOR c_clientes IS
        SELECT 
            c.id_cli,
            c.numrun_cli,
            c.appaterno_cli,
            c.apmaterno_cli,
            c.pnombre_cli,
            c.fecha_nac_cli,
            c.renta,
            co.nombre_comuna,
            tc.nombre_tipo_cli
        FROM cliente c
        JOIN comuna co 
            ON c.id_comuna = co.id_comuna
        JOIN tipo_cliente tc 
            ON c.id_tipo_cli = tc.id_tipo_cli
        ORDER BY c.id_cli;

BEGIN
    DBMS_OUTPUT.PUT_LINE('PROCESANDO CLIENTES ...');

    /*obtiene el total de clientes para validar */
    SELECT COUNT(*)
    INTO v_total_clientes
    FROM cliente;

    FOR reg IN c_clientes LOOP
        v_puntaje := 0;

        /* calcula la edad del cliente segun su fecha de nacimiento */
        v_edad := TRUNC(MONTHS_BETWEEN(SYSDATE, reg.fecha_nac_cli) / 12);

        /* aplica las reglas de negocio para calcular el puntaje */
        IF reg.renta > 800000 
           AND reg.nombre_comuna NOT IN ('La Reina', 'Las Condes', 'Vitacura') THEN

            v_puntaje := ROUND(reg.renta * 0.03);

        ELSIF reg.nombre_tipo_cli IN ('VIP', 'Extranjero') THEN

            v_puntaje := ROUND(v_edad * 30);

        END IF;

        IF v_puntaje = 0 THEN
            /* obtiene el porcentaje segun edad */
            SELECT porcentaje
            INTO v_porcentaje
            FROM tramo_edad
            WHERE anno_vig = EXTRACT(YEAR FROM SYSDATE)
              AND v_edad BETWEEN tramo_inf AND tramo_sup;

            v_puntaje := ROUND(reg.renta * v_porcentaje / 100);
        END IF;

        v_cliente := reg.appaterno_cli || ' ' || reg.apmaterno_cli || ' ' || reg.pnombre_cli;

        v_correo := LOWER(reg.appaterno_cli)
                    || v_edad
                    || '*'
                    || SUBSTR(reg.pnombre_cli, 1, 1)
                    || TO_CHAR(reg.fecha_nac_cli, 'DD')
                    || :b_mes
                    || '@LogiCarg.cl';

        INSERT INTO detalle_de_clientes
        (
            idc,
            rut,
            cliente,
            edad,
            puntaje,
            correo_corp,
            periodo
        )
        VALUES
        (
            reg.id_cli,
            reg.numrun_cli,
            v_cliente,
            v_edad,
            v_puntaje,
            v_correo,
            SUBSTR(:b_periodo, 1, 2) || '/' || SUBSTR(:b_periodo, 3, 4)
        );

        v_contador := v_contador + 1;
    END LOOP;

    IF v_contador = v_total_clientes THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Proceso Finalizado Exitosamente');
        DBMS_OUTPUT.PUT_LINE('Se Procesaron : ' || v_contador || ' CLIENTES');
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Proceso Finalizado CON ERRORES - DESHACIENDO TRANSACCIONES');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Proceso Finalizado CON ERRORES - DESHACIENDO TRANSACCIONES');
END;
/

/* Consulta para visualizar el resultado */
SELECT *
FROM detalle_de_clientes
ORDER BY idc;
