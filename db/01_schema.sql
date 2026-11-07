-- =====================================================
-- TP Base de Datos - GRUPO 2
-- 01_ddl.sql : creación de la base de datos y las tablas
-- Orden de ejecución: 01_ddl.sql -> 02_triggers.sql -> 03_views.sql
-- MySQL 8.0.16+ (necesario para los CHECK)
-- =====================================================

DROP DATABASE IF EXISTS tp_bd_grupo2;
CREATE DATABASE tp_bd_grupo2
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE tp_bd_grupo2;

-- =====================================================
-- TABLAS
-- =====================================================

-- GRUPO FAMILIAR
CREATE TABLE grupo_familiar (
    nro_base        INT            NOT NULL,
    num_telefono    VARCHAR(20)    NOT NULL,
    domicilio       VARCHAR(150)   NOT NULL,
    deuda_total     DECIMAL(12,2)  NOT NULL DEFAULT 0,
    CONSTRAINT pk_grupo_familiar PRIMARY KEY (nro_base),
    -- RA 10: rangos
    CONSTRAINT ck_grupo_deuda_total CHECK (deuda_total >= 0)
) ENGINE=InnoDB;

-- CATEGORIA
-- RA 10: descuento puede ser negativo (= incremento). Solo se exige que sea < 100.
CREATE TABLE categoria (
    tipo_categoria  VARCHAR(30)    NOT NULL,
    descuento       DECIMAL(6,2)   NOT NULL DEFAULT 0,
    CONSTRAINT pk_categoria PRIMARY KEY (tipo_categoria),
    CONSTRAINT ck_categoria_descuento CHECK (descuento < 100)
) ENGINE=InnoDB;

