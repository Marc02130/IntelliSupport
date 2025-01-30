#!/bin/bash
psql "$DATABASE_URL" \
  -v service_role_key="'$SERVICE_ROLE_KEY'" \
  -c "SELECT set_config('service_role_key', :service_role_key, false);" \
  -f migrations/*.sql 