SET SERVEROUTPUT ON SIZE UNLIMITED;

-- PRUEBA 3: EMAIL_DUPLICADO
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO(
        p_nombre          => 'Sofia',
        p_apellido        => 'Duplicada',
        p_email           => 'sofia.perea@quindioflix.com',
        p_contrasena_hash => 'hash_dup',
        p_ciudad          => 'Armenia',
        p_id_plan         => 1,
        p_id_usuario      => v_id
    );
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado: ' || SQLERRM);
END;
/

-- PRUEBA 4: PLAN_NO_EXISTE
DECLARE
v_id NUMBER;
BEGIN
    SP_REGISTRAR_USUARIO(
        p_nombre          => 'Ana',
        p_apellido        => 'Test',
        p_email           => 'ana.test@test.com',
        p_contrasena_hash => 'hash_test_003',
        p_ciudad          => 'Pereira',
        p_id_plan         => 99,
        p_id_usuario      => v_id
    );
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR capturado: ' || SQLERRM);
END;
/