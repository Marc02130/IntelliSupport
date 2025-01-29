#!/bin/bash
psql "$DATABASE_URL" -v edge_function_url="$EDGE_FUNCTION_URL" -v service_role_key="$SERVICE_ROLE_KEY" -f migrations/*.sql 