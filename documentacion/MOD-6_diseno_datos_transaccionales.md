# MOD-6 — Diseño de datos transaccionales para QuindioFlix

**Proyecto:** QuindioFlix — Bases de Datos II  
**Epic:** SCRUM-6 — Modelo de datos y almacenamiento  
**Tarea Jira:** SCRUM-22 — Script de datos de prueba — Tablas transaccionales  
**Estado actual:** Diseño preparado; implementación final bloqueada hasta disponer de `V3__datos_maestros.sql`  
**Fecha:** 2026-04-05

## 1. Objetivo

Dejar definido el diseño de `V4__datos_transaccionales.sql` para que, una vez esté disponible `V3__datos_maestros.sql`, se pueda implementar con rapidez, coherencia y utilidad para las fases posteriores del proyecto.

El script deberá poblar las tablas transaccionales con datos de prueba **asimétricos**, válidos para integridad referencial y útiles para las consultas analíticas de NT1.

---

## 2. Dependencias y bloqueo actual

### Dependencias funcionales

`V4__datos_transaccionales.sql` depende de que existan previamente los datos maestros mínimos de:

- `PLANES`
- `CATEGORIAS`
- `GENEROS`
- `DEPARTAMENTOS`
- `EMPLEADOS`
- `CONTENIDO`

### Bloqueo actual

En Jira, `SCRUM-22` está bloqueada por:

- **SCRUM-21** — `MOD-5 Script de datos de prueba — Tablas maestras`

Y en el repositorio actual solo existen:

- `V1__tablespaces.sql`
- `V2__create_tables.sql`

Por tanto, este documento deja lista la estrategia, pero la implementación final debe esperar a que `V3__datos_maestros.sql` esté en `main`.

---

## 3. Alcance de la tarea SCRUM-22

El script `V4__datos_transaccionales.sql` debe incluir como mínimo:

- 30 `USUARIOS`
- 50 `PERFILES`
- 15 `TEMPORADAS`
- 50 `EPISODIOS`
- 200 `REPRODUCCIONES`
- 60 `CALIFICACIONES`
- 80 `PAGOS`
- 40 `FAVORITOS`

Adicionalmente, los datos deben ser **asimétricos**, es decir, no uniformes, de manera que permitan generar reportes y análisis con resultados realistas.

---

## 4. Principios de diseño del dataset

### 4.1 Asimetría controlada

Los datos no deben distribuirse de manera perfectamente uniforme. Debe haber:

- ciudades con más usuarios que otras;
- planes más contratados que otros;
- contenidos mucho más reproducidos que otros;
- dispositivos con uso desigual;
- usuarios con más perfiles, favoritos o pagos que otros.

### 4.2 Coherencia con el dominio

Los datos deben respetar lo definido en SCRUM-24:

- usuarios con plan válido;
- perfiles infantiles y adultos;
- pagos consistentes con el tipo de plan;
- series/podcasts con temporadas y episodios;
- películas/documentales/música sin episodios forzados;
- reproducciones y calificaciones alineadas con el consumo.

### 4.3 Utilidad para NT1

El dataset debe facilitar después:

- PIVOT por categoría y dispositivo;
- ROLLUP por ciudad y plan;
- vista materializada de contenido más popular;
- métricas de ingresos y consumo;
- evidencia clara de particionamiento en `REPRODUCCIONES`.

---

## 5. Estrategia de carga por tabla

## 5.1 USUARIOS

### Meta
Crear 30 usuarios distribuidos en 3 ciudades y 3 planes.

### Diseño propuesto

- Ciudades sugeridas:
  - Armenia
  - Pereira
  - Manizales

- Distribución no uniforme sugerida:
  - Armenia: 14 usuarios
  - Pereira: 10 usuarios
  - Manizales: 6 usuarios

- Distribución no uniforme de planes:
  - Básico: 14
  - Estándar: 10
  - Premium: 6

- Moderadores:
  - marcar 2 o 3 usuarios con `es_moderador = 'S'`

- Referidos:
  - entre 8 y 10 usuarios pueden tener `id_referidor`

### Criterios

- correos únicos;
- fechas de registro variadas;
- fechas de vencimiento coherentes;
- estados mayoritariamente `ACTIVO`, con pocos casos `INACTIVO` o `SUSPENDIDO`.

---

## 5.2 PERFILES

### Meta
Crear 50 perfiles para 30 usuarios.

### Diseño propuesto

Distribución desigual por cuenta:

- algunos usuarios con 1 perfil;
- varios con 2;
- pocos con 3 o 4;
- respetando el máximo permitido por el plan.

Tipos:

- mayoría `ADULTO`
- algunos `INFANTIL`

### Criterios

- no exceder `PLANES.max_perfiles`;
- nombres plausibles por cuenta;
- usar perfiles infantiles solo donde tenga sentido para las reglas del dominio.

---

