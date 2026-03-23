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