-- SOCIO
CREATE TABLE socio (
    nro_base            INT            NOT NULL,
    nro_orden           INT            NOT NULL,
    nombre              VARCHAR(100)   NOT NULL,
    correo_electronico  VARCHAR(120)   NULL,
    fecha_nacimiento    DATE           NOT NULL,
    deuda_actividad     DECIMAL(12,2)  NOT NULL DEFAULT 0,
    is_titular          BOOLEAN        NOT NULL DEFAULT FALSE,
    tipo_categoria      VARCHAR(30)    NOT NULL,
    CONSTRAINT pk_socio PRIMARY KEY (nro_base, nro_orden),
    CONSTRAINT fk_socio_grupo FOREIGN KEY (nro_base)
        REFERENCES grupo_familiar (nro_base)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_socio_categoria FOREIGN KEY (tipo_categoria)
        REFERENCES categoria (tipo_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- RA 10: rangos
    CONSTRAINT ck_socio_deuda CHECK (deuda_actividad >= 0),
    -- RA 2: el titular es siempre NroOrden = 0 (y solo el titular tiene 0).
    --       Esto garantiza un único titular por grupo.
    -- RA 3 (parcial): is_titular coherente con nro_orden
    CONSTRAINT ck_socio_titular_orden CHECK (
        (is_titular = TRUE  AND nro_orden = 0) OR
        (is_titular = FALSE AND nro_orden > 0)
    )
) ENGINE=InnoDB;

-- SOCIO TITULAR
CREATE TABLE socio_titular (
    nro_base        INT            NOT NULL,
    nro_orden       INT            NOT NULL,
    nro_celular     VARCHAR(20)    NOT NULL,
    CONSTRAINT pk_socio_titular PRIMARY KEY (nro_base, nro_orden),
    CONSTRAINT fk_titular_socio FOREIGN KEY (nro_base, nro_orden)
        REFERENCES socio (nro_base, nro_orden)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- MONTO BASE
CREATE TABLE monto_base (
    id_monto_base   INT            NOT NULL AUTO_INCREMENT,
    valor           DECIMAL(12,2)  NOT NULL,
    fecha_inicio    DATE           NOT NULL,
    fecha_fin       DATE           NOT NULL,
    CONSTRAINT pk_monto_base PRIMARY KEY (id_monto_base),
    CONSTRAINT uq_monto_base_fechas UNIQUE (fecha_inicio, fecha_fin),
    CONSTRAINT ck_monto_base_fechas CHECK (fecha_inicio < fecha_fin),
    CONSTRAINT ck_monto_base_valor CHECK (valor >= 0)
) ENGINE=InnoDB;

-- CUOTA SOCIAL
CREATE TABLE cuota_social (
    id_cuota            INT            NOT NULL AUTO_INCREMENT,
    fecha_vencimiento   DATE           NOT NULL,
    monto_abonado       DECIMAL(12,2)  NOT NULL DEFAULT 0,
    monto_a_pagar       DECIMAL(12,2)  NOT NULL DEFAULT 0,  -- RA 9: lo calcula el trigger
    nro_base            INT            NOT NULL,
    nro_orden           INT            NOT NULL,
    id_monto_base       INT            NOT NULL,
    CONSTRAINT pk_cuota_social PRIMARY KEY (id_cuota),
    CONSTRAINT fk_cuota_titular FOREIGN KEY (nro_base, nro_orden)
        REFERENCES socio_titular (nro_base, nro_orden)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_cuota_monto_base FOREIGN KEY (id_monto_base)
        REFERENCES monto_base (id_monto_base)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- RA 10: rangos
    CONSTRAINT ck_cuota_montos CHECK (monto_abonado >= 0 AND monto_a_pagar >= 0),
    CONSTRAINT ck_cuota_abonado_max CHECK (monto_abonado <= monto_a_pagar)
) ENGINE=InnoDB;

-- PROFESIONAL
CREATE TABLE profesional (
    id_profesional  INT            NOT NULL AUTO_INCREMENT,
    dni             VARCHAR(15)    NOT NULL,
    nombre          VARCHAR(100)   NOT NULL,
    CONSTRAINT pk_profesional PRIMARY KEY (id_profesional),
    CONSTRAINT uq_profesional_dni UNIQUE (dni)
) ENGINE=InnoDB;

-- AREA
CREATE TABLE area (
    id_area                 INT            NOT NULL AUTO_INCREMENT,
    capacidad               INT            NOT NULL,
    ubicacion_predio        VARCHAR(100)   NOT NULL,
    estado_mantenimiento    VARCHAR(50)    NOT NULL,
    CONSTRAINT pk_area PRIMARY KEY (id_area),
    CONSTRAINT ck_area_capacidad CHECK (capacidad >= 0)
) ENGINE=InnoDB;

-- ACTIVIDAD
-- RA 6: tipo solo puede valer ARANCELADA o NO_ARANCELADA (y tiene que coincidir
--       con la tabla de subtipo donde está, lo controlan los triggers)
CREATE TABLE actividad (
    id_actividad    INT            NOT NULL AUTO_INCREMENT,
    descripcion     VARCHAR(200)   NULL,
    tipo            VARCHAR(20)    NOT NULL,
    CONSTRAINT pk_actividad PRIMARY KEY (id_actividad),
    CONSTRAINT ck_actividad_tipo CHECK (tipo IN ('ARANCELADA', 'NO_ARANCELADA'))
) ENGINE=InnoDB;

-- ACTIVIDAD ARANCELADA
CREATE TABLE actividad_arancelada (
    id_actividad        INT            NOT NULL,
    costo               DECIMAL(12,2)  NOT NULL,
    frecuencia_pago     VARCHAR(30)    NOT NULL,
    CONSTRAINT pk_actividad_arancelada PRIMARY KEY (id_actividad),
    CONSTRAINT fk_arancelada_actividad FOREIGN KEY (id_actividad)
        REFERENCES actividad (id_actividad)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_arancelada_costo CHECK (costo >= 0)
) ENGINE=InnoDB;

-- ACTIVIDAD NO ARANCELADA
CREATE TABLE actividad_no_arancelada (
    id_actividad    INT NOT NULL,
    CONSTRAINT pk_actividad_no_arancelada PRIMARY KEY (id_actividad),
    CONSTRAINT fk_no_arancelada_actividad FOREIGN KEY (id_actividad)
        REFERENCES actividad (id_actividad)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- PUEDE DICTAR (habilitación profesional-actividad)  -- necesaria para la RA 8
-- Si en el modelo de la cátedra se llama distinto, renombrar acá y en el trigger.
CREATE TABLE puede_dictar (
    id_profesional  INT NOT NULL,
    id_actividad    INT NOT NULL,
    CONSTRAINT pk_puede_dictar PRIMARY KEY (id_profesional, id_actividad),
    CONSTRAINT fk_puede_dictar_prof FOREIGN KEY (id_profesional)
        REFERENCES profesional (id_profesional)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_puede_dictar_act FOREIGN KEY (id_actividad)
        REFERENCES actividad (id_actividad)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- PERMITE (actividades que se pueden desarrollar en cada área)  -- necesaria para la RA 8
CREATE TABLE permite (
    id_area         INT NOT NULL,
    id_actividad    INT NOT NULL,
    CONSTRAINT pk_permite PRIMARY KEY (id_area, id_actividad),
    CONSTRAINT fk_permite_area FOREIGN KEY (id_area)
        REFERENCES area (id_area)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_permite_act FOREIGN KEY (id_actividad)
        REFERENCES actividad (id_actividad)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- TRABAJA EN (cronograma)
CREATE TABLE trabaja_en (
    id_profesional  INT            NOT NULL,
    id_actividad    INT            NOT NULL,
    id_area         INT            NOT NULL,
    dias            VARCHAR(50)    NOT NULL,
    horario         VARCHAR(30)    NOT NULL,
    periodo         VARCHAR(50)    NOT NULL,
    CONSTRAINT pk_trabaja_en PRIMARY KEY (id_profesional, id_actividad, id_area, dias, horario),
    CONSTRAINT fk_trabaja_profesional FOREIGN KEY (id_profesional)
        REFERENCES profesional (id_profesional)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_trabaja_actividad FOREIGN KEY (id_actividad)
        REFERENCES actividad (id_actividad)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_trabaja_area FOREIGN KEY (id_area)
        REFERENCES area (id_area)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- SE INSCRIBE EN
CREATE TABLE se_inscribe_en (
    nro_base            INT   NOT NULL,
    nro_orden           INT   NOT NULL,
    id_actividad        INT   NOT NULL,
    fecha_inscripcion   DATE  NOT NULL,
    CONSTRAINT pk_se_inscribe_en PRIMARY KEY (nro_base, nro_orden, id_actividad),
    CONSTRAINT fk_inscribe_socio FOREIGN KEY (nro_base, nro_orden)
        REFERENCES socio (nro_base, nro_orden)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_inscribe_actividad FOREIGN KEY (id_actividad)
        REFERENCES actividad (id_actividad)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ABONA
-- RA 5: solo paga quien está inscripto -> FK compuesta a SE INSCRIBE EN.
--       Además id_actividad sigue referenciando a ACTIVIDAD ARANCELADA.
CREATE TABLE abona (
    id_actividad    INT   NOT NULL,
    nro_orden       INT   NOT NULL,
    nro_base        INT   NOT NULL,
    fecha           DATE  NOT NULL,
    CONSTRAINT pk_abona PRIMARY KEY (id_actividad, nro_orden, nro_base),
    CONSTRAINT fk_abona_arancelada FOREIGN KEY (id_actividad)
        REFERENCES actividad_arancelada (id_actividad)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_abona_inscripcion FOREIGN KEY (nro_base, nro_orden, id_actividad)
        REFERENCES se_inscribe_en (nro_base, nro_orden, id_actividad)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- AGRUPA
CREATE TABLE agrupa (
    id_actividad    INT          NOT NULL,
    tipo_categoria  VARCHAR(30)  NOT NULL,
    CONSTRAINT pk_agrupa PRIMARY KEY (id_actividad, tipo_categoria),
    CONSTRAINT fk_agrupa_actividad FOREIGN KEY (id_actividad)
        REFERENCES actividad (id_actividad)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_agrupa_categoria FOREIGN KEY (tipo_categoria)
        REFERENCES categoria (tipo_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;


-- =====================================================
-- RA QUE QUEDAN FUERA DEL DDL (participaciones totales)
-- MySQL no tiene constraints diferidos, así que se controlan desde la aplicación
-- (insertando todo en una misma transacción) o con un procedimiento de alta:
--   * todo GRUPO FAMILIAR tiene al menos un SOCIO (y un SOCIO TITULAR, nro_orden = 0)
--   * todo SOCIO con is_titular = TRUE tiene fila en SOCIO TITULAR
--   * todo SOCIO TITULAR tiene al menos una CUOTA SOCIAL
--   * toda ACTIVIDAD está en ARANCELADA o en NO ARANCELADA
--   * toda ACTIVIDAD tiene al menos una categoría en AGRUPA
--   * deuda_actividad y deuda_total (RA 9) quedan como columnas que carga/actualiza
--     la aplicación; la deuda de cada cuota se obtiene con la vista v_cuota_deuda
-- =====================================================