# Objetivo:
    levantar SSO local (Laravel Passport v13 + SPA Vite) en modo dev, sin pasos manuales.

# Requisitos:
    Docker Desktop/Engine, Git.

# Puertos: 
    AUTH_PORT=8080, WEB_PORT=5173, DB_PORT=3306 (cambiar en .env.local si chocan).

# Estructura:
```bash
    infraestructura/sso/
        compose.yml
        .env.example
        bin/{up.sh,init-keys.sh,migrate.sh,upsert-client.sh,create-user.sh,dev-all.sh}
```
# Arranque rápido:
```bash
    cp .env.example .env.local   # opcional: ajustar BACKEND_CONTEXT/WEB_CONTEXT
    ./bin/dev-all.sh             # levanta, migra, genera llaves, crea/upsertea cliente PKCE e imprime client_id
```
# Login de prueba (opcional):
```bash
    ./bin/create-user.sh  # EMAIL=... NAME=... PASS=... para custom
```
# Probar: 
    http://localhost:$WEB_PORT → Cambiar de cuenta → login → consentimiento → /profile.

## comandos para copiar y pegar clonando repos y levantando sso completo:
```bash
# 0) Clonar org
git clone git@github.com:Proyecto-Tecnicatura-2025/infraestructura.git
git clone git@github.com:Proyecto-Tecnicatura-2025/auth-service.git
git clone git@github.com:Proyecto-Tecnicatura-2025/web-client.git

# 1) Infra / SSO
cd infraestructura/sso
cp .env.example .env.local
# (ajusta BACKEND_CONTEXT=../../auth-service si tu backend se llama auth-service)
./bin/dev-all.sh

# 2) (opcional) usuario de prueba
./bin/create-user.sh  # usa por defecto leoalmada.dev@gmail.com / 3213214

# 3) Verificar envs en el front
docker compose -f compose.yml exec -T web_client printenv | grep ^VITE_

# 4) Probar E2E
# Abrir http://localhost:5173 → Cambiar de cuenta → login → consentimiento → /profile

# 5) Smoke checks
docker compose -f compose.yml exec -T backend bash -lc '
php artisan route:list | egrep "oauth/authorize|oauth/token" && \
test -d storage/framework/sessions && echo "sessions OK" && \
test -d resources/views && echo "views OK"
'
```