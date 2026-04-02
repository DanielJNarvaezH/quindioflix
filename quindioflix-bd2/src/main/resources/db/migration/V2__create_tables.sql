-- =============================================================================
-- MOD-3: Creacion de Tablas con Restricciones y Comentarios — QuindioFlix
-- Script  : V2__create_tables.sql
-- Runner  : Flyway 9.22.3 (JDBC — no SQL*Plus)
-- Autores : Equipo QuindioFlix
-- Nota    : Todas las tablas del dominio principal van en
--           ts_quindioflix_datos. La tabla REPRODUCCIONES va en los
--           tablespaces de particion ts_quindioflix_reprod_2024 y
--           ts_quindioflix_reprod_2025 (PARTITION BY RANGE).
--           Los indices de PK y UNIQUE se crean en ts_quindioflix_indices.
-- =============================================================================

-- =============================================================================
-- 1. PLANES
--    Define los tres planes de suscripcion: Basico, Estandar, Premium.
--    Cada plan determina precio, calidad de video, pantallas simultaneas
--    y cantidad maxima de perfiles por cuenta.
-- =============================================================================
CREATE TABLE PLANES (
    id_plan           NUMBER(3)       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            VARCHAR2(30)    NOT NULL,
    precio_mensual    NUMBER(10,2)    NOT NULL,
    max_pantallas     NUMBER(1)       NOT NULL,
    calidad_video     VARCHAR2(10)    NOT NULL,
    max_perfiles      NUMBER(1)       NOT NULL,

    CONSTRAINT chk_planes_precio      CHECK (precio_mensual > 0),
    CONSTRAINT chk_planes_pantallas   CHECK (max_pantallas BETWEEN 1 AND 4),
    CONSTRAINT chk_planes_calidad     CHECK (calidad_video IN ('SD', 'HD', '4K')),
    CONSTRAINT chk_planes_perfiles    CHECK (max_perfiles BETWEEN 1 AND 5),
    CONSTRAINT uq_planes_nombre       UNIQUE (nombre)
        USING INDEX TABLESPACE ts_quindioflix_indices
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  PLANES                IS 'Planes de suscripcion disponibles en QuindioFlix (Basico, Estandar, Premium).';
COMMENT ON COLUMN PLANES.id_plan        IS 'Identificador unico del plan. Generado automaticamente.';
COMMENT ON COLUMN PLANES.nombre         IS 'Nombre del plan: Basico, Estandar o Premium.';
COMMENT ON COLUMN PLANES.precio_mensual IS 'Precio mensual del plan en pesos colombianos.';
COMMENT ON COLUMN PLANES.max_pantallas  IS 'Numero maximo de pantallas simultaneas permitidas por el plan.';
COMMENT ON COLUMN PLANES.calidad_video  IS 'Calidad maxima de video del plan: SD, HD o 4K.';
COMMENT ON COLUMN PLANES.max_perfiles   IS 'Numero maximo de perfiles que puede crear un usuario con este plan.';


-- =============================================================================
-- 2. DEPARTAMENTOS
--    Cinco departamentos de la empresa: Tecnologia, Contenido, Marketing,
--    Soporte y Finanzas. La FK hacia EMPLEADOS (id_jefe) es ciclica y se
--    agrega al final del script, despues de crear EMPLEADOS.
-- =============================================================================
CREATE TABLE DEPARTAMENTOS (
    id_departamento   NUMBER(3)       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            VARCHAR2(50)    NOT NULL,
    id_jefe           NUMBER(6)       DEFAULT NULL,   -- FK ciclica; se agrega al final

    CONSTRAINT uq_departamentos_nombre  UNIQUE (nombre)
        USING INDEX TABLESPACE ts_quindioflix_indices
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  DEPARTAMENTOS                 IS 'Departamentos de la empresa QuindioFlix.';
COMMENT ON COLUMN DEPARTAMENTOS.id_departamento IS 'Identificador unico del departamento.';
COMMENT ON COLUMN DEPARTAMENTOS.nombre          IS 'Nombre del departamento: Tecnologia, Contenido, Marketing, Soporte, Finanzas.';
COMMENT ON COLUMN DEPARTAMENTOS.id_jefe         IS 'FK hacia EMPLEADOS: empleado que dirige este departamento. Debe pertenecer al mismo departamento.';


-- =============================================================================
-- 3. EMPLEADOS
--    Personal de QuindioFlix con jerarquia de supervision interna.
--    Relacion reflexiva id_supervisor: cada empleado tiene a lo sumo un
--    supervisor directo (NULL si no tiene).
--    Empleados de Contenido publican contenido; empleados de Soporte
--    resuelven reportes de contenido inapropiado.
-- =============================================================================
CREATE TABLE EMPLEADOS (
    id_empleado       NUMBER(6)       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            VARCHAR2(80)    NOT NULL,
    apellido          VARCHAR2(80)    NOT NULL,
    email             VARCHAR2(120)   NOT NULL,
    cargo             VARCHAR2(60)    NOT NULL,
    fecha_ingreso     DATE            NOT NULL,
    salario           NUMBER(12,2)    NOT NULL,
    id_departamento   NUMBER(3)       NOT NULL,
    id_supervisor     NUMBER(6)       DEFAULT NULL,   -- FK reflexiva

    CONSTRAINT uq_empleados_email     UNIQUE (email)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT chk_empleados_salario  CHECK (salario > 0),
    CONSTRAINT fk_empleados_depto     FOREIGN KEY (id_departamento)
        REFERENCES DEPARTAMENTOS (id_departamento),
    CONSTRAINT fk_empleados_superv    FOREIGN KEY (id_supervisor)
        REFERENCES EMPLEADOS (id_empleado)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  EMPLEADOS                 IS 'Empleados de QuindioFlix con jerarquia de supervision y asignacion a departamento.';
COMMENT ON COLUMN EMPLEADOS.id_empleado     IS 'Identificador unico del empleado.';
COMMENT ON COLUMN EMPLEADOS.nombre          IS 'Nombre(s) del empleado.';
COMMENT ON COLUMN EMPLEADOS.apellido        IS 'Apellido(s) del empleado.';
COMMENT ON COLUMN EMPLEADOS.email           IS 'Correo electronico corporativo del empleado. Debe ser unico.';
COMMENT ON COLUMN EMPLEADOS.cargo           IS 'Cargo o titulo del empleado dentro de su departamento.';
COMMENT ON COLUMN EMPLEADOS.fecha_ingreso   IS 'Fecha en que el empleado ingreso a la empresa.';
COMMENT ON COLUMN EMPLEADOS.salario         IS 'Salario mensual del empleado en pesos colombianos.';
COMMENT ON COLUMN EMPLEADOS.id_departamento IS 'FK hacia DEPARTAMENTOS: departamento al que pertenece el empleado.';
COMMENT ON COLUMN EMPLEADOS.id_supervisor   IS 'FK reflexiva hacia EMPLEADOS: supervisor directo del empleado. NULL si no tiene supervisor.';

-- FK ciclica: ahora que EMPLEADOS existe, se agrega id_jefe en DEPARTAMENTOS
ALTER TABLE DEPARTAMENTOS
    ADD CONSTRAINT fk_departamentos_jefe
        FOREIGN KEY (id_jefe) REFERENCES EMPLEADOS (id_empleado);


-- =============================================================================
-- 4. CATEGORIAS
--    Clasificacion del contenido: Peliculas, Series, Documentales,
--    Musica, Podcasts.
-- =============================================================================
CREATE TABLE CATEGORIAS (
    id_categoria   NUMBER(3)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR2(50) NOT NULL,

    CONSTRAINT uq_categorias_nombre  UNIQUE (nombre)
        USING INDEX TABLESPACE ts_quindioflix_indices
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  CATEGORIAS              IS 'Categorias de contenido del catalogo QuindioFlix.';
COMMENT ON COLUMN CATEGORIAS.id_categoria IS 'Identificador unico de la categoria.';
COMMENT ON COLUMN CATEGORIAS.nombre       IS 'Nombre de la categoria: Peliculas, Series, Documentales, Musica, Podcasts.';


-- =============================================================================
-- 5. GENEROS
--    Generos disponibles en el catalogo: Accion, Comedia, Drama, etc.
--    Un contenido puede pertenecer a multiples generos (N:M via
--    CONTENIDO_GENEROS).
-- =============================================================================
CREATE TABLE GENEROS (
    id_genero   NUMBER(3)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR2(50) NOT NULL,

    CONSTRAINT uq_generos_nombre  UNIQUE (nombre)
        USING INDEX TABLESPACE ts_quindioflix_indices
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  GENEROS           IS 'Generos cinematograficos y musicales disponibles en QuindioFlix.';
COMMENT ON COLUMN GENEROS.id_genero IS 'Identificador unico del genero.';
COMMENT ON COLUMN GENEROS.nombre    IS 'Nombre del genero: Accion, Comedia, Drama, Suspenso, Ciencia Ficcion, etc.';


-- =============================================================================
-- 6. CONTENIDO
--    Entidad central del catalogo. Almacena peliculas, series,
--    documentales, musica y podcasts bajo una misma tabla.
--    Las series y podcasts tienen temporadas; las peliculas no.
--    Cada contenido tiene un empleado responsable de su publicacion.
-- =============================================================================
CREATE TABLE CONTENIDO (
    id_contenido              NUMBER(8)       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titulo                    VARCHAR2(200)   NOT NULL,
    sinopsis                  VARCHAR2(2000)  DEFAULT NULL,
    anio_lanzamiento          NUMBER(4)       NOT NULL,
    duracion_min              NUMBER(5)       DEFAULT NULL,
    clasificacion_edad        VARCHAR2(5)     NOT NULL,
    es_original_quindioflix   CHAR(1)         DEFAULT 'N' NOT NULL,
    popularidad               NUMBER(10,2)    DEFAULT 0   NOT NULL,
    fecha_publicacion         DATE            DEFAULT SYSDATE NOT NULL,
    estado                    VARCHAR2(10)    DEFAULT 'ACTIVO' NOT NULL,
    id_categoria              NUMBER(3)       NOT NULL,
    id_empleado_publicacion   NUMBER(6)       NOT NULL,

    CONSTRAINT chk_contenido_clasificacion  CHECK (clasificacion_edad IN ('TP', '+7', '+13', '+16', '+18')),
    CONSTRAINT chk_contenido_original       CHECK (es_original_quindioflix IN ('S', 'N')),
    CONSTRAINT chk_contenido_popularidad    CHECK (popularidad >= 0),
    CONSTRAINT chk_contenido_anio           CHECK (anio_lanzamiento BETWEEN 1888 AND 2100),
    CONSTRAINT chk_contenido_estado         CHECK (estado IN ('ACTIVO', 'INACTIVO', 'PROXIMAMENTE')),
    CONSTRAINT fk_contenido_categoria       FOREIGN KEY (id_categoria)
        REFERENCES CATEGORIAS (id_categoria),
    CONSTRAINT fk_contenido_empleado        FOREIGN KEY (id_empleado_publicacion)
        REFERENCES EMPLEADOS (id_empleado)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  CONTENIDO                           IS 'Catalogo central de QuindioFlix: peliculas, series, documentales, musica y podcasts.';
COMMENT ON COLUMN CONTENIDO.id_contenido              IS 'Identificador unico del contenido.';
COMMENT ON COLUMN CONTENIDO.titulo                    IS 'Titulo oficial del contenido.';
COMMENT ON COLUMN CONTENIDO.sinopsis                  IS 'Descripcion o resumen del contenido. Puede ser NULL.';
COMMENT ON COLUMN CONTENIDO.anio_lanzamiento          IS 'Año de lanzamiento original del contenido.';
COMMENT ON COLUMN CONTENIDO.duracion_min              IS 'Duracion en minutos. Para series y podcasts puede ser NULL (la duracion esta en cada episodio).';
COMMENT ON COLUMN CONTENIDO.clasificacion_edad        IS 'Clasificacion de edad: TP, +7, +13, +16 o +18. Determina acceso desde perfiles infantiles.';
COMMENT ON COLUMN CONTENIDO.es_original_quindioflix   IS 'S si es produccion propia de QuindioFlix; N si es contenido licenciado.';
COMMENT ON COLUMN CONTENIDO.popularidad               IS 'Indicador de popularidad calculado a partir de reproducciones y calificaciones.';
COMMENT ON COLUMN CONTENIDO.fecha_publicacion         IS 'Fecha en que el contenido fue publicado en la plataforma.';
COMMENT ON COLUMN CONTENIDO.estado                    IS 'Estado del contenido: ACTIVO (disponible), INACTIVO (retirado), PROXIMAMENTE (anunciado).';
COMMENT ON COLUMN CONTENIDO.id_categoria              IS 'FK hacia CATEGORIAS: categoria a la que pertenece el contenido.';
COMMENT ON COLUMN CONTENIDO.id_empleado_publicacion   IS 'FK hacia EMPLEADOS: empleado del departamento Contenido responsable de la publicacion.';


-- =============================================================================
-- 7. CONTENIDO_GENEROS
--    Tabla intermedia N:M entre CONTENIDO y GENEROS.
--    Un contenido puede pertenecer a varios generos;
--    un genero puede estar en multiples contenidos.
-- =============================================================================
CREATE TABLE CONTENIDO_GENEROS (
    id_contenido   NUMBER(8)   NOT NULL,
    id_genero      NUMBER(3)   NOT NULL,

    CONSTRAINT pk_contenido_generos   PRIMARY KEY (id_contenido, id_genero)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT fk_cg_contenido        FOREIGN KEY (id_contenido)
        REFERENCES CONTENIDO (id_contenido),
    CONSTRAINT fk_cg_genero           FOREIGN KEY (id_genero)
        REFERENCES GENEROS (id_genero)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  CONTENIDO_GENEROS              IS 'Tabla intermedia N:M que asocia cada contenido con sus generos.';
COMMENT ON COLUMN CONTENIDO_GENEROS.id_contenido IS 'FK hacia CONTENIDO. Parte de la clave primaria compuesta.';
COMMENT ON COLUMN CONTENIDO_GENEROS.id_genero    IS 'FK hacia GENEROS. Parte de la clave primaria compuesta.';


-- =============================================================================
-- 8. CONTENIDO_RELACIONADO
--    Tabla intermedia N:M reflexiva sobre CONTENIDO.
--    Relaciona contenidos entre si: secuelas, precuelas, remakes, spin-offs.
--    La relacion es dirigida: id_origen -> id_destino con un tipo de relacion.
-- =============================================================================
CREATE TABLE CONTENIDO_RELACIONADO (
    id_origen        NUMBER(8)     NOT NULL,
    id_destino       NUMBER(8)     NOT NULL,
    tipo_relacion    VARCHAR2(20)  NOT NULL,

    CONSTRAINT pk_contenido_relacionado   PRIMARY KEY (id_origen, id_destino)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT chk_cr_tipo_relacion       CHECK (tipo_relacion IN ('SECUELA', 'PRECUELA', 'REMAKE', 'SPIN-OFF', 'ADAPTACION')),
    CONSTRAINT chk_cr_no_self             CHECK (id_origen <> id_destino),
    CONSTRAINT fk_cr_origen               FOREIGN KEY (id_origen)
        REFERENCES CONTENIDO (id_contenido),
    CONSTRAINT fk_cr_destino              FOREIGN KEY (id_destino)
        REFERENCES CONTENIDO (id_contenido)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  CONTENIDO_RELACIONADO              IS 'Tabla intermedia N:M reflexiva que registra relaciones entre contenidos (secuelas, remakes, etc.).';
COMMENT ON COLUMN CONTENIDO_RELACIONADO.id_origen    IS 'FK hacia CONTENIDO: contenido de origen de la relacion.';
COMMENT ON COLUMN CONTENIDO_RELACIONADO.id_destino   IS 'FK hacia CONTENIDO: contenido de destino de la relacion.';
COMMENT ON COLUMN CONTENIDO_RELACIONADO.tipo_relacion IS 'Tipo de relacion: SECUELA, PRECUELA, REMAKE, SPIN-OFF o ADAPTACION.';


-- =============================================================================
-- 9. TEMPORADAS
--    Organiza series y podcasts en temporadas numeradas.
--    Las peliculas, documentales y musica no tienen temporadas.
-- =============================================================================
CREATE TABLE TEMPORADAS (
    id_temporada       NUMBER(8)       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_temporada   NUMBER(3)       NOT NULL,
    titulo_temporada   VARCHAR2(200)   DEFAULT NULL,
    anio_estreno       NUMBER(4)       DEFAULT NULL,
    id_contenido       NUMBER(8)       NOT NULL,

    CONSTRAINT uq_temporadas_numero   UNIQUE (id_contenido, numero_temporada)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT chk_temporadas_numero  CHECK (numero_temporada >= 1),
    CONSTRAINT fk_temporadas_contenido FOREIGN KEY (id_contenido)
        REFERENCES CONTENIDO (id_contenido)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  TEMPORADAS                   IS 'Temporadas de series y podcasts del catalogo QuindioFlix.';
COMMENT ON COLUMN TEMPORADAS.id_temporada      IS 'Identificador unico de la temporada.';
COMMENT ON COLUMN TEMPORADAS.numero_temporada  IS 'Numero de temporada dentro del contenido (1, 2, 3...).';
COMMENT ON COLUMN TEMPORADAS.titulo_temporada  IS 'Titulo opcional de la temporada.';
COMMENT ON COLUMN TEMPORADAS.anio_estreno      IS 'Año en que se estreno esta temporada. Puede ser NULL.';
COMMENT ON COLUMN TEMPORADAS.id_contenido      IS 'FK hacia CONTENIDO: contenido (serie o podcast) al que pertenece esta temporada.';


-- =============================================================================
-- 10. EPISODIOS
--     Episodios que pertenecen a una temporada.
--     La duracion se registra aqui (no en CONTENIDO) para series/podcasts.
-- =============================================================================
CREATE TABLE EPISODIOS (
    id_episodio        NUMBER(10)      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_episodio    NUMBER(4)       NOT NULL,
    titulo_episodio    VARCHAR2(200)   NOT NULL,
    duracion_min       NUMBER(5)       NOT NULL,
    sinopsis           VARCHAR2(2000)  DEFAULT NULL,
    id_temporada       NUMBER(8)       NOT NULL,

    CONSTRAINT uq_episodios_numero    UNIQUE (id_temporada, numero_episodio)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT chk_episodios_numero   CHECK (numero_episodio >= 1),
    CONSTRAINT chk_episodios_duracion CHECK (duracion_min > 0),
    CONSTRAINT fk_episodios_temporada FOREIGN KEY (id_temporada)
        REFERENCES TEMPORADAS (id_temporada)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  EPISODIOS                 IS 'Episodios de cada temporada de series y podcasts.';
COMMENT ON COLUMN EPISODIOS.id_episodio     IS 'Identificador unico del episodio.';
COMMENT ON COLUMN EPISODIOS.numero_episodio IS 'Numero del episodio dentro de su temporada.';
COMMENT ON COLUMN EPISODIOS.titulo_episodio IS 'Titulo oficial del episodio.';
COMMENT ON COLUMN EPISODIOS.duracion_min    IS 'Duracion del episodio en minutos.';
COMMENT ON COLUMN EPISODIOS.sinopsis        IS 'Descripcion del episodio. Puede ser NULL.';
COMMENT ON COLUMN EPISODIOS.id_temporada    IS 'FK hacia TEMPORADAS: temporada a la que pertenece este episodio.';


-- =============================================================================
-- 11. USUARIOS
--     Cuentas registradas en la plataforma. Cada usuario elige un plan,
--     puede haber sido referido por otro usuario (FK reflexiva) y puede
--     actuar como moderador (es_moderador = 'S').
-- =============================================================================
CREATE TABLE USUARIOS (
    id_usuario          NUMBER(8)       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre              VARCHAR2(80)    NOT NULL,
    apellido            VARCHAR2(80)    NOT NULL,
    email               VARCHAR2(120)   NOT NULL,
    contrasena_hash     VARCHAR2(256)   NOT NULL,
    fecha_registro      DATE            DEFAULT SYSDATE NOT NULL,
    fecha_vencimiento   DATE            NOT NULL,
    estado_cuenta       VARCHAR2(10)    DEFAULT 'ACTIVO' NOT NULL,
    es_moderador        CHAR(1)         DEFAULT 'N'      NOT NULL,
    ciudad              VARCHAR2(80)    DEFAULT NULL,
    id_plan             NUMBER(3)       NOT NULL,
    id_referidor        NUMBER(8)       DEFAULT NULL,   -- FK reflexiva

    CONSTRAINT uq_usuarios_email      UNIQUE (email)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT chk_usuarios_estado    CHECK (estado_cuenta IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO')),
    CONSTRAINT chk_usuarios_moderador CHECK (es_moderador IN ('S', 'N')),
    CONSTRAINT fk_usuarios_plan       FOREIGN KEY (id_plan)
        REFERENCES PLANES (id_plan),
    CONSTRAINT fk_usuarios_referidor  FOREIGN KEY (id_referidor)
        REFERENCES USUARIOS (id_usuario)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  USUARIOS                    IS 'Cuentas de usuario registradas en la plataforma QuindioFlix.';
COMMENT ON COLUMN USUARIOS.id_usuario         IS 'Identificador unico del usuario.';
COMMENT ON COLUMN USUARIOS.nombre             IS 'Nombre(s) del usuario.';
COMMENT ON COLUMN USUARIOS.apellido           IS 'Apellido(s) del usuario.';
COMMENT ON COLUMN USUARIOS.email              IS 'Correo electronico del usuario. Unico en la plataforma y usado para el login.';
COMMENT ON COLUMN USUARIOS.contrasena_hash    IS 'Hash de la contrasena del usuario (nunca texto plano).';
COMMENT ON COLUMN USUARIOS.fecha_registro     IS 'Fecha en que el usuario creo su cuenta.';
COMMENT ON COLUMN USUARIOS.fecha_vencimiento  IS 'Fecha en que vence la suscripcion activa del usuario.';
COMMENT ON COLUMN USUARIOS.estado_cuenta      IS 'Estado de la cuenta: ACTIVO, INACTIVO (sin pago > 30 dias) o SUSPENDIDO.';
COMMENT ON COLUMN USUARIOS.es_moderador       IS 'S si el usuario tiene rol de moderador (puede resolver reportes); N en caso contrario.';
COMMENT ON COLUMN USUARIOS.ciudad             IS 'Ciudad de residencia del usuario. Usada en reportes de consumo por ciudad.';
COMMENT ON COLUMN USUARIOS.id_plan            IS 'FK hacia PLANES: plan de suscripcion activo del usuario.';
COMMENT ON COLUMN USUARIOS.id_referidor       IS 'FK reflexiva hacia USUARIOS: usuario que refirio a este usuario. NULL si no fue referido.';


-- =============================================================================
-- 12. PERFILES
--     Perfiles por cuenta de usuario. El maximo depende del plan.
--     Los perfiles infantiles solo acceden a clasificaciones TP, +7, +13.
-- =============================================================================
CREATE TABLE PERFILES (
    id_perfil     NUMBER(8)     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR2(60)  NOT NULL,
    tipo_perfil   VARCHAR2(10)  DEFAULT 'ADULTO' NOT NULL,
    avatar        VARCHAR2(200) DEFAULT NULL,
    id_usuario    NUMBER(8)     NOT NULL,

    CONSTRAINT chk_perfiles_tipo    CHECK (tipo_perfil IN ('ADULTO', 'INFANTIL')),
    CONSTRAINT fk_perfiles_usuario  FOREIGN KEY (id_usuario)
        REFERENCES USUARIOS (id_usuario)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  PERFILES             IS 'Perfiles de visualizacion asociados a cada cuenta de usuario.';
COMMENT ON COLUMN PERFILES.id_perfil   IS 'Identificador unico del perfil.';
COMMENT ON COLUMN PERFILES.nombre      IS 'Nombre del perfil (ej: Papa, Mama, Ninos).';
COMMENT ON COLUMN PERFILES.tipo_perfil IS 'ADULTO: acceso a todo el catalogo. INFANTIL: acceso restringido a TP, +7 y +13.';
COMMENT ON COLUMN PERFILES.avatar      IS 'URL o ruta del avatar seleccionado por el perfil. Puede ser NULL.';
COMMENT ON COLUMN PERFILES.id_usuario  IS 'FK hacia USUARIOS: cuenta propietaria de este perfil.';


-- =============================================================================
-- 13. PAGOS
--     Registro de cada cobro mensual realizado por un usuario.
--     Incluye metodo, estado, monto y descuento por programa de referidos.
-- =============================================================================
CREATE TABLE PAGOS (
    id_pago              NUMBER(10)      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_pago           DATE            DEFAULT SYSDATE NOT NULL,
    monto                NUMBER(10,2)    NOT NULL,
    metodo_pago          VARCHAR2(20)    NOT NULL,
    estado_pago          VARCHAR2(15)    DEFAULT 'PENDIENTE' NOT NULL,
    descuento_aplicado   NUMBER(5,2)     DEFAULT 0           NOT NULL,
    id_usuario           NUMBER(8)       NOT NULL,

    CONSTRAINT chk_pagos_monto      CHECK (monto > 0),
    CONSTRAINT chk_pagos_metodo     CHECK (metodo_pago IN ('TARJETA', 'PSE', 'EFECTIVO', 'NEQUI', 'DAVIPLATA')),
    CONSTRAINT chk_pagos_estado     CHECK (estado_pago IN ('PENDIENTE', 'APROBADO', 'RECHAZADO', 'REEMBOLSADO')),
    CONSTRAINT chk_pagos_descuento  CHECK (descuento_aplicado BETWEEN 0 AND 100),
    CONSTRAINT fk_pagos_usuario     FOREIGN KEY (id_usuario)
        REFERENCES USUARIOS (id_usuario)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  PAGOS                    IS 'Registro de cobros mensuales realizados por los usuarios de QuindioFlix.';
COMMENT ON COLUMN PAGOS.id_pago            IS 'Identificador unico del pago.';
COMMENT ON COLUMN PAGOS.fecha_pago         IS 'Fecha en que se realizo o registro el pago.';
COMMENT ON COLUMN PAGOS.monto              IS 'Monto cobrado en pesos colombianos (despues de aplicar descuentos).';
COMMENT ON COLUMN PAGOS.metodo_pago        IS 'Medio de pago utilizado: TARJETA, PSE, EFECTIVO, NEQUI o DAVIPLATA.';
COMMENT ON COLUMN PAGOS.estado_pago        IS 'Estado del pago: PENDIENTE, APROBADO, RECHAZADO o REEMBOLSADO.';
COMMENT ON COLUMN PAGOS.descuento_aplicado IS 'Porcentaje de descuento aplicado por programa de referidos (0 a 100).';
COMMENT ON COLUMN PAGOS.id_usuario         IS 'FK hacia USUARIOS: usuario que realizo este pago.';


-- =============================================================================
-- 14. REPRODUCCIONES
--     Registro de cada sesion de reproduccion. Es la tabla de mayor
--     volumen del sistema. Se particiona por RANGE sobre fecha_hora_inicio
--     para separar datos historicos por anio y mejorar rendimiento de
--     reportes de consumo por periodo.
--     p_2024 -> ts_quindioflix_reprod_2024
--     p_2025 -> ts_quindioflix_reprod_2025
-- =============================================================================
CREATE TABLE REPRODUCCIONES (
    id_reproduccion      NUMBER(12)      GENERATED ALWAYS AS IDENTITY,
    fecha_hora_inicio    TIMESTAMP       NOT NULL,
    fecha_hora_fin       TIMESTAMP       DEFAULT NULL,
    dispositivo          VARCHAR2(15)    NOT NULL,
    porcentaje_avance    NUMBER(5,2)     DEFAULT 0   NOT NULL,
    id_perfil            NUMBER(8)       NOT NULL,
    id_contenido         NUMBER(8)       NOT NULL,
    id_episodio          NUMBER(10)      DEFAULT NULL,

    CONSTRAINT pk_reproducciones           PRIMARY KEY (id_reproduccion, fecha_hora_inicio),
    CONSTRAINT chk_reprod_dispositivo      CHECK (dispositivo IN ('CELULAR', 'TABLET', 'TV', 'COMPUTADOR')),
    CONSTRAINT chk_reprod_avance           CHECK (porcentaje_avance BETWEEN 0 AND 100),
    CONSTRAINT chk_reprod_fechas           CHECK (fecha_hora_fin IS NULL OR fecha_hora_fin >= fecha_hora_inicio),
    CONSTRAINT fk_reprod_perfil            FOREIGN KEY (id_perfil)
        REFERENCES PERFILES (id_perfil),
    CONSTRAINT fk_reprod_contenido         FOREIGN KEY (id_contenido)
        REFERENCES CONTENIDO (id_contenido),
    CONSTRAINT fk_reprod_episodio          FOREIGN KEY (id_episodio)
        REFERENCES EPISODIOS (id_episodio)
)
PARTITION BY RANGE (fecha_hora_inicio) (
    PARTITION p_2024
        VALUES LESS THAN (TIMESTAMP '2025-01-01 00:00:00')
        TABLESPACE ts_quindioflix_reprod_2024,
    PARTITION p_2025
        VALUES LESS THAN (TIMESTAMP '2026-01-01 00:00:00')
        TABLESPACE ts_quindioflix_reprod_2025
);

COMMENT ON TABLE  REPRODUCCIONES                  IS 'Registro de cada sesion de reproduccion. Tabla de mayor volumen; particionada por anio sobre fecha_hora_inicio.';
COMMENT ON COLUMN REPRODUCCIONES.id_reproduccion  IS 'Identificador unico de la reproduccion. Parte de la PK compuesta con fecha_hora_inicio.';
COMMENT ON COLUMN REPRODUCCIONES.fecha_hora_inicio IS 'Fecha y hora en que inicio la reproduccion. Define la particion (2024 o 2025).';
COMMENT ON COLUMN REPRODUCCIONES.fecha_hora_fin    IS 'Fecha y hora en que termino la reproduccion. NULL si la sesion esta activa.';
COMMENT ON COLUMN REPRODUCCIONES.dispositivo       IS 'Dispositivo usado: CELULAR, TABLET, TV o COMPUTADOR.';
COMMENT ON COLUMN REPRODUCCIONES.porcentaje_avance IS 'Porcentaje del contenido reproducido (0 a 100). Base para calcular popularidad.';
COMMENT ON COLUMN REPRODUCCIONES.id_perfil         IS 'FK hacia PERFILES: perfil que realizo la reproduccion.';
COMMENT ON COLUMN REPRODUCCIONES.id_contenido      IS 'FK hacia CONTENIDO: contenido que se reprodujo.';
COMMENT ON COLUMN REPRODUCCIONES.id_episodio       IS 'FK hacia EPISODIOS: episodio reproducido. NULL si el contenido no tiene episodios.';


-- =============================================================================
-- 15. CALIFICACIONES
--     Calificacion de 1 a 5 estrellas con resena opcional.
--     Un perfil puede calificar un contenido como maximo una vez
--     (UNIQUE sobre id_perfil, id_contenido).
-- =============================================================================
CREATE TABLE CALIFICACIONES (
    id_calificacion   NUMBER(10)      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    estrellas         NUMBER(1)       NOT NULL,
    resena            VARCHAR2(2000)  DEFAULT NULL,
    fecha_calificacion DATE           DEFAULT SYSDATE NOT NULL,
    id_perfil         NUMBER(8)       NOT NULL,
    id_contenido      NUMBER(8)       NOT NULL,

    CONSTRAINT uq_calificaciones_perfil_cont  UNIQUE (id_perfil, id_contenido)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT chk_calificaciones_estrellas   CHECK (estrellas BETWEEN 1 AND 5),
    CONSTRAINT fk_calificaciones_perfil       FOREIGN KEY (id_perfil)
        REFERENCES PERFILES (id_perfil),
    CONSTRAINT fk_calificaciones_contenido    FOREIGN KEY (id_contenido)
        REFERENCES CONTENIDO (id_contenido)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  CALIFICACIONES                    IS 'Calificaciones de contenido realizadas por los perfiles de usuario.';
COMMENT ON COLUMN CALIFICACIONES.id_calificacion    IS 'Identificador unico de la calificacion.';
COMMENT ON COLUMN CALIFICACIONES.estrellas          IS 'Puntuacion del contenido: entre 1 y 5 estrellas.';
COMMENT ON COLUMN CALIFICACIONES.resena             IS 'Resena textual opcional que acompana la calificacion.';
COMMENT ON COLUMN CALIFICACIONES.fecha_calificacion IS 'Fecha en que se registro la calificacion.';
COMMENT ON COLUMN CALIFICACIONES.id_perfil          IS 'FK hacia PERFILES: perfil que califica.';
COMMENT ON COLUMN CALIFICACIONES.id_contenido       IS 'FK hacia CONTENIDO: contenido calificado.';


-- =============================================================================
-- 16. FAVORITOS
--     Lista personal de contenido favorito por perfil.
--     Un perfil no puede agregar el mismo contenido dos veces
--     (UNIQUE sobre id_perfil, id_contenido).
-- =============================================================================
CREATE TABLE FAVORITOS (
    id_favorito    NUMBER(10)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_agregado DATE         DEFAULT SYSDATE NOT NULL,
    id_perfil      NUMBER(8)    NOT NULL,
    id_contenido   NUMBER(8)    NOT NULL,

    CONSTRAINT uq_favoritos_perfil_cont  UNIQUE (id_perfil, id_contenido)
        USING INDEX TABLESPACE ts_quindioflix_indices,
    CONSTRAINT fk_favoritos_perfil       FOREIGN KEY (id_perfil)
        REFERENCES PERFILES (id_perfil),
    CONSTRAINT fk_favoritos_contenido    FOREIGN KEY (id_contenido)
        REFERENCES CONTENIDO (id_contenido)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  FAVORITOS               IS 'Lista de contenido marcado como favorito por cada perfil.';
COMMENT ON COLUMN FAVORITOS.id_favorito   IS 'Identificador unico del registro de favorito.';
COMMENT ON COLUMN FAVORITOS.fecha_agregado IS 'Fecha en que el perfil agrego el contenido a favoritos.';
COMMENT ON COLUMN FAVORITOS.id_perfil     IS 'FK hacia PERFILES: perfil propietario de la lista de favoritos.';
COMMENT ON COLUMN FAVORITOS.id_contenido  IS 'FK hacia CONTENIDO: contenido agregado a favoritos.';


-- =============================================================================
-- 17. REPORTES_INAPROPIADO
--     Reporte de contenido inadecuado por un perfil. Los reportes son
--     atendidos por moderadores (usuarios con es_moderador = 'S').
--     id_moderador es NULL hasta que un moderador toma el reporte.
-- =============================================================================
CREATE TABLE REPORTES_INAPROPIADO (
    id_reporte         NUMBER(10)      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    motivo             VARCHAR2(500)   NOT NULL,
    estado_reporte     VARCHAR2(15)    DEFAULT 'PENDIENTE' NOT NULL,
    fecha_reporte      DATE            DEFAULT SYSDATE     NOT NULL,
    fecha_resolucion   DATE            DEFAULT NULL,
    id_perfil_reporta  NUMBER(8)       NOT NULL,
    id_contenido       NUMBER(8)       NOT NULL,
    id_moderador       NUMBER(8)       DEFAULT NULL,

    CONSTRAINT chk_reportes_estado    CHECK (estado_reporte IN ('PENDIENTE', 'EN_REVISION', 'RESUELTO', 'DESCARTADO')),
    CONSTRAINT chk_reportes_fechas    CHECK (fecha_resolucion IS NULL OR fecha_resolucion >= fecha_reporte),
    CONSTRAINT fk_reportes_perfil     FOREIGN KEY (id_perfil_reporta)
        REFERENCES PERFILES (id_perfil),
    CONSTRAINT fk_reportes_contenido  FOREIGN KEY (id_contenido)
        REFERENCES CONTENIDO (id_contenido),
    CONSTRAINT fk_reportes_moderador  FOREIGN KEY (id_moderador)
        REFERENCES USUARIOS (id_usuario)
) TABLESPACE ts_quindioflix_datos;

COMMENT ON TABLE  REPORTES_INAPROPIADO                IS 'Reportes de contenido inapropiado realizados por perfiles de usuario.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.id_reporte     IS 'Identificador unico del reporte.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.motivo         IS 'Descripcion del motivo por el que se reporta el contenido.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.estado_reporte IS 'Estado del reporte: PENDIENTE, EN_REVISION, RESUELTO o DESCARTADO.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.fecha_reporte  IS 'Fecha en que se realizo el reporte.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.fecha_resolucion IS 'Fecha en que el moderador resolvio el reporte. NULL si aun esta pendiente.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.id_perfil_reporta IS 'FK hacia PERFILES: perfil que realizo el reporte.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.id_contenido   IS 'FK hacia CONTENIDO: contenido reportado como inapropiado.';
COMMENT ON COLUMN REPORTES_INAPROPIADO.id_moderador   IS 'FK hacia USUARIOS: moderador asignado para resolver el reporte. NULL hasta asignacion.';

-- =============================================================================
-- FIN DEL SCRIPT V2__create_tables.sql
-- Tablas creadas: 17
--   PLANES, DEPARTAMENTOS, EMPLEADOS, CATEGORIAS, GENEROS,
--   CONTENIDO, CONTENIDO_GENEROS, CONTENIDO_RELACIONADO,
--   TEMPORADAS, EPISODIOS, USUARIOS, PERFILES, PAGOS,
--   REPRODUCCIONES (particionada), CALIFICACIONES, FAVORITOS,
--   REPORTES_INAPROPIADO
-- Tablespaces usados:
--   ts_quindioflix_datos    -> todas las tablas excepto REPRODUCCIONES
--   ts_quindioflix_indices  -> todos los indices PK y UNIQUE
--   ts_quindioflix_reprod_2024 -> particion p_2024 de REPRODUCCIONES
--   ts_quindioflix_reprod_2025 -> particion p_2025 de REPRODUCCIONES
-- =============================================================================
