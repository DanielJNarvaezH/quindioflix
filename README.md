# QuindioFlix — Bases de Datos II
Universidad del Quindío | Ingeniería de Sistemas | 2026-1

Proyecto final de Bases de Datos II. Sistema de streaming de contenido 
multimedia implementado con Oracle XE 21c, Spring Boot y Flyway.

## Equipo
- Daniel Narváez
- Diego García  
- Cristhian Osorio

## Tecnologías
- Java 21
- Spring Boot 4.0.4
- Flyway 9.22.3
- Oracle XE 21c

## Cómo empezar

### 1. Prerequisito — Crear usuario Oracle
Ejecutar como SYSTEM conectado al PDB (XEPDB1):
```sql
-- Ver archivo: setup/crear_usuario.sql
```

### 2. Clonar el repo
```bash
git clone https://github.com/TU_USUARIO/quindioflix.git
```

### 3. Correr el proyecto
```bash
cd quindioflix/quindioflix-bd2
mvn spring-boot:run
```
Flyway ejecuta automáticamente los scripts en db/migration/ en orden.

## Estructura
```
quindioflix/
├── quindioflix-bd2/                           # Backend Spring Boot
├── Scripts Proyecto Bases de Datos II/        # Scripts prerequisitos Oracle
└── documentacion/                             # MER y documentación
``` 

## Convención de Scripts SQL (Flyway)

Los scripts van en `quindioflix-bd2/src/main/resources/db/migration/`
y siguen el formato: `V{numero}__{descripcion}.sql`

el V es de versión, de ahí que para corregir algo se haga otro script de 
corrección que será algo así como una versión nueva.

### Orden de ejecución
| Script | Descripción |
|--------|-------------|
| V1__tablespaces.sql | Tablespaces y datafiles |
| V2__create_tables.sql | Tablas con restricciones y comentarios |
| V3__datos_maestros.sql | Datos de prueba tablas maestras |
| V4__datos_transaccionales.sql | Datos de prueba tablas transaccionales |
| V5__nucleo1_consultas.sql | Consultas avanzadas NT1 |
| V6__nucleo2_plsql.sql | PL/SQL cursores, SPs, funciones, triggers |
| V7__nucleo3_transacciones.sql | Transacciones y concurrencia |
| V8__nucleo4_indices.sql | Índices y EXPLAIN PLAN |
| V9__nucleo5_roles.sql | Usuarios, roles y privilegios |

### Reglas importantes
- ⚠️ **Nunca modificar/corregir un script que ya alguien ejecutó y subió al github** — Flyway 
  detecta el cambio por checksum y lanza error
- ✅ Para correcciones crear script nuevo: `V2.1__fix_tablas.sql`
- ✅ El número debe ser único y en orden ascendente
- ✅ Descripción en minúsculas con guiones bajos, sin tildes ni espacios