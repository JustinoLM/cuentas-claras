# Flujo de trabajo con Git — Cuentas Claras

Este documento define cómo se trabaja con git en este proyecto. El objetivo no es solo versionar código, sino practicar un flujo profesional de verdad: ramas, commits con formato, Issues, Pull Requests, CI y releases por fase.

---

## 1. Ramas — GitHub Flow simplificado

No usamos GitFlow completo (develop/release/hotfix) — es más estructura de la que necesita un proyecto de un solo desarrollador. Usamos **GitHub Flow**:

- `main` siempre queda estable y compilando. Nunca se trabaja directo ahí.
- Cada pieza de trabajo vive en su propia rama, nombrada `feature/nombre-corto-descriptivo`:
  - `feature/modelos-swiftdata`
  - `feature/parser-dgi`
  - `feature/pipeline-captura`
  - `feature/cola-offline`
  - `feature/categorizacion`
  - `fix/nombre-del-bug` para arreglos puntuales (no features nuevas)
- Al terminar: Pull Request en GitHub → revisión (aunque sea uno mismo, leerlo como si fuera ajeno) → merge a `main` → borrar la rama.

```bash
git checkout -b feature/modelos-swiftdata
# ... trabajo ...
git push -u origin feature/modelos-swiftdata
gh pr create --fill
```

---

## 2. Mensajes de commit — Conventional Commits

Formato: `tipo: descripción en minúscula, modo imperativo`

| Prefijo | Cuándo usarlo |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de un bug |
| `test` | Agregar o modificar tests |
| `docs` | Cambios en documentación (spec, README, este archivo) |
| `refactor` | Cambio de código que no altera comportamiento |
| `chore` | Configuración, dependencias, tareas de mantenimiento |

Ejemplos:

```
feat: agregar modelo SwiftData de Gasto e ItemFactura
fix: corregir mapeo de data-title en tabla de items
test: agregar fixtures de la DGI al target de tests
docs: actualizar spec con esquema CSV versionado
chore: configurar gitignore
```

Si el commit cierra un Issue de GitHub, referenciarlo en el cuerpo del commit o del PR:

```
feat: parsear HTML de facturas DGI

Closes #3
```

---

## 3. Issues — una pieza del spec, un Issue

Cada sección relevante del `spec-invoice-scanner.md` se convierte en un Issue antes de empezar a codearla. Ejemplos para la Fase 1:

- Modelos SwiftData (sección 3)
- Pipeline de captura, 3 vías (sección 4)
- Parseo DGI + tests contra fixtures (secciones 5, 16)
- Deduplicación (sección 6)
- Notas de crédito — soporte parcial (sección 7)
- Cola offline (sección 8)
- Categorización manual (sección 9)

Flujo: **Issue → rama → PR que lo cierra → merge → Issue se cierra solo.**

---

## 4. Pull Requests

- Título corto, en el mismo estilo que los commits (`feat: ...`).
- Descripción: qué cambia y por qué — no hace falta extenso, pero sí claro.
- Revisar el propio diff antes de mergear, como ejercicio: ¿este código lo entendería alguien más? ¿falta un test?
- Squash merge o merge normal, cualquiera de los dos es válido para este proyecto — lo importante es mantenerlo consistente.

---

## 5. CI — GitHub Actions

Archivo `.github/workflows/tests.yml`:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: xcodebuild test -project "Cuentas Claras/Cuentas Claras.xcodeproj" -scheme "Cuentas Claras" -destination "platform=iOS Simulator,name=iPhone 16"
```

Corre los tests automáticamente en cada push y cada PR — incluye las pruebas del parser contra las 4 fixtures de la DGI. Si un cambio rompe el parseo, se detecta antes de mergear, no en producción.

---

## 6. Branch protection en `main`

En GitHub: **Settings → Branches → Add rule** sobre `main`:

- Exigir Pull Request antes de mergear (nada de push directo).
- Opcional: exigir que el check de CI pase antes de poder mergear.

Trabajando solo se siente burocrático a veces, pero es justo la disciplina que evita saltarse el proceso "porque total es rápido".

---

## 7. Tags por fase — versionado semántico

Al completar cada fase del roadmap (sección 18 del spec):

```bash
git tag -a v0.1.0 -m "Fase 1: núcleo local completo"
git push origin v0.1.0
```

| Tag | Fase completada |
|---|---|
| `v0.1.0` | Fase 1 — Núcleo (Capa 1) |
| `v0.2.0` | Fase 2 — Capa 0 + Capa 2 |
| `v0.3.0` | Fase 3 — Capa 3 (OneDrive) |
| `v0.4.0` | Fase 4 — Pulido y preparación para tienda |
| `v1.0.0` | Fase 5 — Por definir |

---

## 8. Setup inicial del repo remoto

```bash
gh repo create cuentas-claras --private --source=. --remote=origin
git push -u origin main
```

Requiere `gh` instalado (`brew install gh`) y autenticado (`gh auth login`).

---

## 9. Excepción — el commit inicial

El primer commit (configuración de Xcode, `.gitignore`, `README.md`, `CLAUDE.md`, spec, git-workflow, fixtures) va directo a `main` como `chore: configuración inicial del proyecto` — es setup del repo, no una feature del spec. **A partir de ahí, todo pasa por rama + PR.**