## 5.3 TEMPORADAS y EPISODIOS

### Meta
- 15 temporadas
- 50 episodios

### Diseño propuesto

Solo deben aplicarse a contenidos seriados del catálogo maestro:

- series
- podcasts

Distribución sugerida:

- 5 contenidos serializados;
- 2 a 4 temporadas por contenido;
- entre 3 y 5 episodios por temporada.

### Criterios

- no crear episodios para películas;
- no crear temporadas para contenido unitario;
- variar duración y año de estreno.

---

## 5.4 PAGOS

### Meta
Crear 80 pagos.

### Diseño propuesto

- múltiples pagos por usuario activo;
- pocos pagos rechazados o reembolsados;
- método de pago no uniforme:
  - TARJETA y PSE más frecuentes;
  - NEQUI y DAVIPLATA intermedios;
  - EFECTIVO minoritario.

### Criterios

- monto coherente con el plan;
- descuentos ocasionales por referidos;
- fechas mensuales o bimensuales variadas para permitir análisis temporal.

---

## 5.5 REPRODUCCIONES

### Meta
Crear 200 reproducciones.

### Diseño propuesto

Esta es la tabla más importante para NT1. Debe diseñarse con asimetría fuerte:

- unos pocos contenidos muy populares;
- varios contenidos con consumo medio;
- algunos con consumo bajo;
- dispositivos con distribución desigual:
  - CELULAR y TV más frecuentes;
  - COMPUTADOR intermedio;
  - TABLET menos frecuente.

### Fechas recomendadas

Distribuir reproducciones entre:

- 2024
- 2025

para que haya registros en ambas particiones:

- `p_2024`
- `p_2025`

### Criterios

- `id_episodio` solo cuando aplique;
- `porcentaje_avance` variado;
- sesiones completas e incompletas;
- suficientes registros por categoría y dispositivo para el PIVOT.

---

## 5.6 CALIFICACIONES

### Meta
Crear 60 calificaciones.

### Diseño propuesto

- más calificaciones en contenidos populares;
- menos calificaciones en contenidos de baja reproducción;
- promedio alto en algunos títulos y regular en otros.

### Criterios

- no repetir perfil-contenido;
- incluir reseñas en parte de los registros;
- apoyar la futura vista materializada de popularidad.

---

## 5.7 FAVORITOS

### Meta
Crear 40 favoritos.

### Diseño propuesto

- concentrar favoritos en contenidos populares;
- evitar distribución plana;
- usar perfiles distintos.

### Criterios

- no repetir perfil-contenido;
- fechas variadas.

---

## 6. Orden recomendado de inserción

El orden propuesto para `V4__datos_transaccionales.sql` es:

1. `USUARIOS`
2. `PERFILES`
3. `TEMPORADAS`
4. `EPISODIOS`
5. `PAGOS`
6. `REPRODUCCIONES`
7. `CALIFICACIONES`
8. `FAVORITOS`

Este orden respeta las dependencias por llaves foráneas y simplifica la carga.

---

## 7. Recomendaciones técnicas para implementación

- usar consultas por nombre o atributos de negocio cuando sea posible para obtener IDs;
- evitar depender de valores de identity “asumidos” si `V3` puede cambiar;
- agrupar el script por secciones claramente comentadas;
- dejar evidencia de por qué ciertos contenidos o ciudades tienen mayor volumen;
- preparar datos pensando en consultas posteriores, no solo en cumplir cantidades.

---

## 8. Evidencias que debería dejar SCRUM-22

Cuando se implemente y ejecute el script, conviene capturar:

- conteo por tabla transaccional;
- usuarios por ciudad y plan;
- pagos por estado y método;
- reproducciones por categoría y dispositivo;
- particiones activas de `REPRODUCCIONES`;
- muestra de perfiles infantiles y adultos;
- muestra de contenidos con y sin episodios.

Estas evidencias servirán para:

- `3.3 Prueba del Modelo` en la plantilla editable;
- verificación de integridad de `SCRUM-23`;
- soporte documental para NT1.

---

## 9. Riesgos a evitar

- crear datos demasiado uniformes;
- violar máximos de perfiles por plan;
- generar episodios para contenido no seriado;
- dejar una sola partición sin datos;
- crear pocos datos útiles para consultas analíticas;
- hacer inserts dependientes de IDs frágiles.

---

## 10. Próximo paso cuando se desbloquee

Una vez `SCRUM-21` esté implementada y subida a `main`, el siguiente flujo recomendado es:

1. hacer pull del repositorio actualizado;
2. revisar cómo quedaron cargados `PLANES`, `CONTENIDO`, `EMPLEADOS` y demás tablas maestras;
3. aterrizar los IDs reales o las búsquedas necesarias;
4. implementar `V4__datos_transaccionales.sql`;
5. validar integridad localmente;
6. dejar evidencia lista para `SCRUM-23`.
