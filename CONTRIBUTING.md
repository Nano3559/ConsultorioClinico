# 🤝 Contribuir a ConsultorioClínico

Guía rápida para el equipo (detalle completo en [`docs/GIT_CONVENTION.md`](docs/GIT_CONVENTION.md)).

## 1. Flujo de trabajo
```bash
git pull origin main                     # empezar siempre desde main actualizada
git checkout -b feat/mi-cambio           # rama corta: <tipo>/<descripcion>
# ... trabajo ...
git add <archivos>                       # revisa con git status / git diff
git commit -m "feat: descripción corta"  # Conventional Commits en español
git push -u origin feat/mi-cambio
```
Luego abre un **Pull Request** hacia `main` en GitHub.

## 2. Reglas de oro
1. **Nada se commitea directo a `main`** — todo entra por PR.
2. **Revisión cruzada**: otro integrante aprueba antes del merge.
3. **Conventional Commits en español**: `feat`, `fix`, `docs`, `style`,
   `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `ui`.
4. **Un commit = un cambio lógico**; título ≤ 72 caracteres.
5. **Secretos nunca**: `.env`, `service-account.json`, keystore, claves.
   Están en `.gitignore`; si uno se filtra, rotarlo inmediatamente.

## 3. Antes de abrir el PR
- [ ] `flutter analyze` sin warnings (frontend)
- [ ] `flutter test` en verde (frontend)
- [ ] `npm test` en verde (backend)
- [ ] Sin secretos ni archivos temporales en el diff
- [ ] README/docs actualizados si aplica

## 4. Mensaje del PR
Título con formato de commit (`feat: ...`) y descripción con:
qué cambia · por qué · cómo probarlo.

## 5. Desarrollo con IA (OpenCode)
El proyecto usa OpenCode con los agentes `glm-architect` (GLM 5.3),
`deepseek-coder` (DeepSeek v4 Pro) y `gpt-luna-reviewer` (GPT 5.6 Luna),
más los respaldos gratuitos `free-planner`, `free-coder` y `free-reviewer`
(catálogo free de OpenCode Zen). Los agentes siguen estas mismas reglas
(ver `AGENTS.md`). Pídeles: planificar → implementar → revisar antes de
abrir el PR.
